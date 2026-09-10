import CoreGraphics

@main
struct SquareCaptureCheck {
    static func main() {
        for (input,expected) in [
            (CGRect(x:0,y:0,width:1080,height:1920),CGRect(x:0,y:420,width:1080,height:1080)),
            (CGRect(x:0,y:0,width:1920,height:1080),CGRect(x:420,y:0,width:1080,height:1080)),
            (CGRect(x:20,y:30,width:960,height:960),CGRect(x:20,y:30,width:960,height:960))
        ] {
            let crop=SquareCapture.cropRect(in:input)
            precondition(crop == expected)
            precondition(crop.midX == input.midX && crop.midY == input.midY)
            precondition(input.contains(crop))
        }
        print("Square capture: portrait, landscape and offset bounds passed")
    }
}
