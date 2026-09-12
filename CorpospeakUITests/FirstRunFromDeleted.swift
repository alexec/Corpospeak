import XCTest

/// The Guideline 2.1 run: what a reviewer sees when they open the app for the first time.
///
/// This test only means anything if the app was deleted before it ran, because that is the only
/// state in which iOS asks for the microphone and for speech recognition. `scripts/device_run.sh`
/// does the delete; running this test on its own against an already-permitted app proves
/// nothing and says so in the failure.
final class FirstRunFromDeleted: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEveryPermissionPromptAsANewUserMeetsThem() throws {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Start listening"]
        XCTAssertTrue(start.waitForExistence(timeout: 30), "first-run view never appeared")

        // The first-run view is the app explaining itself before iOS asks anything, so it is
        // worth a frame of its own: it is the first thing the reviewer reads.
        Attachment.save(XCUIScreen.main.screenshot(), named: "10-first-run")

        start.tap()

        // Everything below this line is the part that had never been tested on real hardware.
        let answered = SystemAlerts.dismissAll(timeout: 30)
        XCTAssertFalse(
            answered.isEmpty,
            """
            No system alert appeared. Either the app was not deleted before this ran, so iOS had \
            the answers already, or the alerts are no longer reachable from the test process.
            """
        )
        XCTContext.runActivity(named: "answered \(answered.count) alerts: \(answered.joined(separator: ", "))") { _ in }

        XCTAssertTrue(
            start.waitForNonExistence(timeout: 30),
            "still on the first-run view after answering \(answered)"
        )

        // Listening starts the moment first run finishes, so this frame is the app doing its job
        // with permissions that were granted seconds ago.
        Attachment.save(XCUIScreen.main.screenshot(), named: "11-listening")

        // A reviewer asking a Guideline 2.1 question wants to see the feature work, not just the
        // prompts, so the recording carries on until the app has heard something and read the
        // rewrite back. The Mac is talking throughout — see `scripts/device_capture.sh`.
        let heard = app.staticTexts["YOU SAID"].waitForExistence(timeout: 120)
        XCTAssertTrue(heard, "the app never transcribed anything, so the recording shows prompts and nothing else")
        Attachment.save(XCUIScreen.main.screenshot(), named: "12-working")

        // Hold a few seconds so the reply is still being read when the recording stops; a video
        // that cuts the moment the text lands looks like it failed.
        Thread.sleep(forTimeInterval: 8)
        Attachment.save(XCUIScreen.main.screenshot(), named: "13-speaking")
    }
}
