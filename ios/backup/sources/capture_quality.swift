import Foundation

/// Engineering capture gates, not eye detection or diagnostic adequacy.
struct CaptureQuality {
    let sharpness: Double
    let mean: Double
    let clippedFraction: Double
    let darkFraction: Double
    let pixels: [UInt8]
    let focusSettled: Bool

    static func measure(_ pixels: [UInt8], side: Int, focusSettled: Bool) -> CaptureQuality {
        precondition(side > 2 && pixels.count == side*side)
        let values=pixels.map(Double.init)
        var sum=0.0, squares=0.0, count=0.0
        for y in 1..<(side-1) {
            for x in 1..<(side-1) {
                let i=y*side+x
                let lap=values[i-1]+values[i+1]+values[i-side]+values[i+side]-4*values[i]
                sum+=lap;squares+=lap*lap;count+=1
            }
        }
        return CaptureQuality(sharpness:max(0,squares/count-pow(sum/count,2)),mean:values.reduce(0,+)/Double(values.count),clippedFraction:Double(pixels.filter {$0 >= 248}.count)/Double(pixels.count),darkFraction:Double(pixels.filter {$0 < 25}.count)/Double(pixels.count),pixels:pixels,focusSettled:focusSettled)
    }
    var guidance: String {
        if !focusSettled { return "Waiting for autofocus / exposure" }
        if mean < 45 || darkFraction > 0.35 { return "Increase light on the eye" }
        if mean > 225 || clippedFraction > 0.08 { return "Reduce bright reflections" }
        if sharpness < 80 { return "Move slowly to sharpen detail" }
        return "Detail and exposure ready · hold still"
    }
    var eligible: Bool { focusSettled && mean >= 45 && mean <= 225 && darkFraction <= 0.35 && clippedFraction <= 0.08 && sharpness >= 80 }
}

struct CaptureSample {
    let jpeg: Data
    let quality: CaptureQuality
    let time: Double
}

struct StableCaptureGate {
    private var previous: CaptureSample?
    private var best: CaptureSample?
    private var start=0.0
    private(set) var count=0

    mutating func reset() { previous=nil;best=nil;count=0;start=0 }
    mutating func accept(_ sample: CaptureSample) -> Data? {
        guard sample.quality.eligible else { reset();return nil }
        var stable=false
        if let previous, sample.time > previous.time, sample.time-previous.time <= 0.6,
           previous.quality.pixels.count == sample.quality.pixels.count {
            let motion=zip(previous.quality.pixels,sample.quality.pixels).reduce(0.0) { $0+abs(Double($1.0)-Double($1.1)) } / Double(sample.quality.pixels.count)
            stable=motion <= 5
        }
        if !stable { count=0;start=sample.time;best=nil }
        count+=1;previous=sample
        if best == nil || sample.quality.sharpness > best!.quality.sharpness { best=sample }
        guard count >= 4, sample.time-start >= 0.8 else { return nil }
        let jpeg=best?.jpeg;reset();return jpeg
    }
}
