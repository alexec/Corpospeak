import SwiftUI

@main
struct CorpSpeakApp: App {
    @State private var model = CorpSpeakModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 520, minHeight: 380)
                .task { await model.start() }
        }
        .windowStyle(.plain)
        .defaultSize(width: 720, height: 480)
        .commands {
            // The default Help item opens an empty help book; point it at the README instead.
            CommandGroup(replacing: .help) {
                Link("Corpospeak Help", destination: URL(string: "https://github.com/alexec/Corpospeak#readme")!)
            }
        }
    }
}
