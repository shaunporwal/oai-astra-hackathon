import Foundation
import CoreGraphics

/// 8-bit single-channel raster, row-major, origin top-left.
struct GrayImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(width: Int, height: Int, fill: UInt8 = 0) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: fill, count: width * height)
    }

    @inline(__always)
    subscript(x: Int, y: Int) -> UInt8 {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    @inline(__always)
    func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    /// Bilinear sample; returns nil when the point lies outside the raster.
    func sample(x: Double, y: Double) -> Double? {
        guard x >= 0, y >= 0, x <= Double(width - 1), y <= Double(height - 1) else { return nil }
        let x0 = Int(x), y0 = Int(y)
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let fx = x - Double(x0), fy = y - Double(y0)
        let a = Double(self[x0, y0]), b = Double(self[x1, y0])
        let c = Double(self[x0, y1]), d = Double(self[x1, y1])
        return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy
    }

    /// 3×3 box blur; edges are clamped.
    func boxBlurred() -> GrayImage {
        var out = GrayImage(width: width, height: height)
        for y in 0..<height {
            let ym = max(y - 1, 0), yp = min(y + 1, height - 1)
            for x in 0..<width {
                let xm = max(x - 1, 0), xp = min(x + 1, width - 1)
                var sum = 0
                for yy in [ym, y, yp] {
                    let row = yy * width
                    sum += Int(pixels[row + xm]) + Int(pixels[row + x]) + Int(pixels[row + xp])
                }
                out.pixels[y * width + x] = UInt8(sum / 9)
            }
        }
        return out
    }

    func cropped(to rect: CGRect) -> GrayImage {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        let w = Int(r.width), h = Int(r.height)
        guard w > 0, h > 0 else { return GrayImage(width: 1, height: 1) }
        var out = GrayImage(width: w, height: h)
        let ox = Int(r.minX), oy = Int(r.minY)
        for y in 0..<h {
            let src = (oy + y) * width + ox
            out.pixels.replaceSubrange(y * w ..< y * w + w, with: pixels[src ..< src + w])
        }
        return out
    }

    func percentile(_ p: Double) -> UInt8 {
        var hist = [Int](repeating: 0, count: 256)
        for v in pixels { hist[Int(v)] += 1 }
        let target = Int(Double(pixels.count) * p)
        var acc = 0
        for i in 0..<256 {
            acc += hist[i]
            if acc >= target { return UInt8(i) }
        }
        return 255
    }

    var mean: Double {
        guard !pixels.isEmpty else { return 0 }
        var sum = 0
        for v in pixels { sum += Int(v) }
        return Double(sum) / Double(pixels.count) / 255
    }
}

/// 8-bit RGBA raster, row-major, origin top-left.
struct RGBImage {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        precondition(pixels.count == width * height * 4)
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.pixels = [UInt8](repeating: 255, count: width * height * 4)
    }

    @inline(__always)
    func rgb(x: Int, y: Int) -> (r: Double, g: Double, b: Double) {
        let i = (y * width + x) * 4
        return (Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2]))
    }

    @inline(__always)
    mutating func set(x: Int, y: Int, r: UInt8, g: UInt8, b: UInt8) {
        let i = (y * width + x) * 4
        pixels[i] = r; pixels[i + 1] = g; pixels[i + 2] = b; pixels[i + 3] = 255
    }

    /// Rec. 601 luma.
    func gray() -> GrayImage {
        var out = GrayImage(width: width, height: height)
        var i = 0
        for p in 0..<(width * height) {
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            out.pixels[p] = UInt8((r * 299 + g * 587 + b * 114) / 1000)
            i += 4
        }
        return out
    }
}

// MARK: - Geometry helpers

extension CGPoint {
    func distance(to other: CGPoint) -> Double {
        Double(hypot(x - other.x, y - other.y))
    }

    func scaled(by s: Double) -> CGPoint {
        CGPoint(x: x * s, y: y * s)
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

extension Array where Element == Double {
    var mean: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let m = mean
        let variance = reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(count - 1)
        return variance.squareRoot()
    }

    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let idx = Int((Double(sorted.count - 1) * p).rounded())
        return sorted[Swift.max(0, Swift.min(idx, sorted.count - 1))]
    }
}
