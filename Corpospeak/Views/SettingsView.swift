import SwiftUI

/// The house shape, in every one of Alex's apps: "How it works" at the top, the app's own
/// settings in the middle, and a Developer section at the bottom that only exists in Debug.
///
/// Corpospeak has one real setting, the voice it speaks with, so the gear that opens this
/// screen ships rather than being Debug-only.
struct SettingsView: View {
    let model: CorpospeakModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingHowItWorks = false
    @State private var isShowingNotices = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("How it works") { isShowingHowItWorks = true }
                }

                Section("Voice") {
                    Picker("Speaks with", selection: voiceSelection) {
                        ForEach(voiceOptions) { option in
                            Text(option.name).tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Button("Acknowledgements") { isShowingNotices = true }
                } footer: {
                    Text("The open-source work Corpospeak speaks with, and the licences it is offered under.")
                }

                #if DEBUG
                Section("Developer") {
                    Button("Show first run again") {
                        model.forgetFirstRun()
                        dismiss()
                    }
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $isShowingHowItWorks) {
            HowItWorks()
        }
        .sheet(isPresented: $isShowingNotices) {
            Acknowledgements()
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }

    /// Best first, the same order the voice menu uses: the user's own voice, then Kokoro,
    /// then Apple's.
    private var voiceOptions: [Speaker.VoiceOption] {
        model.speaker.personalVoiceOptions
            + model.speaker.kokoroVoiceOptions
            + model.speaker.systemVoiceOptions
    }

    private var voiceSelection: Binding<String> {
        Binding(
            get: { model.speaker.selectedVoiceID ?? "" },
            set: { model.selectVoice(id: $0) }
        )
    }
}

/// The first-run words again, for someone who wants to re-read what the app is.
///
/// It shows `FirstRunContent` and nothing else: no "Start listening" button, so no permission
/// request. Somebody tapping this on an install that already granted the microphone must not
/// meet a system alert, and somebody tapping it on an install that refused must not be asked
/// again from here.
private struct HowItWorks: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                FirstRunContent(compact: true)
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 320)
        #endif
    }
}

/// The licences for the open-source work inside the app — Kokoro's weights, FluidAudio, and
/// what FluidAudio itself carries. Most of those licences ask anyone shipping the code in
/// binary form to reproduce them, and until now nothing in the app did.
///
/// The text is read out of the bundle rather than written into Swift, so `THIRD-PARTY-NOTICES.md`
/// is the single copy and cannot drift from the one in the repository. Reading it is also why
/// this screen needs no network: the app makes no connections at all, and a licence link to the
/// web would have been the first.
private struct Acknowledgements: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                // Monospaced because most of what follows is verbatim licence text, hard-wrapped
                // by whoever wrote it; 11pt is what keeps those lines from wrapping twice on a
                // phone. The prose above them is left unwrapped in the file so it reflows.
                Text(notices)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Acknowledgements")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    /// If this ever reads the fallback, the file was dropped from the bundle — which is a
    /// licence problem, not a cosmetic one, so it says so rather than showing an empty page.
    private var notices: String {
        guard let url = Bundle.main.url(forResource: "THIRD-PARTY-NOTICES", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return """
                The notices file is missing from this build.

                Corpospeak ships Kokoro 82M and FluidAudio, both Apache-2.0, and FluidAudio \
                carries fastcluster (BSD), VBx and NemoTextProcessing. The full text is in \
                THIRD-PARTY-NOTICES.md in the source repository.
                """
        }
        return text
    }
}
