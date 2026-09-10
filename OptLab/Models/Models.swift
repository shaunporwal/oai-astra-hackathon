import Foundation
import CoreGraphics

// MARK: - Anatomy

enum Eye: String, Codable, CaseIterable, Identifiable, Hashable {
    /// Oculus dexter — participant's right eye.
    case right = "OD"
    /// Oculus sinister — participant's left eye.
    case left = "OS"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .right: return "Right eye"
        case .left: return "Left eye"
        }
    }

    var shortName: String {
        switch self {
        case .right: return "Right"
        case .left: return "Left"
        }
    }
}

// MARK: - Study structure

struct Participant: Codable, Hashable, Identifiable {
    var id: String
    var studyName: String

    var displayName: String { "Participant \(id)" }
}

struct ProtocolStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var detail: String
}

/// Acceptance criteria applied to every frame during guidance and to the final capture.
struct QualityThresholds: Codable, Hashable {
    /// Minimum normalised Laplacian-variance sharpness (0…1) in the iris region.
    var minSharpness: Double = 0.35
    /// Acceptable mean luma (0…1) window in the eye region.
    var exposureRange: ClosedRange<Double> = 0.22...0.78
    /// Maximum fraction of clipped (near-white) pixels in the eye region.
    var maxClipping: Double = 0.04
    /// Maximum iris-centre drift between consecutive frames, as a fraction of frame width.
    var maxMotion: Double = 0.012
    /// Maximum angular velocity of the device (rad/s) during the hold window.
    var maxDeviceRotationRate: Double = 0.35
    /// Allowed deviation of iris size from the guide, as a ratio (0.1 = ±10 %).
    var sizeTolerance: Double = 0.14
    /// Maximum iris-centre distance from the guide centre, as a fraction of frame width.
    var centerTolerance: Double = 0.045
    /// Number of consecutive compliant frames before auto-capture fires.
    var requiredStableFrames: Int = 12

    static let standard = QualityThresholds()
}

struct ImagingProtocol: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var eyes: [Eye]
    var steps: [ProtocolStep]
    var thresholds: QualityThresholds
    var endpoints: [EndpointKind]
    /// Horizontal visible iris diameter used as the anatomical scale reference (mm).
    var referenceIrisDiameterMm: Double = ScaleCalibration.populationHVIDmm

    static let ocularSurface = ImagingProtocol(
        id: "OSS-03",
        name: "Ocular surface study",
        summary: "Guided anterior segment imaging for ocular surface redness, limbal and pupillary endpoints.",
        eyes: [.right, .left],
        steps: [
            ProtocolStep(title: "Confirm identity and consent", detail: "Verify the participant ID against the visit schedule and confirm consent is on file."),
            ProtocolStep(title: "Ambient light", detail: "Diffuse room light, no direct sun or lamp on the face. The app flags glare and under-exposure."),
            ProtocolStep(title: "Right eye first", detail: "Hold the phone 6–10 cm from the eye. Follow on-screen and voice guidance until the guide ring turns solid."),
            ProtocolStep(title: "Left eye", detail: "Repeat with the participant looking straight ahead, both eyes open."),
            ProtocolStep(title: "Quality gate", detail: "Focus, coverage and motion checks must pass before endpoints are computed."),
        ],
        thresholds: .standard,
        endpoints: EndpointKind.allCases
    )
}

enum SessionStatus: String, Codable {
    case scheduled
    case inProgress
    case complete
}

struct StudySession: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var participant: Participant
    var visitNumber: Int
    var imagingProtocol: ImagingProtocol
    var dueDate: Date
    var consentRecorded: Bool
    var status: SessionStatus = .scheduled
    var captures: [EyeCapture] = []
    var sessionEndpoints: [EndpointMeasurement] = []

    var visitLabel: String { String(format: "Visit %02d", visitNumber) }

    var remainingEyes: [Eye] {
        imagingProtocol.eyes.filter { eye in !captures.contains { $0.eye == eye && $0.quality.passed } }
    }

    var nextEye: Eye? { remainingEyes.first }

    func capture(for eye: Eye) -> EyeCapture? {
        captures.last { $0.eye == eye && $0.quality.passed }
    }

    var isDueToday: Bool { Calendar.current.isDateInToday(dueDate) }
}

