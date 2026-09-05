# CorpSpeak

A macOS app that listens to you continuously, rewrites what you said as CorpSpeak using the
on-device Apple Intelligence model, and reads the result back to you in your own voice.

Everything runs on the Mac: dictation (Speech framework, on-device recognition), the rewrite
(Foundation Models framework), and playback with your Personal Voice (AVSpeechSynthesizer).
The app never touches the network.

## Requirements

- macOS 26 with Apple Intelligence turned on (System Settings → Apple Intelligence & Siri)
- A Personal Voice (System Settings → Accessibility → Personal Voice)
- Xcode 26
- [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the project file

## Build and run

```bash
xcodegen generate
open CorpSpeak.xcodeproj
```

Then press Run. The first launch asks for Microphone and Speech Recognition permission.

Or from the terminal:

```bash
xcodebuild -project CorpSpeak.xcodeproj -scheme CorpSpeak -configuration Debug build
```

## How it fits together

| File | Role |
| --- | --- |
| `CorpSpeak/Services/SpeechListener.swift` | Always-on microphone → `SFSpeechRecognizer`. Emits one utterance per pause in speech. |
| `CorpSpeak/Services/Translator.swift` | Sends an utterance to the on-device `LanguageModelSession` and returns the rewrite. |
| `CorpSpeak/Services/Speaker.swift` | Reads text aloud with the user's Personal Voice one sentence at a time and reports which sentence is playing. |
| `CorpSpeak/CorpSpeakStyle.swift` | The CorpSpeak glossary and prompt, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `CorpSpeak/CorpSpeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `CorpSpeak/Views/ContentView.swift` | The single window. |

Listening is paused while the app is speaking so it does not transcribe its own voice.

CorpSpeak makes no network connections and keeps nothing. See [PRIVACY.md](PRIVACY.md).

## Voice

CorpSpeak speaks only in your own voice, using the Personal Voice that macOS creates. Create
one in System Settings → Accessibility → Personal Voice (ten phrases, about a minute), turn on
*Allow Apps to Request to Use*, then choose *Use my Personal Voice…* in the app and allow it.
The app notices as soon as a voice appears, and nothing is spoken until then. You can withdraw
access, or record a new voice, in the same System Settings pane.

Long replies are spoken one sentence at a time, and the window scrolls to keep the current
sentence in view. Clicking the status pill (or Escape) cuts a reply off; ⌘M mutes the microphone.
