import Foundation
import CoreGraphics

/// Per-frame photometric and focus metrics computed on the eye region.
struct FrameQualityMetrics: Equatable {
    /// Normalised sharpness in 0…1 (1 − exp(−varLaplacian / 150)).
    var sharpness: Double
    /// Mean luma 0…1.
    var meanLuma: Double
    /// Fraction of pixels at or above 250/255.
    var clipping: Double

    static let zero = FrameQualityMetrics(sharpness: 0, meanLuma: 0, clipping: 0)
}

enum FrameQualityAnalyzer {
    /// Laplacian variance reference at which sharpness ≈ 0.63.
    static let sharpnessReference = 150.0

    static func metrics(for roi: GrayImage) -> FrameQualityMetrics {
        FrameQualityMetrics(
            sharpness: sharpness(of: roi),
            meanLuma: roi.mean,
            clipping: clippingFraction(of: roi)
        )
    }

    /// Variance of the 3×3 Laplacian response — a standard focus measure.
    static func laplacianVariance(of image: GrayImage) -> Double {
        let w = image.width, h = image.height
        guard w > 2, h > 2 else { return 0 }
        var sum = 0.0, sumSq = 0.0
        var n = 0
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                let c = Int(image.pixels[y * w + x]) * 4
                let l = Int(image.pixels[y * w + x - 1]) + Int(image.pixels[y * w + x + 1])
                    + Int(image.pixels[(y - 1) * w + x]) + Int(image.pixels[(y + 1) * w + x])
                let v = Double(c - l)
                sum += v
                sumSq += v * v
                n += 1
            }
        }
        guard n > 0 else { return 0 }
        let mean = sum / Double(n)
        return sumSq / Double(n) - mean * mean
    }

    static func sharpness(of image: GrayImage) -> Double {
        1 - exp(-laplacianVariance(of: image) / sharpnessReference)
    }

    static func clippingFraction(of image: GrayImage, level: UInt8 = 250) -> Double {
        guard !image.pixels.isEmpty else { return 0 }
        var n = 0
        for v in image.pixels where v >= level { n += 1 }
        return Double(n) / Double(image.pixels.count)
    }
}
