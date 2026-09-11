# Backlog

1. **Test on iPhone, iPad, and macOS.** Debug builds for macOS and the iOS Simulator both
   succeed on this branch. Run the app on each platform and check the full loop: listen →
   translate → speak, the voice menu (Personal Voice and system voices), mute, and stop.
   Note: the paired iPad (A16) is not Apple Intelligence eligible
   (`scripts/check_apple_intelligence_eligible.py`), so iPad testing needs an M1/A17 Pro or
   later iPad; the paired iPhone 15 Pro Max is eligible.
2. **User testing.** Put a TestFlight build in front of a few people and collect feedback on
   the translations, the voice, and first-launch permission prompts.
3. **Get the current code onto the App Store.** macOS 1.0 went live on 2026-09-10
   (approved 02:41, released automatically) but the build attached to that version is
   **1.0 (1)**, uploaded Sep 4. Builds 2 and 3 were uploaded and never attached, so the
   Personal Voice default, the translation speed-up and Kokoro are all absent from the
   shipped app.
   - **iOS is now on the record and waiting on screenshots.** The iOS platform was added
     on 2026-09-10 and **1.0 (4)** is uploaded and attached to iOS 1.0, with the
     description, keywords, support URL, copyright, contact details and App Review notes
     filled in, and release set to manual. It is deliberately not submitted; the version
     page still reads *Add for Review*, so this is a first submission and not a
     resubmission. What is left is the three things that need the app visibly working on
     an Apple-Intelligence-eligible device, checked in App Store Connect on 2026-09-10:
     **iPhone 6.5" screenshots (0 of 10)**, **iPad 13" screenshots (0 of 10)**, and the
     **Guideline 2.1 screen recording**, which is not attached (App Review Information →
     Attachment is empty). The iOS 27 guardrail that used to block these is fixed
     (item 5). All three now need only the iPhone 15 Pro Max, which is the one eligible
     device in the house. A simulator cannot stand in: the app has no way to inject text,
     so a screenshot needs someone speaking into a microphone. There is no eligible iPad,
     so the iPad set has to come from the same iPhone session or borrowed hardware.
   - **The iPad set is 1 of 4, and a simulator cannot finish it.** Measured 2026-09-10 on an
     iPad Pro 13-inch (M5) simulator, iOS 26.5, Release build.
     `Corpospeak/AppStore/screenshots/en-US/2-listening.png` is captured: 2752 × 2064,
     landscape, the empty state. The other three cannot come from any simulator, and the
     reason is **not** that nobody spoke into the microphone:
     - **On-device speech recognition does not work in the Simulator.** The microphone path
       is fine — the Mac's speakers playing `say` drive the app's level meter well above
       ambient — but `localspeechrecognition` fails to build a recognizer on every restart
       (`_EARSpeechRecognizer is nil`, `Failed to create recognizer from … mini.json`). The
       en_US ASR model ships as `UC_SIRI_ASR_ASSISTANT_…_Cryptex.dmg`, and the simulator
       never mounts cryptexes, so `mini.json` is unreachable. `SpeechListener` sets
       `requiresOnDeviceRecognition = true` (Services/SpeechListener.swift:235) and will not
       fall back, by design. So no transcript is possible there, whoever is talking — frames
       1 and 4 need a transcript, and frame 2's `Listening… pause to send` pill needs one too
       (`silenceDeadline` is only set when a recognition result arrives).
     - **Personal Voice does not exist on a simulator**, so frame 3's **Your Voice** section
       never renders (`offersPersonalVoice` is false for `.unsupported`), and Kokoro is gated
       off on the 26.4+ iOS line. The voice menu there shows **System Voices** alone, which is
       the opposite of what that frame is meant to show.
     - **The rewrite itself works.** `SystemLanguageModel.default.availability` reports
       `available` inside that simulator, verified with a probe binary run through
       `simctl spawn`. Foundation Models is not the blocker; ASR is.
     So the iPad set needs either a real Apple-Intelligence-eligible 13-inch iPad, or a way to
     drive the loop without the microphone — the Brushwise pattern of launch arguments that
     seed content and add no UI would let a simulator produce frames 1, 2 and 4. Frame 3 would
     still need real hardware with a Personal Voice on it. Not done here: this was a capture
     task and changing the app was out of scope.
   - **Build 5 has never been uploaded.** `project.yml` says 1.0 (5) and the branch
     `claude/ship-build-5` carries the bump plus *Explain the app before asking for the
     microphone*. App Store Connect has builds 3 and 4 only. Decide before submitting
     whether iOS 1.0 goes out as build 4, which is attached now and does not have the
     permission explanation, or as build 5, which needs an archive and upload first.
   - **A new macOS version is still outstanding.** Create 1.0.1 (or 1.1), archive and
     upload build 4 or later for macOS, attach it, submit. The review notes in
     `RELEASING.md` §4 cleared review once, but they now say the app has no third-party
     SDKs and uses only Apple frameworks, which stopped being true when Kokoro landed. The
     iOS notes in App Store Connect have the corrected wording to copy from.
