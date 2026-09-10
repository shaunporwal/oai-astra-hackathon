import Foundation

@main
struct CaptureQualityCheck {
    static func main() {
        let side=16
        let sharp=(0..<(side*side)).map { UInt8(($0%side)/2%2 == 0 ? 100 : 150) }
        let q=CaptureQuality.measure(sharp,side:side,focusSettled:true)
        precondition(q.eligible)
        precondition(!CaptureQuality.measure(sharp,side:side,focusSettled:false).eligible)
        for level:UInt8 in [0,120,255] {
            precondition(!CaptureQuality.measure([UInt8](repeating:level,count:side*side),side:side,focusSettled:true).eligible)
        }
        var gate=StableCaptureGate()
        func sample(_ time:Double,_ quality:CaptureQuality=q,_ id:UInt8=1) -> CaptureSample {
            CaptureSample(jpeg:Data([id]),quality:quality,time:time)
        }
        precondition(gate.accept(sample(0)) == nil)
        precondition(gate.accept(sample(0.3)) == nil)
        let sharper=CaptureQuality(sharpness:q.sharpness+1,mean:q.mean,clippedFraction:0,darkFraction:0,pixels:sharp,focusSettled:true)
        precondition(gate.accept(sample(0.6,sharper,2)) == nil)
        precondition(gate.accept(sample(0.9)) == Data([2]))
        precondition(gate.count == 0)
        _=gate.accept(sample(1))
        let moved=CaptureQuality.measure(sharp.map {$0+20},side:side,focusSettled:true)
        precondition(gate.accept(sample(1.3,moved)) == nil && gate.count == 1)
        precondition(gate.accept(sample(3,moved)) == nil && gate.count == 1)
        let blurred=CaptureQuality.measure([UInt8](repeating:120,count:side*side),side:side,focusSettled:true)
        precondition(gate.accept(sample(3.3,blurred)) == nil && gate.count == 0)
        _=gate.accept(sample(4));gate.reset()
        precondition(gate.count == 0)
        print("Capture gates: focus/exposure/blur rejection, stability, gaps, reset and exact best JPEG passed")
    }
}
