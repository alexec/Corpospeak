# CorpSpeak

A macOS app that listens to you continuously, rewrites what you said as CorpSpeak using the
on-device Apple Intelligence model, and reads the result back to you.

Everything runs on the Mac: dictation (Speech framework, on-device recognition), the rewrite
(Foundation Models framework), and playback (AVSpeechSynthesizer). No network, no settings.

## Requirements

- macOS 26 with Apple Intelligence turned on (System Settings → Apple Intelligence & Siri)
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
| `CorpSpeak/Services/Speaker.swift` | Reads text aloud with `AVSpeechSynthesizer`. |
| `CorpSpeak/CorpSpeakStyle.swift` | The glossary and prompt instructions that define CorpSpeak, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `CorpSpeak/CorpSpeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `CorpSpeak/Views/ContentView.swift` | The single window. |

Listening is paused while the app is speaking so it does not transcribe its own voice.

## Voice quality

The app picks the most natural English voice installed on the Mac. Out of the box that is a
compact system voice. For a much more realistic voice, download a Premium or Enhanced one:
System Settings → Accessibility → Read & Speak → System Voice → Manage Voices, then pick an
English voice marked Premium (for example Ava, Zoe or Samantha). The app uses it automatically on
next launch.