4. **Kokoro as the default voice when there's no Personal Voice.** Design, licence diligence and
   the bundling decision are in [docs/voice-engine.md](docs/voice-engine.md). Blocked on the
   Actionable streaming-diarization task choosing a Kokoro port, so both apps standardise on one
   dependency. Once it lands: add the package, write the text→PCM adapter, vendor the model
   subset into the bundle with network access off, change the default-voice ladder to
   Personal Voice → Kokoro → Apple, and synthesize sentence N+1 while N plays.
   - **Check the port doesn't link espeak-ng before adopting it** — it's GPL-3.0 and this app
     ships on the App Store. `mattmireles/kokoro-coreml` doesn't document its tokenizer; the
     other three use Misaki or a Core ML G2P.
   - Measure RTF on the iPhone 15 Pro Max (which is the oldest device the app supports, since
     Apple Intelligence sets the floor) *while a rewrite is streaming* — Kokoro and Foundation
     Models contend for the Neural Engine, so the 0.08 figure measured alone isn't the one that
     matters.
   - Budget well above the 80MB the ONNX figure suggests: FluidAudio's Core ML build is ~300MB
     all in, ~23MB of which is G2P lexicons.

5. **~~The iOS 27 model refuses rewrites.~~ Fixed 2026-09-09** by naming the task as parody
   of the speaker's own words in the opening line (phone refusals 2/12 → 0/11). Kept below
   for the reasoning, which still applies to any future prompt change.

   **The iOS 27 model refuses rewrites.** The phone reports the model available and the
   OS example split working ("work (OS 27+)"), so it is the guardrail rejecting the
   content, not a wrong example set. Simplifying the prompt is measurably the wrong fix:
   cutting the phrasebook from 95 terms to 20 took facts kept from 84% to 64% on the Mac
   model while refusals did not move (n=24 each). The untested hypothesis is that the
   *instructions* are the trigger, not the examples: "evasive", "the ask gets buried" and
   "it should take the listener a moment to work out what was actually asked" describe
   deliberate obfuscation. Five variants changing exactly one such phrase each are staged
   in `.claude/skills/prompt-eval/scripts/probe/Probe/Variants.swift`; run the phone probe
   with the iPhone unlocked and awake. This blocks the iOS screenshots and the App Review
   screen recording in item 3, so it is the next thing to do.

## Won't build

- **Downloading voices from HuggingFace on demand.** Keeps the app small, but PRIVACY.md and the
  README both promise no network connections at all, and that promise is in the App Store review
  notes. Bundle the model instead. If size ever forces the issue, Apple's On-Demand Resources is
  the fallback, not a third-party fetch.

## Minor review findings

- [x] ASR-metadata · 2026-09-10 · App Store Connect → App Information · subtitle read
  "Say it. Hear it in CorpSpeak", spelling the app the old way. Now "Say it. Hear it in
  Corpospeak" (29 of 30 characters). Goes out with the next version.
- [x] ASR-privacy · 2026-09-10 · App Store Connect → App Privacy · the privacy policy URL
  was pinned to commit 22c7dc3 under the old repo name (`alexec/CorpSpeak`), serving a
  Mac-only policy dated 4 September that said speech "may send audio to Apple for
  recognition". Now `https://github.com/alexec/Corpospeak/blob/main/PRIVACY.md`, so it
  tracks the policy instead of freezing a copy of it.
- [x] ASR-rights · 2026-09-10 · App Store Connect → App Information · Content Rights said
  the app contains no third-party content, while it bundles the Apache-2.0 Kokoro model.
  Now "Yes, this app has the necessary rights to its third-party content", which Apache 2.0
  grants and the App Review notes already disclose.
- [ ] ASR-attribution · 2026-09-10 · repo root · nothing in the app or the repo carries the
  Apache-2.0 licence text for Kokoro or FluidAudio. Apache 2.0 §4 asks for it with any
  distribution. There is no Settings screen to put an acknowledgements row in yet.
