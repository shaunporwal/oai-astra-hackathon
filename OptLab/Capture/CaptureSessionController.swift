import Foundation
import CoreImage
import Observation
import OSLog
import UIKit

private let log = Logger(subsystem: "com.optlab.eyeimaging", category: "capture")

/// Orchestrates one eye's guided capture: frames in, guidance out, photo + analysis when aligned.
@MainActor
@Observable
final class CaptureSessionController {
    enum Phase: Equatable {
        case idle
        case starting
        case live
        case capturing
        case analyzing
        case captured(EyeCapture)
        case failed(String)
    }

    // MARK: Published state
    private(set) var phase: Phase = .idle
    private(set) var guidance: Guidance = .idle
    private(set) var faceVisible = false
    private(set) var guide: GuideGeometry = .standard
    private(set) var profile: CameraProfile?
    private(set) var frameAspectRatio: Double = 0.75
    private(set) var framesPerSecond: Double = 0
    var autoCaptureEnabled = true {
        didSet { engine.autoCaptureEnabled = autoCaptureEnabled }
    }
    var voiceEnabled = true {
        didSet { voice.isEnabled = voiceEnabled }
    }

    let eye: Eye
    let imagingProtocol: ImagingProtocol
    let frameSource: FrameSource

    // MARK: Pipeline
    private let converter = FrameConverter()
    private let pipeline: FramePipeline
    private var engine: AlignmentEngine
    private let voice = VoiceGuidance()
    private var fpsWindow: [TimeInterval] = []
    private var lastLiveObservation: EyeObservation?
    private var lastRotationRate: Double = 0
    private var lastLensPosition: Double?

    init(eye: Eye, imagingProtocol: ImagingProtocol, frameSource: FrameSource? = nil) {
        self.eye = eye
        self.imagingProtocol = imagingProtocol
        #if targetEnvironment(simulator)
        self.frameSource = frameSource ?? SimulatedFrameSource()
        #else
        self.frameSource = frameSource ?? CameraService()
        #endif
        self.pipeline = FramePipeline(eye: eye, converter: converter)
        self.engine = AlignmentEngine(thresholds: imagingProtocol.thresholds, guide: .standard)
    }

    var workingDistanceText: String? {
        guard let profile else { return nil }
        let mm = profile.workingDistanceMm(forIrisFraction: guide.targetIrisRadius * 2)
        return String(format: "≈ %.0f mm", mm)
    }