// MARK: - Captures

struct QualityCheck: Codable, Hashable {
    var value: Double
    var passed: Bool
    var detail: String
}

struct QualityReport: Codable, Hashable {
    var focus: QualityCheck
    var coverage: QualityCheck
    var motion: QualityCheck
    var exposure: QualityCheck

    var passed: Bool { focus.passed && coverage.passed && motion.passed && exposure.passed }

    var failures: [String] {
        var out: [String] = []
        if !focus.passed { out.append("Focus") }
        if !coverage.passed { out.append("Coverage") }
        if !motion.passed { out.append("Motion") }
        if !exposure.passed { out.append("Exposure") }
        return out
    }
}

/// Pixel-space geometry of the eye in the captured full-resolution image.
struct EyeGeometry: Codable, Hashable {
    var imageWidth: Int
    var imageHeight: Int
    var irisCenter: CGPoint
    var irisRadiusPx: Double
    var pupilCenter: CGPoint
    var pupilRadiusPx: Double
    var pupilCircularity: Double

    var irisDiameterPx: Double { irisRadiusPx * 2 }
    var pupilDiameterPx: Double { pupilRadiusPx * 2 }
}

struct ScaleCalibration: Codable, Hashable {
    enum Method: String, Codable {
        /// Scale derived from the population-mean horizontal visible iris diameter.
        case anatomicalHVID
    }

    /// Population mean horizontal visible iris diameter (white-to-white), mm.
    static let populationHVIDmm = 11.71
    /// One standard deviation of HVID in adults, mm. Drives the reported scale uncertainty.
    static let populationHVIDSDmm = 0.42

    var mmPerPixel: Double
    var method: Method
    /// Relative 1-σ uncertainty of the scale (e.g. 0.036 = 3.6 %).
    var relativeUncertainty: Double

    init(irisDiameterPx: Double, referenceHVIDmm: Double = ScaleCalibration.populationHVIDmm) {
        mmPerPixel = referenceHVIDmm / max(irisDiameterPx, 1)
        method = .anatomicalHVID
        relativeUncertainty = ScaleCalibration.populationHVIDSDmm / referenceHVIDmm
    }

    func mm(fromPixels px: Double) -> Double { px * mmPerPixel }
    /// Smallest resolvable distance given the pixel pitch: the "sub-millimetre" figure of merit.
    var resolutionMm: Double { mmPerPixel }
}

struct EyeCapture: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var eye: Eye
    var capturedAt: Date
    var imageFileName: String
    var quality: QualityReport
    var geometry: EyeGeometry?
    var scale: ScaleCalibration?
    var endpoints: [EndpointMeasurement] = []
    /// Pupil diameter samples (mm) recorded during the hold window preceding capture.
    var pupilTrace: [Double] = []
    var deviceModel: String
    var lensPosition: Double?
}

// MARK: - Endpoints

enum EndpointDomain: String, Codable, CaseIterable, Identifiable {
    case drugEfficacy
    case metabolic
    case neuroTrauma
    case anatomy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drugEfficacy: return "Drug efficacy"
        case .metabolic: return "Metabolic markers"
        case .neuroTrauma: return "Neuro-trauma"
        case .anatomy: return "Anatomical reference"
        }
    }

    var systemImage: String {
        switch self {
        case .drugEfficacy: return "pills"
        case .metabolic: return "drop"
        case .neuroTrauma: return "brain.head.profile"
        case .anatomy: return "ruler"
        }
    }
}

enum EndpointKind: String, Codable, CaseIterable, Identifiable {
    case irisDiameter
    case pupilDiameter
    case pupilIrisRatio
    case pupilCircularity
    case pupilVariability
    case conjunctivalRedness
    case scleralVesselDensity
    case limbalArcusIndex
    case scleralYellowness
    case anisocoria

