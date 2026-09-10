import XCTest

/// End-to-end smoke test: walks the full protocol on the simulator using the synthetic
/// frame source, asserting that guidance converges, auto-capture fires, and both eyes pass
/// the quality gate. Screenshots are saved to `$SCREENSHOT_DIR` (default /tmp/optlab-shots).
final class CaptureFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shotDir: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/optlab-shots"
        shotDir = URL(fileURLWithPath: dir, isDirectory: true)
        try? FileManager.default.createDirectory(at: shotDir, withIntermediateDirectories: true)

        app = XCUIApplication()
        app.launchArguments = ["--reset-demo", "--ui-testing", "-voiceGuidanceEnabled", "NO", "-autoCaptureEnabled", "YES"]
        app.launch()
    }

    func testFullBothEyesProtocol() throws {
        // Home
        XCTAssertTrue(app.staticTexts["Ready for your\nnext capture."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Participant 0042"].exists)
        snap("01-home")

        app.buttons["Open session"].tap()

        // Session
        let begin = app.buttons["Begin guided capture"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Right eye"].exists)
        snap("02-session")
        begin.tap()

        // Guided capture — the scripted eye starts small and off-centre.
        XCTAssertTrue(app.staticTexts["Eye detected"].waitForExistence(timeout: 30), "eye should be detected by the macro localiser")
        sleep(1)
        snap("03-capture-guidance")

        // Auto-capture must fire once the eye is held in the guide, then the still is analysed.
        let checking = app.staticTexts["Checking your capture."]
        XCTAssertTrue(checking.waitForExistence(timeout: 60), "auto-capture should fire")
        snap("04-quality-check")

        let continueLeft = app.buttons["Continue to left eye"]
        XCTAssertTrue(continueLeft.waitForExistence(timeout: 60), "right eye should pass the quality gate")
        snap("05-quality-passed")
        continueLeft.tap()

        // Left eye: same pipeline, second capture of the session.
        XCTAssertTrue(checking.waitForExistence(timeout: 90), "left eye auto-capture should fire")
        let viewResults = app.buttons["View results"]
        XCTAssertTrue(viewResults.waitForExistence(timeout: 60), "left eye should pass the quality gate")
        viewResults.tap()

        // Complete
        XCTAssertTrue(app.staticTexts["Capture complete."].waitForExistence(timeout: 10))
        snap("06-complete")

        app.buttons["Trial endpoints"].tap()
        XCTAssertTrue(app.staticTexts["Trial endpoints"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Pupil diameter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Anisocoria (OD − OS)"].exists)
        snap("07-endpoints")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["Review images"].waitForExistence(timeout: 10))
        app.buttons["Review images"].tap()
        XCTAssertTrue(app.staticTexts["Review images"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["1 mm"].waitForExistence(timeout: 10), "scale bar should render once geometry exists")
        snap("08-review")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["Return to sessions"].waitForExistence(timeout: 10))
        app.buttons["Return to sessions"].tap()
        XCTAssertTrue(app.staticTexts["Participant 0017"].waitForExistence(timeout: 10), "next participant should surface after completion")
        snap("09-home-after")
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: shotDir.appendingPathComponent("\(name).png"))
    }
}
