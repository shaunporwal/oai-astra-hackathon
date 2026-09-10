import Foundation
import CoreGraphics

/// Eye geometry in frame-normalised coordinates: origin top-left, x and y in 0…1 of the
/// frame's width and height respectively; radii are fractions of the frame width.
struct EyeObservation: Equatable {
    enum Source: String { case faceLandmarks, macroLocalizer, synthetic }

    var irisCenter: CGPoint
    var irisRadius: Double
    var pupilCenter: CGPoint
    var pupilRadius: Double
    var pupilCircularity: Double
    var confidence: Double
    var source: Source

    /// Pupil diameter in millimetres using the anatomical iris reference — scale-free, so
    /// it can be tracked frame-to-frame before any photo is taken.
    func pupilDiameterMm(referenceHVID: Double = ScaleCalibration.populationHVIDmm) -> Double {
        guard irisRadius > 0 else { return 0 }
        return (pupilRadius / irisRadius) * referenceHVID
    }
}

/// Everything the alignment engine needs to know about one frame.
struct FrameAssessment {
    var timestamp: TimeInterval
    var observation: EyeObservation?
    var quality: FrameQualityMetrics
    /// Device angular velocity magnitude (rad/s), from CoreMotion; 0 when unavailable.
    var rotationRate: Double
    /// Lens position 0 (far) … 1 (near) reported by the camera; nil when unknown.
    var lensPosition: Double?
}

/// Where the on-screen guide ring sits, in frame-normalised coordinates.
struct GuideGeometry: Equatable {
    var center: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// Target iris radius as a fraction of frame width. 0.21 → iris spans 42 % of the frame,
    /// which on a 12 MP sensor yields ≈7 µm per pixel across an 11.7 mm iris.
    var targetIrisRadius: Double = 0.21

    static let standard = GuideGeometry()
}

enum Instruction: Equatable {
    case searching
    case moveCloser(slightly: Bool)
    case moveBack(slightly: Bool)
    case move(dx: Double, dy: Double)
    case moreLight
    case tooBright
    case holdStill
    case focusing
    case aligned
    case captured

    var headline: String {
        switch self {
        case .searching: return "Find the eye."
        case .moveCloser(let slightly): return slightly ? "Move slightly closer." : "Move closer."
        case .moveBack(let slightly): return slightly ? "Move slightly back." : "Move back."
        case .move(let dx, let dy):
            if abs(dx) >= abs(dy) { return dx < 0 ? "Move left." : "Move right." }
            return dy < 0 ? "Move up." : "Move down."
        case .moreLight: return "Need more light."
        case .tooBright: return "Reduce glare."
        case .holdStill: return "Hold still."
        case .focusing: return "Focusing…"
        case .aligned: return "Aligned. Hold."
        case .captured: return "Captured."
        }
    }

    var detail: String {
        switch self {
        case .searching: return "Point the camera at the eye, 6–10 cm away."
        case .moveCloser, .moveBack: return "Keep the eye inside the guide."
        case .move: return "Centre the iris in the ring."
        case .moreLight: return "Face diffuse room light, avoid shadows."
        case .tooBright: return "Angle away from direct light sources."
        case .holdStill: return "Brace your elbows and breathe out."
        case .focusing: return "Small movements help the lens lock."
        case .aligned: return "Auto-capture in a moment."
        case .captured: return "Checking image quality."
        }
    }

    /// Short arrow-glyph label rendered under the guide ring.
    var arrowSymbol: String? {
        switch self {
        case .moveCloser: return "arrow.down"
        case .moveBack: return "arrow.up"
        case .move(let dx, let dy):
            if abs(dx) >= abs(dy) { return dx < 0 ? "arrow.left" : "arrow.right" }
            return dy < 0 ? "arrow.up" : "arrow.down"
        default: return nil
        }
    }

    var arrowLabel: String? {
        switch self {
        case .moveCloser: return "Move closer"
        case .moveBack: return "Move back"
        case .move: return "Centre"
        default: return nil
        }
    }
}

struct Guidance: Equatable {
    var instruction: Instruction
    var eyeDetected: Bool
    var lightingReady: Bool
    var focusReady: Bool
    var positionReady: Bool
    var motionReady: Bool
    /// 0…1 progress towards the stable-frame requirement.
    var alignmentProgress: Double
    var stableFrames: Int
    /// True on exactly one frame, when the engine decides a photo should be taken.
    var shouldCapture: Bool
    /// Observed iris size relative to the guide (1 = perfect).
    var sizeRatio: Double?
    var observation: EyeObservation?

    static let idle = Guidance(
        instruction: .searching, eyeDetected: false, lightingReady: false, focusReady: false,
        positionReady: false, motionReady: false, alignmentProgress: 0, stableFrames: 0,
        shouldCapture: false, sizeRatio: nil, observation: nil
    )
}

/// Pure, deterministic state machine that converts frame assessments into guidance and
/// decides when the capture should fire. No UI or camera dependencies, so it is fully testable.
final class AlignmentEngine {
    let thresholds: QualityThresholds
    let guide: GuideGeometry
    var autoCaptureEnabled: Bool

