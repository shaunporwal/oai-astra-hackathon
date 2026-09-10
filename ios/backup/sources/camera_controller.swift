import AVFoundation
import UIKit
import SwiftUI

/// Camera ownership stays here; networking and clinical measurements live elsewhere.
final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var latestJPEG: Data?
    @Published var status = "Camera stopped"
    @Published var running = false
    @Published var focusLocked = false
    private let queue = DispatchQueue(label: "eye.backup.camera")
    private let context = CIContext()
    private var device: AVCaptureDevice?
    private var configured = false
    private var lastFrame = CMTime.zero

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            guard allowed else { self.report("Camera access denied. Enable it in Settings."); return }
            self.queue.async {
                do {
                    if !self.configured { try self.configure() }
                    if !self.session.isRunning { self.session.startRunning() }
                    DispatchQueue.main.async { self.running = true; self.status = "Rear wide camera · 1× · attach macro lens here" }
                } catch { self.report("Camera unavailable: \(error.localizedDescription)") }
            }
        }
    }
    func stop() {
        queue.async {
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.running = false; self.latestJPEG = nil; self.status = "Camera stopped" }
        }
    }
    private func configure() throws {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraFailure.missingRearCamera
        }
        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration(); defer { session.commitConfiguration() }
        session.sessionPreset = .hd1920x1080
        guard session.canAddInput(input) else { throw CameraFailure.configuration }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { session.removeInput(input); throw CameraFailure.configuration }
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        device = camera; configured = true
        try camera.lockForConfiguration(); defer { camera.unlockForConfiguration() }
        camera.videoZoomFactor = 1
        if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
        if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
    }
    func setFocusLocked(_ locked: Bool) {
        queue.async {
            guard let device = self.device else { return }
            let mode: AVCaptureDevice.FocusMode = locked ? .locked : .continuousAutoFocus
            guard device.isFocusModeSupported(mode) else { self.report("Focus mode unsupported"); return }
            do {
                try device.lockForConfiguration(); device.focusMode = mode; device.unlockForConfiguration()
                DispatchQueue.main.async { self.focusLocked = locked }
            } catch { self.report("Could not change focus") }
        }
    }
    func setExposure(_ bias: Float) {
        queue.async {
            guard let device = self.device else { return }
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(min(device.maxExposureTargetBias,max(device.minExposureTargetBias,bias)))
                device.unlockForConfiguration()
            } catch { self.report("Could not change exposure") }
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard CMTimeGetSeconds(timestamp-lastFrame) >= 0.3, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrame = timestamp
        let image = CIImage(cvPixelBuffer: buffer)
        let scale = min(1,960/max(image.extent.width,image.extent.height))
        let resized = image.transformed(by: CGAffineTransform(scaleX: scale,y: scale))
        guard let cg = context.createCGImage(resized, from: resized.extent), let jpeg = UIImage(cgImage: cg).jpegData(compressionQuality: 0.92) else { return }
        DispatchQueue.main.async { self.latestJPEG = jpeg }
    }
    private func report(_ text: String) { DispatchQueue.main.async { self.status = text } }
    enum CameraFailure: LocalizedError {
        case missingRearCamera, configuration
        var errorDescription: String? { "A rear camera is required; use a physical iPhone." }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewSurface { let view=PreviewSurface();view.layerVideo.session=session;view.layerVideo.videoGravity = .resizeAspect;return view }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {}
}
final class PreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var layerVideo: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection=layerVideo.connection,connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle=90 }
    }
}
