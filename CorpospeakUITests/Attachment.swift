import XCTest

/// Getting a frame off the phone and onto the Mac.
///
/// The test runs on the device, so it cannot write to the Mac's disk. Screenshots travel back
/// in the `.xcresult` bundle as attachments, and `scripts/device_frames.sh` exports them with
/// `xcrun xcresulttool export attachments`. The name given here becomes the file name, so it
/// is the only thing tying a frame to the slot it fills in CAPTURE.md.
enum Attachment {

    static func save(_ screenshot: XCUIScreenshot, named name: String) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        // Without this an attachment is thrown away when the test passes, which is exactly the
        // run whose frames we want.
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "frame \(name)") { $0.add(attachment) }
    }

    /// Records the pixel size of what the device actually produced, so a run says whether it
    /// matches what App Store Connect accepts rather than anyone assuming it does.
    static func recordSize(of screenshot: XCUIScreenshot) -> CGSize {
        let size = screenshot.image.size
        let scale = screenshot.image.scale
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        XCTContext.runActivity(named: "frame is \(Int(pixels.width)) x \(Int(pixels.height)) pixels") { _ in }
        return pixels
    }
}
