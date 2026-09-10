import XCTest
@testable import OptLab

final class EndpointAnalyzerTests: XCTestCase {
    private let converter = FrameConverter()

    private func analyze(_ scene: SyntheticEyeRenderer.Scene, eye: Eye = .right, trace: [Double] = []) -> EndpointAnalyzer.Result? {
        let full = CGSize(width: 1512, height: 2016)
        let cg = SyntheticEyeRenderer.render(size: full, scene: scene)
        let rgb = converter.rgbImage(from: cg, targetWidth: 512)
        return EndpointAnalyzer.analyze(image: rgb, fullResolutionSize: full, hint: nil, eye: eye, pupilTraceMm: trace)
    }

    func testScaleCalibrationIsSubMillimetre() {
        let scale = ScaleCalibration(irisDiameterPx: 1500)
        XCTAssertEqual(scale.mmPerPixel, 11.71 / 1500, accuracy: 1e-9)
        XCTAssertLessThan(scale.resolutionMm, 0.01)
        XCTAssertEqual(scale.relativeUncertainty, 0.42 / 11.71, accuracy: 1e-6)
    }

    func testPupilDiameterRecoveredFromSyntheticEye() {
        var scene = SyntheticEyeRenderer.Scene()
        scene.pupilRatio = 0.36
        guard let r = analyze(scene) else { return XCTFail("analysis failed") }

        // Pupil diameter = ratio × HVID = 0.36 × 11.71 = 4.22 mm.
        let pupil = r.endpoints.first { $0.kind == .pupilDiameter }!
        XCTAssertEqual(pupil.value, 4.22, accuracy: 0.35)
        XCTAssertNotNil(pupil.uncertainty)
        XCTAssertEqual(pupil.eye, .right)

        let ratio = r.endpoints.first { $0.kind == .pupilIrisRatio }!
        XCTAssertEqual(ratio.value, 0.36, accuracy: 0.03)

        // Geometry reported in full-resolution pixels.
        XCTAssertEqual(r.geometry.imageWidth, 1512)
        XCTAssertEqual(r.geometry.irisRadiusPx, 0.19 * 1512, accuracy: 0.19 * 1512 * 0.08)
    }

    func testRednessIndexIncreasesWithRedderSclera() {
        var calm = SyntheticEyeRenderer.Scene(); calm.redness = 0.05
        var inflamed = SyntheticEyeRenderer.Scene(); inflamed.redness = 0.9
        guard let a = analyze(calm), let b = analyze(inflamed) else { return XCTFail() }
        let ra = a.endpoints.first { $0.kind == .conjunctivalRedness }!.value
        let rb = b.endpoints.first { $0.kind == .conjunctivalRedness }!.value
        XCTAssertGreaterThan(rb, ra)
    }

    func testArcusIndexRespondsToLimbalRing() {
        var clear = SyntheticEyeRenderer.Scene(); clear.arcus = 0
        var arcus = SyntheticEyeRenderer.Scene(); arcus.arcus = 1
        guard let a = analyze(clear), let b = analyze(arcus) else { return XCTFail() }
        let ia = a.endpoints.first { $0.kind == .limbalArcusIndex }!.value
        let ib = b.endpoints.first { $0.kind == .limbalArcusIndex }!.value
        XCTAssertGreaterThan(ib, ia)
    }

    func testPupilVariabilityFromTrace() {
        let trace = [4.2, 4.25, 4.18, 4.3, 4.22, 4.27]
        guard let r = analyze(SyntheticEyeRenderer.Scene(), trace: trace) else { return XCTFail() }
        let v = r.endpoints.first { $0.kind == .pupilVariability }!
        XCTAssertEqual(v.value, trace.standardDeviation / trace.mean * 100, accuracy: 1e-6)
    }

    func testAnisocoriaIsSessionLevelDifference() {
        var session = StudySession(participant: Participant(id: "0001", studyName: "s"), visitNumber: 1, imagingProtocol: .ocularSurface, dueDate: .now, consentRecorded: true)
        let q = QualityReport(
            focus: QualityCheck(value: 1, passed: true, detail: ""),
            coverage: QualityCheck(value: 1, passed: true, detail: ""),
            motion: QualityCheck(value: 0, passed: true, detail: ""),
            exposure: QualityCheck(value: 0.5, passed: true, detail: "")
        )
        func capture(_ eye: Eye, pupil: Double) -> EyeCapture {
            EyeCapture(eye: eye, capturedAt: .now, imageFileName: "x", quality: q,
                       endpoints: [EndpointMeasurement(kind: .pupilDiameter, value: pupil, uncertainty: 0.1, confidence: 0.9, eye: eye)],
                       deviceModel: "test")
        }
        session.captures = [capture(.right, pupil: 4.6), capture(.left, pupil: 4.1)]
        let out = EndpointAnalyzer.sessionEndpoints(for: session)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].kind, .anisocoria)
        XCTAssertEqual(out[0].value, 0.5, accuracy: 1e-9)
        XCTAssertEqual(out[0].uncertainty!, (0.02).squareRoot(), accuracy: 1e-9)
    }

    func testSessionRemainingEyesAndStatus() {
        let session = StudySession(participant: Participant(id: "0001", studyName: "s"), visitNumber: 1, imagingProtocol: .ocularSurface, dueDate: .now, consentRecorded: true)
        XCTAssertEqual(session.remainingEyes, [.right, .left])
        XCTAssertEqual(session.nextEye, .right)
    }
}
