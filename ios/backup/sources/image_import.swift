import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Downsample before decoding full-resolution pixels. Preserve the whole image,
/// apply orientation, and export pixel-only JPEG without source EXIF/GPS metadata.
enum ImageImport {
    static func prepare(_ data: Data) throws -> Data {
        guard data.count <= 30_000_000,
              let source=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),
              let image=CGImageSourceCreateThumbnailAtIndex(source,0,[
                kCGImageSourceCreateThumbnailFromImageAlways:true,
                kCGImageSourceCreateThumbnailWithTransform:true,
                kCGImageSourceThumbnailMaxPixelSize:960,
                kCGImageSourceShouldCacheImmediately:true
              ] as CFDictionary), min(image.width,image.height) >= 64 else { throw ImportError.unsupported }
        let result=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(result,UTType.jpeg.identifier as CFString,1,nil) else { throw ImportError.unsupported }
        CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:0.92] as CFDictionary)
        guard CGImageDestinationFinalize(destination), result.length <= 2_000_000 else { throw ImportError.unsupported }
        return result as Data
    }
    enum ImportError: LocalizedError {
        case unsupported
        var errorDescription: String? { "Choose a supported photo under 30 MB with both dimensions at least 64 pixels after resizing." }
    }
}
