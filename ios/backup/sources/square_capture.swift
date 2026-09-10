import CoreGraphics

/// Matches the center crop of an aspect-fill preview inside a square viewfinder.
enum SquareCapture {
    static func cropRect(in extent: CGRect) -> CGRect {
        let side=min(extent.width,extent.height)
        return CGRect(x:extent.midX-side/2,y:extent.midY-side/2,width:side,height:side)
    }
}