    var id: String { rawValue }

    var title: String {
        switch self {
        case .irisDiameter: return "Iris diameter (HVID)"
        case .pupilDiameter: return "Pupil diameter"
        case .pupilIrisRatio: return "Pupil / iris ratio"
        case .pupilCircularity: return "Pupil circularity"
        case .pupilVariability: return "Pupil size variability"
        case .conjunctivalRedness: return "Conjunctival redness index"
        case .scleralVesselDensity: return "Scleral vessel density"
        case .limbalArcusIndex: return "Limbal arcus index"
        case .scleralYellowness: return "Scleral yellowness"
        case .anisocoria: return "Anisocoria (OD − OS)"
        }
    }

    var unit: String {
        switch self {
        case .irisDiameter, .pupilDiameter, .anisocoria: return "mm"
        case .pupilIrisRatio, .pupilCircularity: return ""
        case .pupilVariability: return "% CV"
        case .conjunctivalRedness, .limbalArcusIndex, .scleralYellowness: return "index"
        case .scleralVesselDensity: return "%"
        }
    }

    var domain: EndpointDomain {
        switch self {
        case .irisDiameter: return .anatomy
        case .pupilDiameter, .pupilIrisRatio, .pupilCircularity, .pupilVariability, .anisocoria: return .neuroTrauma
        case .conjunctivalRedness, .scleralVesselDensity: return .drugEfficacy
        case .limbalArcusIndex, .scleralYellowness: return .metabolic
        }
    }

    var explanation: String {
        switch self {
        case .irisDiameter: return "White-to-white iris width; used as the anatomical scale reference for all millimetre measurements."
        case .pupilDiameter: return "Absolute pupil diameter under ambient light. Serial change and left–right asymmetry are the trial-relevant signals."
        case .pupilIrisRatio: return "Scale-free pupil size; robust to any residual calibration error."
        case .pupilCircularity: return "Ratio of minimum to maximum pupil radius about the centroid. A round pupil scores 1.0; irregular pupils fall below."
        case .pupilVariability: return "Coefficient of variation of pupil diameter across the pre-capture hold window (physiological hippus)."
        case .conjunctivalRedness: return "Relative red chromaticity of the exposed bulbar conjunctiva, nasal and temporal sectors."
        case .scleralVesselDensity: return "Fraction of conjunctival area occupied by vessel-contrast pixels."
        case .limbalArcusIndex: return "Brightness of the peripheral corneal ring relative to the mid-iris — a marker of corneal arcus."
        case .scleralYellowness: return "Blue-deficit of the sclera relative to a neutral white; tracks scleral icterus."
        case .anisocoria: return "Right-minus-left pupil diameter under matched lighting."
        }
    }

    /// Whether this endpoint is derived from a pair of eyes rather than a single capture.
    var isSessionLevel: Bool { self == .anisocoria }

    /// Whether the numeric value is on a millimetre scale (affects displayed precision).
    var isSubMillimetre: Bool { unit == "mm" }
}

struct EndpointMeasurement: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var kind: EndpointKind
    var value: Double
    /// 1-σ uncertainty in the same unit as `value`, when meaningful.
    var uncertainty: Double?
    /// 0…1 analyst confidence in the measurement.
    var confidence: Double
    var eye: Eye?

    var formattedValue: String {
        switch kind {
        case .irisDiameter, .pupilDiameter, .anisocoria:
            return String(format: "%.2f", value)
        case .pupilIrisRatio, .pupilCircularity:
            return String(format: "%.3f", value)
        case .pupilVariability, .scleralVesselDensity:
            return String(format: "%.1f", value)
        case .conjunctivalRedness, .limbalArcusIndex, .scleralYellowness:
            return String(format: "%.0f", value)
        }
    }

    var formattedUncertainty: String? {
        guard let uncertainty else { return nil }
        return String(format: "± %.2f", uncertainty)
    }
}
