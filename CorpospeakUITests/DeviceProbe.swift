import XCTest

/// The smallest question first: can a test running on Alex's own iPhone launch this app and
/// tap one thing, without his hands?
///
/// Everything else T165 wants — the App Store frames, the Guideline 2.1 recording — is built
/// on top of that one answer, so it gets its own test and fails loudly on its own.
final class DeviceProbe: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLaunchAndTapOneThing() throws {
        let app = XCUIApplication()
        app.launch()

        // The first-run view is a view, not a sheet, so it is part of the app's own tree.
        let start = app.buttons["Start listening"]
        XCTAssertTrue(start.waitForExistence(timeout: 20), "first-run view never appeared")
        start.tap()

        // Tapping it asks for the microphone and for speech recognition, which are springboard
        // alerts and belong to another process.
        let allowed = SystemAlerts.dismissAll(timeout: 20)
        XCTContext.runActivity(named: "system alerts answered: \(allowed)") { _ in }

        // The app is past first run if the first-run view is gone.
        XCTAssertTrue(
            start.waitForNonExistence(timeout: 20),
            "still on the first-run view — the tap or the alerts did not go through"
        )

        let shot = XCUIScreen.main.screenshot()
        Attachment.save(shot, named: "01-after-first-run")
    }
}
