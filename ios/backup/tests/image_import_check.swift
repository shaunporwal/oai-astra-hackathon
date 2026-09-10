import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main
struct ImageImportCheck {
    static func main() throws {
        let context=CGContext(data:nil,width:1200,height:800,bitsPerComponent:8,bytesPerRow:1200*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red:0.7,green:0.3,blue:0.2,alpha:1));context.fill(CGRect(x:0,y:0,width:1200,height:800))
        let encoded=NSMutableData()
        let destination=CGImageDestinationCreateWithData(encoded,UTType.jpeg.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(destination,context.makeImage()!,[
            kCGImagePropertyOrientation:6,
            kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:12.34,kCGImagePropertyGPSLatitudeRef:"N"]
        ] as CFDictionary)
        precondition(CGImageDestinationFinalize(destination))
        let result=try ImageImport.prepare(encoded as Data)
        let source=CGImageSourceCreateWithData(result as CFData,nil)!
        let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
        precondition(image.width == 640 && image.height == 960)
        let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil)! as NSDictionary
        precondition(properties[kCGImagePropertyGPSDictionary] == nil)
        precondition((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        do { _=try ImageImport.prepare(Data([0,1,2]));preconditionFailure("Invalid file accepted") } catch {}
        print("Image import: orientation, whole-image aspect ratio, dimensions, metadata removal and invalid-data rejection passed")
    }
}
