import XCTest
@testable import OptLab

final class AlignmentEngineTests: XCTestCase {
    private let guide = GuideGeometry(center: CGPoint(x: 0.5, y: 0.5), targetIrisRadius: 0.19)
    private var thresholds = QualityThresholds.standard

    private func observation(center: CGPoint = CGPoint(x: 0.5, y: 0.5), radius: Double = 0.19) -> EyeObservation {
        EyeObservation(
            irisCenter: center, irisRadius: radius, pupilCenter: center, pupilRadius: radius * 0.36,
            pupilCircularity: 0.95, confidence: 0.9, source: .synthetic
        )
    }

    private func frame(_ t: Double, obs: EyeObservation?, sharpness: Double = 0.8, luma: Double = 0.5, rotation: Double = 0) -> FrameAssessment {
        FrameAssessment(
            timestamp: t, observation: obs,
            quality: FrameQualityMetrics(sharpness: sharpness, meanLuma: luma, clipping: 0),
            rotationRate: rotation, lensPosition: 0.8
        )
    }

    func testSearchingWhenNoEye() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: nil))
        XCTAssertEqual(g.instruction, .searching)
        XCTAssertFalse(g.eyeDetected)
        XCTAssertFalse(g.shouldCapture)
    }

    func testAsksToMoveCloserWhenIrisSmall() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: observation(radius: 0.12)))
        XCTAssertEqual(g.instruction, .moveCloser(slightly: false))
        let g2 = engine.ingest(frame(0.1, obs: observation(radius: 0.16)))
        XCTAssertEqual(g2.instruction, .moveCloser(slightly: true))
        XCTAssertEqual(g2.arrowLabelForTest, "Move closer")
    }

    func testAsksToMoveBackWhenIrisLarge() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: observation(radius: 0.27)))
        XCTAssertEqual(g.instruction, .moveBack(slightly: false))
    }

    func testDirectionalGuidanceWhenOffCentre() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: observation(center: CGPoint(x: 0.38, y: 0.5))))
        XCTAssertEqual(g.instruction.headline, "Move left.")
        let g2 = engine.ingest(frame(0.1, obs: observation(center: CGPoint(x: 0.5, y: 0.62))))
        XCTAssertEqual(g2.instruction.headline, "Move down.")
    }

    func testLightingBlocksBeforeFocus() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: observation(), sharpness: 0.1, luma: 0.1))
        XCTAssertEqual(g.instruction, .moreLight)
        XCTAssertFalse(g.lightingReady)
    }

    func testAutoCaptureFiresAfterStableFrames() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        var fired = 0
        var lastProgress = 0.0
        for i in 0..<(thresholds.requiredStableFrames + 3) {
            let g = engine.ingest(frame(Double(i) / 30, obs: observation()))
            if g.shouldCapture { fired += 1 }
            XCTAssertGreaterThanOrEqual(g.alignmentProgress, lastProgress)
            lastProgress = g.alignmentProgress
        }
        XCTAssertEqual(fired, 1, "capture must fire exactly once")
        XCTAssertEqual(engine.ingest(frame(10, obs: observation())).instruction, .captured)
        XCTAssertGreaterThanOrEqual(engine.pupilTrace.count, thresholds.requiredStableFrames)
    }

    func testMotionResetsProgress() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        for i in 0..<6 { _ = engine.ingest(frame(Double(i) / 30, obs: observation())) }
        XCTAssertEqual(engine.stableFrames, 6)
        // Jump the iris by 3 % of the frame in one frame → hold-still.
        let g = engine.ingest(frame(0.2, obs: observation(center: CGPoint(x: 0.53, y: 0.5))))
        XCTAssertEqual(g.instruction, .holdStill)
        XCTAssertLessThan(engine.stableFrames, 6)
    }

    func testDeviceRotationBlocksCapture() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide)
        let g = engine.ingest(frame(0, obs: observation(), rotation: 1.0))
        XCTAssertEqual(g.instruction, .holdStill)
        XCTAssertFalse(g.motionReady)
    }

    func testManualModeNeverAutoCaptures() {
        let engine = AlignmentEngine(thresholds: thresholds, guide: guide, autoCaptureEnabled: false)
        for i in 0..<40 {
            XCTAssertFalse(engine.ingest(frame(Double(i) / 30, obs: observation())).shouldCapture)
        }
        XCTAssertEqual(engine.ingest(frame(2, obs: observation())).instruction, .aligned)
    }

    func testGuideAdaptsToMinimumFocusDistance() {
        // Macro-capable ultra-wide: can afford the full preferred radius.
        let macro = CameraProfile(name: "UW", horizontalFieldOfView: 104, zoomFactor: 2, minimumFocusDistanceMm: 20, photoWidthPx: 4032, isMacroCapable: true)
        XCTAssertEqual(GuideGeometry.adapted(to: macro).targetIrisRadius, 0.19, accuracy: 0.001)

        // Wide lens with 12 cm minimum focus: guide shrinks so the operator never has to go inside focus range.
        let wide = CameraProfile(name: "W", horizontalFieldOfView: 70, zoomFactor: 2, minimumFocusDistanceMm: 120, photoWidthPx: 4032, isMacroCapable: false)
        let adapted = GuideGeometry.adapted(to: wide)
        XCTAssertLessThan(adapted.targetIrisRadius, 0.1)
        let distance = wide.workingDistanceMm(forIrisFraction: adapted.targetIrisRadius * 2)
        XCTAssertGreaterThanOrEqual(distance, 120 * 1.15 - 0.5)
        // Still sub-millimetre sampling.
        XCTAssertLessThan(wide.mmPerPixel(forIrisFraction: adapted.targetIrisRadius * 2), 0.05)
    }
}

private extension Guidance {
    var arrowLabelForTest: String? { instruction.arrowLabel }
}
