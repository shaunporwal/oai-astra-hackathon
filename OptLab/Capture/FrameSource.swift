import Foundation
import CoreImage
import QuartzCore

/// One live frame, already rotated to portrait (`.up`).
struct CameraFrame {
    let image: CIImage
    let timestamp: TimeInterval
    /// 0 (infinity) … 1 (closest) when the camera reports it.
    let lensPosition: Double?
}

/// Static description of the optics in use, surfaced in the UI and used to adapt the guide.
struct CameraProfile: Equatable {
    var name: String
    /// Horizontal field of view in degrees at zoom factor 1.
    var horizontalFieldOfView: Double
    var zoomFactor: Double
    /// Closest focus distance in millimetres, if known.
    var minimumFocusDistanceMm: Double?
    /// Full-resolution photo width in pixels.
    var photoWidthPx: Double
    var isMacroCapable: Bool

    /// Physical width of the scene captured across the frame at `distanceMm`.
    func frameWidthMm(atDistance distanceMm: Double) -> Double {
        let halfFOV = horizontalFieldOfView / 2 * .pi / 180
        return 2 * distanceMm * tan(halfFOV) / zoomFactor
    }

    /// Working distance at which an iris of `hvidMm` spans `fraction` of the frame width.
    func workingDistanceMm(forIrisFraction fraction: Double, hvidMm: Double = ScaleCalibration.populationHVIDmm) -> Double {
        let halfFOV = horizontalFieldOfView / 2 * .pi / 180
        return hvidMm * zoomFactor / (2 * fraction * tan(halfFOV))
    }

    /// Millimetres per full-resolution pixel when the iris fills `fraction` of the frame.
    func mmPerPixel(forIrisFraction fraction: Double, hvidMm: Double = ScaleCalibration.populationHVIDmm) -> Double {
        hvidMm / (fraction * photoWidthPx)
    }
}

extension GuideGeometry {
    /// Chooses the largest iris target the optics can focus on, so the guide never asks the
    /// operator to move inside the lens's minimum focus distance.
    static func adapted(to profile: CameraProfile, preferredRadius: Double = 0.19, minimumRadius: Double = 0.06) -> GuideGeometry {
        var radius = preferredRadius
        if let minFocus = profile.minimumFocusDistanceMm {
            // Keep a 15 % margin beyond the minimum focus distance.
            let safeDistance = minFocus * 1.15
            let fractionAtSafeDistance = ScaleCalibration.populationHVIDmm / profile.frameWidthMm(atDistance: safeDistance)
            radius = min(preferredRadius, fractionAtSafeDistance / 2)
        }
        return GuideGeometry(center: CGPoint(x: 0.5, y: 0.5), targetIrisRadius: max(radius, minimumRadius))
    }
}

enum FrameSourceError: LocalizedError {
    case cameraUnavailable
    case notAuthorized
    case configurationFailed(String)
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return "No rear camera is available on this device."
        case .notAuthorized: return "Camera access is required for guided capture. Enable it in Settings."
        case .configurationFailed(let why): return "Camera configuration failed: \(why)"
        case .captureFailed: return "The photo could not be captured."
        }
    }
}

/// Anything that can deliver live frames and full-resolution stills.
protocol FrameSource: AnyObject {
    var onFrame: ((CameraFrame) -> Void)? { get set }
    var profile: CameraProfile { get }
    /// Frame aspect ratio (width / height) of live frames.
    var frameAspectRatio: Double { get }

    func start() async throws
    func stop()
    /// A layer that displays the live feed; the caller sizes and installs it.
    func makePreviewLayer() -> CALayer
    /// Requests focus and exposure at a top-left-origin normalised point in the frame.
    func setPointOfInterest(_ point: CGPoint)
    /// Captures a full-resolution portrait still.
    func capturePhoto() async throws -> CGImage
}
