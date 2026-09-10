import XCTest
@testable import OptLab

final class PupilLocalizerTests: XCTestCase {
    private let converter = FrameConverter()

    private func gray(for scene: SyntheticEyeRenderer.Scene, size: CGSize = CGSize(width: 480, height: 640), analysisWidth: Int = 320) -> (GrayImage, RGBImage) {
        let cg = SyntheticEyeRenderer.render(size: size, scene: scene)
        let rgb = converter.rgbImage(from: cg, targetWidth: analysisWidth)
        return (rgb.gray(), rgb)
    }

    func testLocatesCentredEyeWithinTolerance() {
        var scene = SyntheticEyeRenderer.Scene()
        scene.irisCenter = CGPoint(x: 0.5, y: 0.5)
        scene.irisRadius = 0.19
        scene.pupilRatio = 0.36
        let (g, _) = gray(for: scene)

        guard let fit = PupilLocalizer.localize(in: g) else { return XCTFail("no fit") }
        let w = Double(g.width), h = Double(g.height)

        XCTAssertEqual(fit.pupilCenter.x / w, 0.5, accuracy: 0.01)
        XCTAssertEqual(fit.pupilCenter.y / h, 0.5, accuracy: 0.01)
        // Pupil radius: 0.19 × 0.36 = 0.0684 of width.
        XCTAssertEqual(fit.pupilRadius / w, 0.0684, accuracy: 0.006)
        // Iris (limbus) radius.
        XCTAssertEqual(fit.irisRadius / w, 0.19, accuracy: 0.015)
        XCTAssertGreaterThan(fit.pupilCircularity, 0.85)
        XCTAssertGreaterThan(fit.confidence, 0.5)
    }

    func testLocatesOffCentreSmallEye() {
        var scene = SyntheticEyeRenderer.Scene()
        scene.irisCenter = CGPoint(x: 0.36, y: 0.40)
        scene.irisRadius = 0.105
        let (g, _) = gray(for: scene)

        guard let fit = PupilLocalizer.localize(in: g) else { return XCTFail("no fit") }
        let w = Double(g.width), h = Double(g.height)
        XCTAssertEqual(fit.irisCenter.x / w, 0.36, accuracy: 0.015)
        XCTAssertEqual(fit.irisCenter.y / h, 0.40, accuracy: 0.015)
        XCTAssertEqual(fit.irisRadius / w, 0.105, accuracy: 0.012)
    }

    func testRejectsFrameWithoutEye() {
        // Uniform mid-grey frame: no dark compact blob → nil.
        let g = GrayImage(width: 320, height: 427, fill: 140)
        XCTAssertNil(PupilLocalizer.localize(in: g))
    }

    func testPupilRatioTracksDilation() {
        var small = SyntheticEyeRenderer.Scene(); small.pupilRatio = 0.30
        var large = SyntheticEyeRenderer.Scene(); large.pupilRatio = 0.50
        let (gs, _) = gray(for: small)
        let (gl, _) = gray(for: large)
        guard let fs = PupilLocalizer.localize(in: gs), let fl = PupilLocalizer.localize(in: gl) else { return XCTFail() }
        XCTAssertEqual(fs.pupilRadius / fs.irisRadius, 0.30, accuracy: 0.04)
        XCTAssertEqual(fl.pupilRadius / fl.irisRadius, 0.50, accuracy: 0.04)
    }

    func testSharpnessDropsWithBlur() {
        var sharp = SyntheticEyeRenderer.Scene()
        sharp.blur = 0
        var soft = SyntheticEyeRenderer.Scene()
        soft.blur = 3
        let (gsharp, _) = gray(for: sharp, analysisWidth: 192)
        let (gsoft, _) = gray(for: soft, analysisWidth: 192)
        let s1 = FrameQualityAnalyzer.sharpness(of: gsharp)
        let s2 = FrameQualityAnalyzer.sharpness(of: gsoft)
        XCTAssertGreaterThan(s1, s2)
        XCTAssertGreaterThan(s1, QualityThresholds.standard.minSharpness)
    }
}
