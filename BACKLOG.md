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
     filled in, and release set to manual. It is deliberately not submitted. What is left
     is the two things that need the app visibly working on an Apple-Intelligence-eligible
     device: **iPhone 6.5" and iPad screenshots**, and the **Guideline 2.1 screen
     recording**. Both are blocked on the iOS 27 guardrail refusing rewrites (item 5), and
     there is no eligible iPad in the house, so the iPad set needs a simulator or borrowed
     hardware.
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

5. **The iOS 27 model refuses rewrites.** The phone reports the model available and the
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
