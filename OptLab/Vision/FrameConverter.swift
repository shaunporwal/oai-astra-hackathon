import Foundation
import CoreImage
import CoreGraphics
import UIKit

/// Renders CoreImage content into the CPU rasters used by the analysis code.
/// All output rasters are top-left origin.
final class FrameConverter {
    private let context = CIContext(options: [
        .cacheIntermediates: false,
        .priorityRequestLow: true,
    ])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// Downsamples the whole image to `targetWidth` (aspect preserved).
    func rgbImage(from image: CIImage, targetWidth: Int) -> RGBImage {
        let extent = image.extent
        guard extent.width > 0, extent.height > 0 else { return RGBImage(width: 1, height: 1) }
        let scale = Double(targetWidth) / Double(extent.width)
        let height = max(Int((Double(extent.height) * scale).rounded()), 1)
        let scaled = image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -extent.minX * scale, y: -extent.minY * scale))
        return render(scaled, width: targetWidth, height: height)
    }

    /// Crops a region given in top-left-origin *normalised* coordinates, then renders at `targetWidth`.
    func rgbImage(from image: CIImage, normalizedRect rect: CGRect, targetWidth: Int) -> RGBImage {
        let extent = image.extent
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard clamped.width > 0, clamped.height > 0 else { return RGBImage(width: 1, height: 1) }
        // CoreImage is bottom-left origin.
        let cropRect = CGRect(
            x: extent.minX + clamped.minX * extent.width,
            y: extent.minY + (1 - clamped.maxY) * extent.height,
            width: clamped.width * extent.width,
            height: clamped.height * extent.height
        )
        let cropped = image.cropped(to: cropRect)
        let scale = Double(targetWidth) / Double(cropRect.width)
        let height = max(Int((Double(cropRect.height) * scale).rounded()), 1)
        let scaled = cropped
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX * scale, y: -cropRect.minY * scale))
        return render(scaled, width: targetWidth, height: height)
    }

    func rgbImage(from cgImage: CGImage, targetWidth: Int) -> RGBImage {
        rgbImage(from: CIImage(cgImage: cgImage), targetWidth: targetWidth)
    }

    private func render(_ image: CIImage, width: Int, height: Int) -> RGBImage {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            context.render(
                image,
                toBitmap: buffer.baseAddress!,
                rowBytes: width * 4,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                format: .RGBA8,
                colorSpace: colorSpace
            )
        }
        return RGBImage(width: width, height: height, pixels: pixels)
    }

    /// Full-quality CGImage (used when persisting a capture).
    func cgImage(from image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent, format: .RGBA8, colorSpace: colorSpace)
    }
}

extension RGBImage {
    /// Builds a CGImage from the raster (used for previews of synthetic frames and overlays).
    func makeCGImage() -> CGImage? {
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }
}
