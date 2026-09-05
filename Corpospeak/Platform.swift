import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// The few places where the Mac, iPhone, and iPad builds differ.
@MainActor
enum Platform {
    #if os(macOS)
    /// The name of the settings app: "System Settings" on the Mac, "Settings" elsewhere.
    static let settings = "System Settings"
    /// What the user calls the machine: "Mac", "iPhone", or "iPad".
    static let device = "Mac"
    /// The operating system's name.
    static let os = "macOS"
    #else
    static let settings = "Settings"
    static var device: String { UIDevice.current.model }
    static var os: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS" }
    #endif

    /// Where the Personal Voice is created and managed.
    static var voiceSettingsPath: String { "\(settings) → Accessibility → Personal Voice" }

    /// Opens the settings app as close to the Personal Voice pane as the platform allows.
    /// The Mac goes straight to it; iOS can only open the app's own settings page.
    static func openVoiceSettings() {
        #if os(macOS)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?PersonalVoice")!)
        #else
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        #endif
    }

    /// Puts text on the clipboard.
    static func copy(_ text: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}
