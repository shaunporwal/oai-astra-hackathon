import Foundation
import CoreGraphics

/// Geometry of a localised eye in the coordinate space of the analysed raster (pixels).
struct EyeLocalization: Equatable {
    var pupilCenter: CGPoint
    var pupilRadius: Double
    var irisCenter: CGPoint
    var irisRadius: Double
    /// min/max pupil radius from centroid to boundary (1.0 = perfect circle).
    var pupilCircularity: Double
    /// 0…1 — combines pupil blob quality and limbal edge strength.
    var confidence: Double
}

/// Close-range eye localiser. Vision's face-landmark detector needs a whole face in frame,
/// which is not the case at macro working distance (6–10 cm). This operator finds the pupil
/// as the darkest compact blob, then locates the limbus (iris/sclera boundary) with a
/// Daugman-style integro-differential search along nasal/temporal rays, which avoids the
/// eyelids.
enum PupilLocalizer {
    struct Parameters {
        /// Pupil radius search window as a fraction of raster width.
        var minPupilRadiusFraction = 0.015
        var maxPupilRadiusFraction = 0.22
        /// Iris radius bounds relative to the pupil radius.
        var minIrisToPupil = 1.35
        var maxIrisToPupil = 6.5
        /// Half-angle (degrees) around the horizontal axis used for limbus rays.
        var rayHalfAngle = 32.0
        var rayStepDegrees = 4.0
        /// Dark-pixel percentile used to seed the pupil threshold.
        var darkPercentile = 0.03

        static let standard = Parameters()
    }

    static func localize(
        in raw: GrayImage,
        searchRegion: CGRect? = nil,
        parameters p: Parameters = .standard
    ) -> EyeLocalization? {
        guard raw.width >= 16, raw.height >= 16 else { return nil }
        let image = raw.boxBlurred()
        let region = (searchRegion ?? CGRect(x: 0, y: 0, width: image.width, height: image.height))
            .integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard region.width > 8, region.height > 8 else { return nil }

        guard let blob = darkestCompactBlob(in: image, region: region, parameters: p) else { return nil }

        let irisFit = limbusRadius(in: image, center: blob.center, pupilRadius: blob.radius, parameters: p)

        // Iris centre: refine horizontally using the two limbus crossings when both are available.
        var irisCenter = blob.center
        if let left = irisFit.leftRadius, let right = irisFit.rightRadius {
            irisCenter.x += (right - left) / 2
        }

        let blobQuality = blob.circularity.clamped(to: 0...1)
        let edgeQuality = irisFit.edgeStrength.clamped(to: 0...1)
        let confidence = (0.45 * blobQuality + 0.55 * edgeQuality).clamped(to: 0...1)

        return EyeLocalization(
            pupilCenter: blob.center,
            pupilRadius: blob.radius,
            irisCenter: irisCenter,
            irisRadius: irisFit.radius,
            pupilCircularity: blob.circularity,
            confidence: confidence
        )
    }

    // MARK: Pupil blob

    struct Blob {
        var center: CGPoint
        var radius: Double
        var area: Int
        var circularity: Double
    }