    var resolutionText: String? {
        guard let profile else { return nil }
        let mmPerPx = profile.mmPerPixel(forIrisFraction: guide.targetIrisRadius * 2)
        return String(format: "%.0f µm / px", mmPerPx * 1000)
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    // MARK: Lifecycle

    func start() async {
        guard phase == .idle || isFailed else { return }
        phase = .starting
        do {
            try await frameSource.start()
            profile = frameSource.profile
            frameAspectRatio = frameSource.frameAspectRatio
            guide = GuideGeometry.adapted(to: frameSource.profile)
            engine = AlignmentEngine(thresholds: imagingProtocol.thresholds, guide: guide, autoCaptureEnabled: autoCaptureEnabled)
            voice.isEnabled = voiceEnabled
            pipeline.start()
            pipeline.onOutput = { [weak self] output in
                Task { @MainActor [weak self] in
                    self?.handle(output)
                }
            }
            frameSource.onFrame = { [weak pipeline] frame in
                pipeline?.enqueue(frame)
            }
            phase = .live
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func stop() {
        frameSource.onFrame = nil
        frameSource.stop()
        pipeline.stop()
        voice.reset()
        if phase == .live || phase == .starting { phase = .idle }
    }

    func retake() {
        engine.reset()
        pipeline.reset()
        voice.reset()
        guidance = .idle
        lastLiveObservation = nil
        frameSource.onFrame = { [weak pipeline] frame in
            pipeline?.enqueue(frame)
        }
        phase = .live
    }

    /// Manual shutter for when auto-capture is disabled or the operator wants to override.
    func captureNow() {
        guard phase == .live else { return }
        engine.markCaptured()
        Task { await performCapture() }
    }

    // MARK: Frame handling (main actor)

    private func handle(_ output: FramePipeline.Output) {
        guard phase == .live else { return }
        let assessment = output.assessment
        let guidance = engine.ingest(assessment)
        self.guidance = guidance
        faceVisible = output.faceVisible
        lastRotationRate = assessment.rotationRate
        lastLensPosition = assessment.lensPosition
        if let obs = assessment.observation {
            lastLiveObservation = obs
            frameSource.setPointOfInterest(obs.irisCenter)
        }
        updateFPS(assessment.timestamp)
        voice.announce(guidance.instruction)
        if guidance.shouldCapture {
            Task { await performCapture() }
        }
    }

    private func updateFPS(_ t: TimeInterval) {
        fpsWindow.append(t)
        if fpsWindow.count > 30 { fpsWindow.removeFirst() }
        if let first = fpsWindow.first, fpsWindow.count > 5, t > first {
            framesPerSecond = Double(fpsWindow.count - 1) / (t - first)
        }
    }

    // MARK: Capture & analysis

    private func performCapture() async {
        guard phase == .live else { return }
        phase = .capturing
        log.notice("capture start eye=\(self.eye.rawValue, privacy: .public) stable=\(self.engine.stableFrames)")
        Haptics.shutter()
        voice.announce(.captured, force: true)
        frameSource.onFrame = nil

        let liveObservation = lastLiveObservation
        let liveMotion = engine.lastMotion
        let rotationRate = lastRotationRate
        let pupilTrace = engine.pupilTrace
        let thresholds = imagingProtocol.thresholds
        let guide = self.guide
        let reference = imagingProtocol.referenceIrisDiameterMm
        let eye = self.eye
        let lens = lastLensPosition
        let converter = self.converter
        let deviceModel = UIDevice.current.model

        do {
            let cgImage = try await frameSource.capturePhoto()
            log.notice("still captured \(cgImage.width)x\(cgImage.height)")
            phase = .analyzing

            let capture = await Task.detached(priority: .userInitiated) { () -> EyeCapture? in
                let started = Date()
                let uiImage = UIImage(cgImage: cgImage)
                let fullSize = CGSize(width: cgImage.width, height: cgImage.height)
                let analysisRGB = converter.rgbImage(from: cgImage, targetWidth: 1024)
                let analysis = EndpointAnalyzer.analyze(
                    image: analysisRGB, fullResolutionSize: fullSize, hint: liveObservation,
                    eye: eye, pupilTraceMm: pupilTrace, referenceHVIDmm: reference
                )
                log.notice("analysis done in \(Date().timeIntervalSince(started), format: .fixed(precision: 2))s found=\(analysis != nil)")
                let quality = CaptureQualityGate.report(
                    cgImage: cgImage, analysisRGB: analysisRGB, analysis: analysis,
                    liveMotion: liveMotion, rotationRate: rotationRate,
                    thresholds: thresholds, guide: guide, converter: converter
                )
                log.notice("quality passed=\(quality.passed) failures=\(quality.failures.joined(separator: ","), privacy: .public)")
                guard let fileName = ImageStore.save(uiImage) else { return nil }
                return EyeCapture(
                    eye: eye,
                    capturedAt: .now,
                    imageFileName: fileName,
                    quality: quality,
                    geometry: analysis?.geometry,
                    scale: analysis?.scale,
                    endpoints: analysis?.endpoints ?? [],
                    pupilTrace: pupilTrace,
                    deviceModel: deviceModel,
                    lensPosition: lens
                )
            }.value

            if let capture {
                log.notice("capture complete eye=\(self.eye.rawValue, privacy: .public)")
                phase = .captured(capture)
            } else {
                log.error("capture could not be saved")
                phase = .failed("The capture could not be saved.")
            }
        } catch {
            log.error("capture failed: \(error.localizedDescription, privacy: .public)")
            phase = .failed(error.localizedDescription)
        }
    }
}

/// Applies the protocol's acceptance criteria to the full-resolution still.
enum CaptureQualityGate {
    static func report(
        cgImage: CGImage,
        analysisRGB: RGBImage,
        analysis: EndpointAnalyzer.Result?,
        liveMotion: Double,
        rotationRate: Double,
        thresholds: QualityThresholds,
        guide: GuideGeometry,
        converter: FrameConverter
    ) -> QualityReport {
        var sharpness = 0.0
        var meanLuma = analysisRGB.gray().mean
        var clipping = 0.0
        var coverageValue = 0.0
        var coverageOK = false
        var coverageDetail = "Eye not located in the still."

        if let g = analysis?.geometry {
            let cx = Double(g.irisCenter.x) / Double(g.imageWidth)
            let cy = Double(g.irisCenter.y) / Double(g.imageHeight)
            let irisFraction = g.irisRadiusPx / Double(g.imageWidth)
            let aspect = Double(g.imageWidth) / Double(g.imageHeight)

            // Focus: Laplacian variance on the iris + adjacent sclera, sampled at the same
            // 192 px scale as the live pipeline so the protocol threshold is comparable.
            let r = irisFraction * 1.5
            let roi = CGRect(x: cx - r, y: cy - r * aspect, width: 2 * r, height: 2 * r * aspect)
            let irisCrop = converter.rgbImage(from: CIImage(cgImage: cgImage), normalizedRect: roi, targetWidth: 192).gray()
            let m = FrameQualityAnalyzer.metrics(for: irisCrop)
            sharpness = m.sharpness
            meanLuma = m.meanLuma
            clipping = m.clipping

            coverageValue = irisFraction / guide.targetIrisRadius
            let margin = irisFraction * 1.15
            let insideFrame = cx - margin > 0 && cx + margin < 1 && cy - margin * aspect > 0 && cy + margin * aspect < 1
            coverageOK = abs(coverageValue - 1) <= thresholds.sizeTolerance * 1.5 && insideFrame
            coverageDetail = insideFrame
                ? String(format: "Iris spans %.0f%% of target.", coverageValue * 100)
                : "Iris touches the frame edge."
        }

        let focus = QualityCheck(
            value: sharpness,
            passed: sharpness >= thresholds.minSharpness,
            detail: String(format: "Sharpness %.2f (min %.2f).", sharpness, thresholds.minSharpness)
        )
        let coverage = QualityCheck(value: coverageValue, passed: coverageOK, detail: coverageDetail)
        let motionOK = liveMotion <= thresholds.maxMotion * 1.5 && rotationRate <= thresholds.maxDeviceRotationRate
        let motion = QualityCheck(
            value: liveMotion,
            passed: motionOK,
            detail: String(format: "Drift %.1f‰ of frame, rotation %.2f rad/s.", liveMotion * 1000, rotationRate)
        )
        let exposureOK = thresholds.exposureRange.contains(meanLuma) && clipping <= thresholds.maxClipping
        let exposure = QualityCheck(
            value: meanLuma,
            passed: exposureOK,
            detail: String(format: "Mean luma %.2f, clipped %.1f%%.", meanLuma, clipping * 100)
        )
        return QualityReport(focus: focus, coverage: coverage, motion: motion, exposure: exposure)
    }
}
