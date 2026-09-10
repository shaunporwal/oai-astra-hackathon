import Foundation
import CoreImage
import Vision

/// Multimodal eye detector.
///
/// * At arm's length a whole face is visible, so Vision's face-landmark model gives a
///   robust eye region and tells us which eye is which.
/// * At macro working distance (6–10 cm) only the eye fills the frame; there we fall back to
///   `PupilLocalizer`, seeded by the last landmark region when available.
///
/// Both paths end with the same sub-pixel pupil/limbus fit so geometry is consistent.
final class EyeDetector {
    struct Output {
        var observation: EyeObservation?
        /// Downsampled luma of the full frame, reused by callers for photometric metrics.
        var analysisGray: GrayImage
        var faceVisible: Bool
    }

    let analysisWidth: Int
    private let converter: FrameConverter
    private let sequenceHandler = VNSequenceRequestHandler()
    private var lastEyeRegion: CGRect?

    init(converter: FrameConverter, analysisWidth: Int = 320) {
        self.converter = converter
        self.analysisWidth = analysisWidth
    }

    func reset() { lastEyeRegion = nil }

    /// - Parameters:
    ///   - image: A portrait-oriented (`.up`) frame.
    ///   - targetEye: Which eye the protocol is currently capturing.
    func detect(in image: CIImage, targetEye: Eye) -> Output {
        let rgb = converter.rgbImage(from: image, targetWidth: analysisWidth)
        let gray = rgb.gray()
        let w = Double(gray.width), h = Double(gray.height)

        // 1. Face landmarks (arm's length).
        var faceVisible = false
        var landmarkRegion: CGRect?
        var landmarkPupil: CGPoint?
        if let landmarks = detectEyeLandmarks(in: image, targetEye: targetEye) {
            faceVisible = true
            landmarkRegion = landmarks.region
            landmarkPupil = landmarks.pupil
            lastEyeRegion = landmarks.region
        }

        // 2. Choose the search window for the localiser.
        let search: CGRect
        if let landmarkRegion {
            search = landmarkRegion.insetBy(dx: -landmarkRegion.width * 0.35, dy: -landmarkRegion.height * 0.6)
        } else if let lastEyeRegion, faceVisible == false, lastEyeRegion.width > 0.25 {
            // We were close to the face a moment ago; assume the eye is still near where it was.
            search = lastEyeRegion.insetBy(dx: -lastEyeRegion.width * 0.6, dy: -lastEyeRegion.height * 1.0)
        } else {
            search = CGRect(x: 0.06, y: 0.06, width: 0.88, height: 0.88)
        }
        let searchPx = CGRect(x: search.minX * w, y: search.minY * h, width: search.width * w, height: search.height * h)

        // 3. Pupil + limbus fit.
        if let fit = PupilLocalizer.localize(in: gray, searchRegion: searchPx) {
            let obs = EyeObservation(
                irisCenter: CGPoint(x: fit.irisCenter.x / w, y: fit.irisCenter.y / h),
                irisRadius: fit.irisRadius / w,
                pupilCenter: CGPoint(x: fit.pupilCenter.x / w, y: fit.pupilCenter.y / h),
                pupilRadius: fit.pupilRadius / w,
                pupilCircularity: fit.pupilCircularity,
                confidence: faceVisible ? min(1, fit.confidence + 0.2) : fit.confidence,
                source: faceVisible ? .faceLandmarks : .macroLocalizer
            )
            return Output(observation: obs, analysisGray: gray, faceVisible: faceVisible)
        }

        // 4. Landmarks only (eye too small to fit) — enough to say "move closer".
        if let landmarkRegion, let landmarkPupil {
            let irisRadius = landmarkRegion.width * 0.36
            let obs = EyeObservation(
                irisCenter: landmarkPupil,
                irisRadius: irisRadius,
                pupilCenter: landmarkPupil,
                pupilRadius: irisRadius * 0.35,
                pupilCircularity: 1,
                confidence: 0.35,
                source: .faceLandmarks
            )
            return Output(observation: obs, analysisGray: gray, faceVisible: true)
        }

        return Output(observation: nil, analysisGray: gray, faceVisible: false)
    }

    // MARK: Vision

    private struct EyeLandmarks {
        /// Top-left-origin normalised bounding box of the eye contour.
        var region: CGRect
        /// Top-left-origin normalised pupil centre.
        var pupil: CGPoint
    }

    private func detectEyeLandmarks(in image: CIImage, targetEye: Eye) -> EyeLandmarks? {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3
        do {
            try sequenceHandler.perform([request], on: image, orientation: .up)
        } catch {
            return nil
        }
        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
              let landmarks = face.landmarks else { return nil }

        let box = face.boundingBox // normalised, bottom-left origin

        func toTopLeft(_ p: CGPoint) -> CGPoint {
            // Landmark points are normalised to the face bounding box.
            let x = box.minX + p.x * box.width
            let y = box.minY + p.y * box.height
            return CGPoint(x: x, y: 1 - y)
        }

        func summary(_ eye: VNFaceLandmarkRegion2D?, _ pupil: VNFaceLandmarkRegion2D?) -> EyeLandmarks? {
            guard let eye, eye.pointCount > 0 else { return nil }
            let pts = eye.normalizedPoints.map(toTopLeft)
            let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!
            let minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
            let region = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            let pupilPoint: CGPoint
            if let pupil, pupil.pointCount > 0 {
                pupilPoint = toTopLeft(pupil.normalizedPoints[0])
            } else {
                pupilPoint = CGPoint(x: region.midX, y: region.midY)
            }
            return EyeLandmarks(region: region, pupil: pupilPoint)
        }

        let a = summary(landmarks.leftEye, landmarks.leftPupil)
        let b = summary(landmarks.rightEye, landmarks.rightPupil)
        let candidates = [a, b].compactMap { $0 }
        guard !candidates.isEmpty else { return nil }

        // The rear camera is not mirrored, so the participant's right eye is on the image's left.
        // Selecting by position sidesteps any ambiguity in Vision's left/right naming.
        let sorted = candidates.sorted { $0.pupil.x < $1.pupil.x }
        switch targetEye {
        case .right: return sorted.first
        case .left: return sorted.last
        }
    }
}