    /// Finds the pupil by sweeping the dark threshold upward from the frame's black level and
    /// taking the first *stable* compact blob: the pupil's area plateaus once the threshold
    /// clears its edge, well before a dark iris merges in and the area jumps.
    static func darkestCompactBlob(in image: GrayImage, region: CGRect, parameters p: Parameters) -> Blob? {
        let sub = image.cropped(to: region)
        let ox = Int(region.minX), oy = Int(region.minY)

        let floor = Int(sub.percentile(0.002))
        let median = Int(sub.percentile(0.5))
        // A frame with no real dark structure (e.g. a blank wall) is rejected outright.
        guard median - floor > 40 else { return nil }

        var candidates: [(threshold: Int, blob: Blob)] = []
        var t = floor + 4
        while t <= min(floor + 72, 130) {
            if let b = bestCompactBlob(in: sub, threshold: UInt8(t), fullWidth: image.width, parameters: p) {
                candidates.append((t, b))
            }
            t += 4
        }
        guard !candidates.isEmpty else { return nil }

        var chosen: Blob?
        if candidates.count == 1 {
            chosen = candidates[0].blob
        } else {
            func growth(_ i: Int) -> Double {
                let a = Double(candidates[i].blob.area), b = Double(candidates[i + 1].blob.area)
                return (b - a) / a
            }
            func sameBlob(_ i: Int) -> Bool {
                candidates[i].blob.center.distance(to: candidates[i + 1].blob.center) < candidates[i].blob.radius
            }
            outer: for i in 0..<(candidates.count - 1) where sameBlob(i) && growth(i) < 0.15 {
                // Walk a little further along the plateau so the anti-aliased pupil edge is
                // included, but stop before any slow creep into a dark iris.
                var j = i + 1
                while j + 1 < candidates.count, j - i < 3, sameBlob(j), growth(j) < 0.08 { j += 1 }
                chosen = candidates[j].blob
                break outer
            }
            if chosen == nil { chosen = candidates[0].blob }
        }
        guard var blob = chosen else { return nil }
        blob.center = CGPoint(x: blob.center.x + Double(ox), y: blob.center.y + Double(oy))
        return blob
    }

