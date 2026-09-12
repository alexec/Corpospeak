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
