# CorpSpeak

A macOS app that listens to you continuously, rewrites what you said as CorpSpeak using the
on-device Apple Intelligence model, and reads the result back to you.

Everything runs on the Mac: dictation (Speech framework, on-device recognition), the rewrite
(Foundation Models framework), and playback in your own cloned voice with [ZipVoice](https://github.com/k2-fsa/ZipVoice)
via [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx). The only
network use is a one-time download of the voice model.

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
| `CorpSpeak/Services/Speaker.swift` | Reads text aloud one sentence at a time and reports which sentence is playing. |
| `CorpSpeak/Services/ZipVoiceSynthesizer.swift` | Clones the user's voice with ZipVoice through sherpa-onnx. |
| `CorpSpeak/Services/VoiceSample.swift` | The enrollment phrase and the saved recording of the user reading it. |
| `CorpSpeak/Services/ModelStore.swift` | Downloads and unpacks the models into Application Support on first launch. |
| `CorpSpeak/Services/AudioPlayer.swift` | Plays the synthesized PCM audio. |
| `CorpSpeak/CorpSpeakStyle.swift` | The CorpSpeak glossary and prompt, taken from [The Corpospeak Field Guide](https://claude.ai/code/artifact/0a819392-f474-464f-8815-0073bd7845e9). |
| `CorpSpeak/CorpSpeakModel.swift` | Wires the three services together: listen → translate → speak → listen. |
| `CorpSpeak/Views/ContentView.swift` | The single window. |

Listening is paused while the app is speaking so it does not transcribe its own voice.

## Voice

On first launch the app asks you to read one sentence, records it through the mic, and from then
on speaks CorpSpeak in your voice using [ZipVoice](https://github.com/k2-fsa/ZipVoice), a
zero-shot voice cloning model, through sherpa-onnx. The recording stays on the Mac. Choose
*Record my voice again…* from the voice button to redo it.

The model and its vocoder (about 160 MB) are downloaded once from the sherpa-onnx GitHub releases
into `~/Library/Containers/com.alexcollins.CorpSpeak/Data/Library/Application Support/CorpSpeak/`.
There is no other voice: the app speaks only once you have recorded yours and the model is in.

Long replies are spoken one sentence at a time, and the window scrolls to keep the current
sentence in view. Clicking the status pill (or Escape) cuts a reply off; ⌘M mutes the microphone.