    /// Best compact dark component in `sub` at a fixed threshold, in `sub` coordinates.
    private static func bestCompactBlob(in sub: GrayImage, threshold: UInt8, fullWidth: Int, parameters p: Parameters) -> Blob? {
        let w = sub.width, h = sub.height
        var visited = [Bool](repeating: false, count: w * h)
        var best: Blob?
        var bestScore = -Double.infinity

        let minArea = Int(Double.pi * pow(p.minPupilRadiusFraction * Double(fullWidth), 2))
        let maxArea = Int(Double.pi * pow(p.maxPupilRadiusFraction * Double(fullWidth), 2))

        var stack: [Int] = []
        stack.reserveCapacity(4096)

        for start in 0..<(w * h) {
            if visited[start] || sub.pixels[start] > threshold { continue }
            // Flood fill (4-connected).
            visited[start] = true
            stack.append(start)
            var area = 0
            var sx = 0, sy = 0
            var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min
            var boundary: [(Int, Int)] = []

            while let idx = stack.popLast() {
                let x = idx % w, y = idx / w
                area += 1
                sx += x; sy += y
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
                var isBoundary = false
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = x + dx, ny = y + dy
                    if nx < 0 || ny < 0 || nx >= w || ny >= h { isBoundary = true; continue }
                    let n = ny * w + nx
                    if sub.pixels[n] > threshold { isBoundary = true; continue }
                    if !visited[n] {
                        visited[n] = true
                        stack.append(n)
                    }
                }
                if isBoundary { boundary.append((x, y)) }
            }

            guard area >= max(minArea, 12), area <= maxArea else { continue }

            let cx = Double(sx) / Double(area), cy = Double(sy) / Double(area)
            let bboxW = Double(maxX - minX + 1), bboxH = Double(maxY - minY + 1)
            let aspect = min(bboxW, bboxH) / max(bboxW, bboxH)
            let fill = Double(area) / (Double.pi * pow(max(bboxW, bboxH) / 2, 2))
            // Outer contour: the farthest boundary pixel in each angular bin. Interior holes
            // (specular highlights on the cornea) are ignored this way.
            let bins = 36
            var outer = [Double](repeating: -1, count: bins)
            for (bx, by) in boundary {
                let dx = Double(bx) - cx, dy = Double(by) - cy
                let r = hypot(dx, dy)
                var bin = Int((atan2(dy, dx) + .pi) / (2 * .pi) * Double(bins))
                if bin >= bins { bin = bins - 1 }
                if bin < 0 { bin = 0 }
                if r > outer[bin] { outer[bin] = r }
            }
            var contour = outer.filter { $0 >= 0 }
            contour.sort()
            guard contour.count >= 8 else { continue }
            let lo = contour[Int(Double(contour.count - 1) * 0.08)]
            let hi = contour[Int(Double(contour.count - 1) * 0.92)]
            let circularity = hi > 0 ? (lo / hi) : 0
            let contourRadius = contour.mean

            // Reject eyelash-like elongated or hollow components.
            guard aspect > 0.45, fill > 0.45 else { continue }

            let score = Double(area) * pow(circularity, 2) * aspect
            if score > bestScore {
                bestScore = score
                // Boundary samples are pixel centres just inside the true edge: add half a pixel.
                best = Blob(
                    center: CGPoint(x: cx, y: cy),
                    radius: (contour.count >= 12 ? contourRadius : (Double(area) / Double.pi).squareRoot()) + 0.5,
                    area: area,
                    circularity: circularity
                )
            }
        }
        return best
    }

    // MARK: Limbus

    struct IrisFit {
        var radius: Double
        var leftRadius: Double?
        var rightRadius: Double?
        var edgeStrength: Double
    }

    /// Searches for the radius at which the mean intensity along nasal/temporal rays
    /// rises most steeply (dark iris → bright sclera).
    static func limbusRadius(in image: GrayImage, center: CGPoint, pupilRadius rp: Double, parameters p: Parameters) -> IrisFit {
        let rMin = max(rp * p.minIrisToPupil, 3)
        let rMax = rp * p.maxIrisToPupil
        let steps = max(Int(rMax - rMin), 8)
        let dr = (rMax - rMin) / Double(steps)

        func sideProfile(startDeg: Double) -> [Double]? {
            var profile = [Double](repeating: 0, count: steps + 1)
            var counts = [Int](repeating: 0, count: steps + 1)
            var deg = startDeg - p.rayHalfAngle
            while deg <= startDeg + p.rayHalfAngle {
                let theta = deg * .pi / 180
                let cosT = cos(theta), sinT = sin(theta)
                for i in 0...steps {
                    let r = rMin + Double(i) * dr
                    if let v = image.sample(x: Double(center.x) + r * cosT, y: Double(center.y) + r * sinT) {
                        profile[i] += v
                        counts[i] += 1
                    }
                }
                deg += p.rayStepDegrees
            }
            var valid = 0
            for i in 0...steps where counts[i] > 0 {
                profile[i] /= Double(counts[i]); valid += 1
            }
            guard valid > steps / 2 else { return nil }
            for i in 0...steps where counts[i] == 0 { profile[i] = profile[max(i - 1, 0)] }
            return profile
        }

        func bestEdge(_ profile: [Double]) -> (radius: Double, strength: Double)? {
            // Smooth then take forward differences over a 3-sample baseline.
            let n = profile.count
            guard n > 6 else { return nil }
            var smooth = profile
            for i in 1..<(n - 1) { smooth[i] = (profile[i - 1] + profile[i] + profile[i + 1]) / 3 }
            var bestI = -1
            var bestG = 0.0
            for i in 2..<(n - 2) {
                let g = smooth[i + 2] - smooth[i - 2]
                if g > bestG { bestG = g; bestI = i }
            }
            guard bestI >= 0 else { return nil }
            return (rMin + Double(bestI) * dr, bestG / 255)
        }

        let right = sideProfile(startDeg: 0).flatMap(bestEdge)
        let left = sideProfile(startDeg: 180).flatMap(bestEdge)

        var radii: [Double] = []
        var strengths: [Double] = []
        if let right { radii.append(right.radius); strengths.append(right.strength) }
        if let left { radii.append(left.radius); strengths.append(left.strength) }

        guard !radii.isEmpty else {
            // Fall back to a population-typical pupil/iris ratio.
            return IrisFit(radius: rp * 3.2, leftRadius: nil, rightRadius: nil, edgeStrength: 0)
        }

        // Edge strengths are intensity deltas over 4 samples; ~0.12 (≈30/255) is a confident limbus.
        let strength = (strengths.mean / 0.12).clamped(to: 0...1)
        return IrisFit(
            radius: radii.mean,
            leftRadius: left?.radius,
            rightRadius: right?.radius,
            edgeStrength: strength
        )
    }
}
