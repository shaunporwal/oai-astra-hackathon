import Foundation
import AVFoundation
import CoreImage
import UIKit

/// AVFoundation-backed frame source tuned for anterior segment macro imaging.
///
/// * Prefers a macro-capable lens (autofocusing ultra-wide on Pro models) and falls back to
///   the wide camera; the guide geometry adapts to whichever lens is chosen.
/// * Restricts autofocus to the near range and follows the iris with the focus/exposure point.
/// * Rotates all connections to portrait so downstream code sees `.up` frames.
/// * Still captures use the format's maximum photo dimensions with quality prioritised.
final class CameraService: NSObject, FrameSource {
    var onFrame: ((CameraFrame) -> Void)?
    private(set) var profile = CameraProfile(
        name: "Camera", horizontalFieldOfView: 70, zoomFactor: 1,
        minimumFocusDistanceMm: nil, photoWidthPx: 4032, isMacroCapable: false
    )
    private(set) var frameAspectRatio: Double = 3.0 / 4.0

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.optlab.camera.session")
    private let videoQueue = DispatchQueue(label: "com.optlab.camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoContinuation: CheckedContinuation<CGImage, Error>?
    private var lastPointOfInterest: CGPoint?

    /// Digital zoom applied on top of the chosen lens. 2× on the ultra-wide roughly doubles
    /// iris coverage without changing the sensor's pixel pitch.
    private let preferredZoom: CGFloat = 2.0

    // MARK: Lifecycle

    func start() async throws {
        try await ensureAuthorization()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    if !self.isConfigured { try self.configure() }
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func ensureAuthorization() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw FrameSourceError.notAuthorized }
        default:
            throw FrameSourceError.notAuthorized
        }
    }

    // MARK: Configuration

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = selectDevice() else { throw FrameSourceError.cameraUnavailable }
        self.device = device

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw FrameSourceError.configurationFailed("input") }
        session.addInput(input)

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        guard session.canAddOutput(videoOutput) else { throw FrameSourceError.configurationFailed("video output") }
        session.addOutput(videoOutput)

        guard session.canAddOutput(photoOutput) else { throw FrameSourceError.configurationFailed("photo output") }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        if let maxDimensions = device.activeFormat.supportedMaxPhotoDimensions.last {
            photoOutput.maxPhotoDimensions = maxDimensions
        }

        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 }) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
        }

        try configureDevice(device)
        isConfigured = true
    }

    private func selectDevice() -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        // Macro-capable = an autofocusing lens that can focus within ~5 cm.
        let macro = discovery.devices.first {
            $0.isFocusModeSupported(.continuousAutoFocus) && $0.minimumFocusDistance > 0 && $0.minimumFocusDistance <= 50
        }
        return macro ?? discovery.devices.first { $0.deviceType == .builtInWideAngleCamera } ?? discovery.devices.first
    }

    private func configureDevice(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
        if device.isSmoothAutoFocusSupported { device.isSmoothAutoFocusEnabled = false }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) { device.whiteBalanceMode = .continuousAutoWhiteBalance }
        if device.hasTorch { device.torchMode = .off }
        device.isSubjectAreaChangeMonitoringEnabled = true

        let zoom = min(preferredZoom, device.activeFormat.videoMaxZoomFactor)
        device.videoZoomFactor = zoom

        let dims = device.activeFormat.supportedMaxPhotoDimensions.last
        let photoWidth = Double(max(dims?.width ?? 4032, dims?.height ?? 3024))
        let videoDims = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        // Portrait after rotation: width is the smaller sensor dimension.
        frameAspectRatio = Double(min(videoDims.width, videoDims.height)) / Double(max(videoDims.width, videoDims.height))

        let minFocus = device.minimumFocusDistance > 0 ? Double(device.minimumFocusDistance) : nil
        profile = CameraProfile(
            name: device.deviceType == .builtInUltraWideCamera ? "Ultra wide (macro)" : "Wide",
            horizontalFieldOfView: Double(device.activeFormat.videoFieldOfView),
            zoomFactor: Double(zoom),
            minimumFocusDistanceMm: minFocus,
            photoWidthPx: photoWidth,
            isMacroCapable: (minFocus ?? 1000) <= 50
        )
    }

    // MARK: Preview & focus

    func makePreviewLayer() -> CALayer {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        previewLayer = layer
        return layer
    }

    func setPointOfInterest(_ point: CGPoint) {
        if let last = lastPointOfInterest, last.distance(to: point) < 0.04 { return }
        lastPointOfInterest = point
        sessionQueue.async { [weak self] in
            guard let self, let device = self.device else { return }
            // Device point-of-interest space is landscape sensor space; with the connection
            // rotated 90° for portrait, (x, y) in the frame maps to (y, 1 − x).
            let devicePoint = CGPoint(x: point.y, y: 1 - point.x)
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                // Non-fatal: continuous AF keeps working without a point of interest.
            }
        }
    }

    // MARK: Still capture

    func capturePhoto() async throws -> CGImage {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            sessionQueue.async {
                guard self.photoContinuation == nil else {
                    continuation.resume(throwing: FrameSourceError.captureFailed)
                    return
                }
                self.photoContinuation = continuation
                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = .quality
                settings.flashMode = .off
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let lens = device.map { Double($0.lensPosition) }
        onFrame?(CameraFrame(image: image, timestamp: timestamp, lensPosition: lens))
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        sessionQueue.async {
            guard let continuation = self.photoContinuation else { return }
            self.photoContinuation = nil
            if let error {
                continuation.resume(throwing: error)
                return
            }
            guard let data = photo.fileDataRepresentation(),
                  let ci = CIImage(data: data, options: [.applyOrientationProperty: true]),
                  let cg = CIContext().createCGImage(ci, from: ci.extent) else {
                continuation.resume(throwing: FrameSourceError.captureFailed)
                return
            }
            continuation.resume(returning: cg)
        }
    }
}
