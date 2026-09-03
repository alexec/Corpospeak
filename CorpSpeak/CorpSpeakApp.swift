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
    }
}