    private(set) var stableFrames = 0
    private(set) var hasCaptured = false
    private var lastObservation: EyeObservation?
    private var lastTimestamp: TimeInterval?
    /// Pupil diameter (mm) samples collected while the eye is held in position.
    private(set) var pupilTrace: [Double] = []
    private(set) var lastMotion: Double = 0

    init(thresholds: QualityThresholds = .standard, guide: GuideGeometry = .standard, autoCaptureEnabled: Bool = true) {
        self.thresholds = thresholds
        self.guide = guide
        self.autoCaptureEnabled = autoCaptureEnabled
    }

    func reset() {
        stableFrames = 0
        hasCaptured = false
        lastObservation = nil
        lastTimestamp = nil
        pupilTrace = []
        lastMotion = 0
    }

    /// Marks the engine as having captured, e.g. after a manual shutter press.
    func markCaptured() { hasCaptured = true }

    func ingest(_ frame: FrameAssessment) -> Guidance {
        defer {
            lastObservation = frame.observation
            lastTimestamp = frame.timestamp
        }

        if hasCaptured {
            return Guidance(
                instruction: .captured, eyeDetected: frame.observation != nil, lightingReady: true,
                focusReady: true, positionReady: true, motionReady: true, alignmentProgress: 1,
                stableFrames: stableFrames, shouldCapture: false, sizeRatio: nil, observation: frame.observation
            )
        }

        guard let obs = frame.observation, obs.confidence > 0.2 else {
            decayStability(hard: true)
            return Guidance(
                instruction: .searching, eyeDetected: false,
                lightingReady: lightingOK(frame.quality), focusReady: false, positionReady: false,
                motionReady: false, alignmentProgress: 0, stableFrames: 0, shouldCapture: false,
                sizeRatio: nil, observation: nil
            )
        }

        // --- Position
        let sizeRatio = obs.irisRadius / guide.targetIrisRadius
        let sizeError = sizeRatio - 1
        let offset = CGPoint(x: obs.irisCenter.x - guide.center.x, y: obs.irisCenter.y - guide.center.y)
        let centerError = Double(hypot(offset.x, offset.y))
        let sizeOK = abs(sizeError) <= thresholds.sizeTolerance
        let centerOK = centerError <= thresholds.centerTolerance
        let positionReady = sizeOK && centerOK

        // --- Lighting / focus / motion
        let lightingReady = lightingOK(frame.quality)
        let focusReady = frame.quality.sharpness >= thresholds.minSharpness

        var motion = 0.0
        if let last = lastObservation {
            motion = obs.irisCenter.distance(to: last.irisCenter)
        }
        lastMotion = motion
        let motionReady = motion <= thresholds.maxMotion && frame.rotationRate <= thresholds.maxDeviceRotationRate

        // --- Instruction priority: get in position, then light, then steadiness, then focus.
        let instruction: Instruction
        if !sizeOK {
            if sizeError < 0 {
                instruction = .moveCloser(slightly: sizeError > -0.3)
            } else {
                instruction = .moveBack(slightly: sizeError < 0.3)
            }
        } else if !centerOK {
            instruction = .move(dx: Double(offset.x), dy: Double(offset.y))
        } else if !lightingReady {
            instruction = frame.quality.meanLuma < thresholds.exposureRange.lowerBound ? .moreLight : .tooBright
        } else if !motionReady {
            instruction = .holdStill
        } else if !focusReady {
            instruction = .focusing
        } else {
            instruction = .aligned
        }

        let allReady = positionReady && lightingReady && focusReady && motionReady
        if allReady {
            stableFrames += 1
            pupilTrace.append(obs.pupilDiameterMm())
            if pupilTrace.count > 90 { pupilTrace.removeFirst(pupilTrace.count - 90) }
        } else {
            decayStability(hard: !positionReady)
        }

        var shouldCapture = false
        if autoCaptureEnabled, allReady, stableFrames >= thresholds.requiredStableFrames {
            shouldCapture = true
            hasCaptured = true
        }

        return Guidance(
            instruction: shouldCapture ? .captured : instruction,
            eyeDetected: true,
            lightingReady: lightingReady,
            focusReady: focusReady,
            positionReady: positionReady,
            motionReady: motionReady,
            alignmentProgress: (Double(stableFrames) / Double(thresholds.requiredStableFrames)).clamped(to: 0...1),
            stableFrames: stableFrames,
            shouldCapture: shouldCapture,
            sizeRatio: sizeRatio,
            observation: obs
        )
    }

    private func lightingOK(_ q: FrameQualityMetrics) -> Bool {
        thresholds.exposureRange.contains(q.meanLuma) && q.clipping <= thresholds.maxClipping
    }

    private func decayStability(hard: Bool) {
        if hard {
            stableFrames = 0
            pupilTrace.removeAll(keepingCapacity: true)
        } else {
            stableFrames = max(0, stableFrames - 2)
        }
    }
}
