import SwiftUI

@main
struct CorpospeakApp: App {
    @State private var model = CorpospeakModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    // iOS stops the microphone while the app is in the background.
                    if phase == .active { model.resumeAfterInterruption() }
                }
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 380)
                #endif
        }
        #if os(macOS)
        .windowStyle(.plain)
        .defaultSize(width: 720, height: 480)
        .commands {
            // The default Help item opens an empty help book. It used to point at the repo's
            // README, which is the wrong place twice over: the repo may go private, and a
            // README is written for someone reading the source, not someone using the app.
            // This is the same support page the App Store record points at.
            CommandGroup(replacing: .help) {
                Link("Corpospeak Help", destination: URL(string: "https://www.alexecollins.com/corpospeak/support.html")!)
            }
        }
        #endif
    }
}
