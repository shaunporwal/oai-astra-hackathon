import Foundation
import CoreImage
import CoreMotion

/// Background stage of the capture loop: detection + per-frame metrics. Runs on its own
/// serial queue, drops frames when it falls behind, and hands a `FrameAssessment` to the
/// main-actor controller.
final class FramePipeline {
    struct Output {
        var assessment: FrameAssessment
        var faceVisible: Bool
    }

    var onOutput: ((Output) -> Void)?

    private let eye: Eye
    private let converter: FrameConverter
    private let detector: EyeDetector
    private let queue = DispatchQueue(label: "com.optlab.capture.pipeline", qos: .userInitiated)
    private let motion = CMMotionManager()
    private var isProcessing = false
    private var rotationRate: Double = 0

    init(eye: Eye, converter: FrameConverter) {
        self.eye = eye
        self.converter = converter
        self.detector = EyeDetector(converter: converter)
    }

    func start() {
        detector.reset()
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: OperationQueue()) { [weak self] data, _ in
            guard let self, let rate = data?.rotationRate else { return }
            let magnitude = (rate.x * rate.x + rate.y * rate.y + rate.z * rate.z).squareRoot()
            self.queue.async { self.rotationRate = magnitude }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
    }

    func reset() {
        queue.async { self.detector.reset() }
    }

    func enqueue(_ frame: CameraFrame) {
        queue.async { [weak self] in
            guard let self, !self.isProcessing else { return }
            self.isProcessing = true
            defer { self.isProcessing = false }
            self.process(frame)
        }
    }

    private func process(_ frame: CameraFrame) {
        let output = detector.detect(in: frame.image, targetEye: eye)

        let metrics: FrameQualityMetrics
        if let obs = output.observation {
            // Focus and exposure are judged on the iris plus adjacent sclera (1.5 × iris radius).
            let r = obs.irisRadius * 1.5
            let aspect = Double(frame.image.extent.width / max(frame.image.extent.height, 1))
            let roi = CGRect(x: obs.irisCenter.x - r, y: obs.irisCenter.y - r * aspect, width: 2 * r, height: 2 * r * aspect)
            let roiRGB = converter.rgbImage(from: frame.image, normalizedRect: roi, targetWidth: 192)
            metrics = FrameQualityAnalyzer.metrics(for: roiRGB.gray())
        } else {
            metrics = FrameQualityMetrics(
                sharpness: 0,
                meanLuma: output.analysisGray.mean,
                clipping: FrameQualityAnalyzer.clippingFraction(of: output.analysisGray)
            )
        }

        let assessment = FrameAssessment(
            timestamp: frame.timestamp,
            observation: output.observation,
            quality: metrics,
            rotationRate: rotationRate,
            lensPosition: frame.lensPosition
        )
        onOutput?(Output(assessment: assessment, faceVisible: output.faceVisible))
    }
}
