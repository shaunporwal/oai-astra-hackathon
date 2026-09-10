import Foundation
import CoreImage
import QuartzCore
import UIKit

/// Frame source for the simulator and previews. Plays a scripted approach: the eye starts
/// small and off-centre, drifts into the guide over a few seconds, then holds with realistic
/// hand tremor so the real detection → guidance → auto-capture pipeline runs unmodified.
final class SimulatedFrameSource: FrameSource {
    var onFrame: ((CameraFrame) -> Void)?
    let profile = CameraProfile(
        name: "Simulated macro",
        horizontalFieldOfView: 104,
        zoomFactor: 2,
        minimumFocusDistanceMm: 20,
        photoWidthPx: 3024,
        isMacroCapable: true
    )
    let frameAspectRatio: Double = 3.0 / 4.0

    private let frameSize = CGSize(width: 480, height: 640)
    private let photoSize = CGSize(width: 3024, height: 4032)
    private let previewLayer = CALayer()
    private var timer: Timer?
    private var startTime: TimeInterval = 0
    private var scene = SyntheticEyeRenderer.Scene()
    private let queue = DispatchQueue(label: "com.optlab.simulated", qos: .userInitiated)
    private var rng = SeededGenerator(seed: 42)
    /// Iris size the script converges on; matched to the adapted guide for this profile.
    var targetIrisRadius: Double = GuideGeometry.adapted(to: CameraProfile(
        name: "", horizontalFieldOfView: 104, zoomFactor: 2, minimumFocusDistanceMm: 20, photoWidthPx: 3024, isMacroCapable: true
    )).targetIrisRadius

    func start() async throws {
        startTime = CACurrentMediaTime()
        await MainActor.run {
            previewLayer.contentsGravity = .resizeAspectFill
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func makePreviewLayer() -> CALayer { previewLayer }

    func setPointOfInterest(_ point: CGPoint) {}

    func capturePhoto() async throws -> CGImage {
        var still = scene
        still.blur = 0
        let size = photoSize
        return await Task.detached(priority: .userInitiated) {
            SyntheticEyeRenderer.render(size: size, scene: still)
        }.value
    }

    // MARK: Script

    private func tick() {
        let t = CACurrentMediaTime() - startTime
        scene = scriptedScene(at: t)
        let size = frameSize
        let sceneCopy = scene
        queue.async { [weak self] in
            guard let self else { return }
            let cg = SyntheticEyeRenderer.render(size: size, scene: sceneCopy)
            DispatchQueue.main.async { self.previewLayer.contents = cg }
            self.onFrame?(CameraFrame(image: CIImage(cgImage: cg), timestamp: t, lensPosition: 0.8))
        }
    }

    private func scriptedScene(at t: TimeInterval) -> SyntheticEyeRenderer.Scene {
        var s = SyntheticEyeRenderer.Scene()
        s.arcus = 0.25
        s.redness = 0.2
        // Phase 1 (0–1.5 s): far and off-centre. Phase 2 (1.5–4.5 s): ease in. Phase 3: hold.
        let approach = smoothstep((t - 1.5) / 3.0)
        let startRadius = targetIrisRadius * 0.55
        s.irisRadius = startRadius + (targetIrisRadius - startRadius) * approach
        let startCenter = CGPoint(x: 0.36, y: 0.40)
        s.irisCenter = CGPoint(
            x: startCenter.x + (0.5 - startCenter.x) * approach,
            y: startCenter.y + (0.5 - startCenter.y) * approach
        )
        // Hand tremor: ~1.5 % of the iris radius, well inside the motion threshold.
        let tremor = 0.003 * (1 - 0.6 * approach)
        s.irisCenter.x += tremor * sin(t * 9.1) + 0.0007 * Double.random(in: -1...1, using: &rng)
        s.irisCenter.y += tremor * cos(t * 7.3) + 0.0007 * Double.random(in: -1...1, using: &rng)
        // Physiological hippus on the pupil.
        s.pupilRatio = 0.36 + 0.012 * sin(t * 1.7)
        // Focus hunts while approaching, then locks.
        s.blur = 2.2 * (1 - approach)
        return s
    }

    private func smoothstep(_ x: Double) -> Double {
        let c = x.clamped(to: 0...1)
        return c * c * (3 - 2 * c)
    }
}
