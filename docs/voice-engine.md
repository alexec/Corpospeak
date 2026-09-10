# The voice engine: Kokoro alongside Personal Voice

_Design record, 9 September 2026. Updated once the port was settled and the numbers measured._

Corpospeak speaks with either the user's Personal Voice or one of Apple's built-in
`AVSpeechSynthesis` voices. The built-in ones sound bad, Enhanced and Premium downloads
included, and should stop being the default. The plan is three tiers:

1. **Personal Voice** — unchanged, still the best thing the app can do, still the default when
   the user has recorded one and allowed Corpospeak to use it.
2. **Kokoro** — the new default when there is no Personal Voice.
3. **Apple built-in** — fallback only, for hardware or a state where Kokoro can't run.

## The licence trap: espeak-ng

Kokoro's weights are Apache 2.0 (v0.19, released in full fp32 on 25 December 2024), and every
Swift wrapper below is Apache 2.0 or MIT. That is not the whole question. Kokoro's *reference*
pipeline phonemizes with **espeak-ng, which is GPL-3.0**, and a GPL dependency linked into a
closed-source App Store binary is the problem VLC is famous for. The brief's instruction to check
the model weights and not just the wrapper repo lands exactly here — except the exposure isn't in
the weights, it's in the grapheme-to-phoneme step in front of them.

The upstream issue asking this question ([hexgrad/kokoro#247]) is **open with no maintainer
answer**, so the ecosystem has not resolved it on our behalf. It has to be checked per port.

Three of the four candidates avoid espeak-ng by using Misaki or a Core ML G2P model. One doesn't
say. **Any port that links espeak-ng is unusable for Corpospeak** and that check should gate
adoption regardless of which port the Actionable evaluation prefers.

## The four candidates

| Port | Wrapper licence | Backend | Grapheme→phoneme | Weights & voices |
| --- | --- | --- | --- | --- |
| [FluidInference/FluidAudio] | Apache 2.0 | Core ML, ANE-resident (`KokoroAne`) | Core ML G2P (BART) + bundled lexicons — **no espeak** | Auto-downloads to `~/.cache/fluidaudio/Models/kokoro/`; `ModelHub.offlineMode` and load-from-bundled-directory APIs exist |
| [mweinbach/kokoro-swift] | Apache 2.0 | MLX *and* Core ML (segmented for ANE) | Bundled Misaki — **no espeak, no Python** | 54 voices fetched on demand from HuggingFace |
| [mlalma/kokoro-ios] | MIT | MLX Swift (GPU/Metal) | MisakiSwift by default; an espeak-ng path exists but is commented out | Ships neither weights nor voices — bring your own |
| [mattmireles/kokoro-coreml] | Apache 2.0 | Core ML | **Not documented** — read the tokenizer before adopting | Pre-converted `.mlpackage` downloaded from HuggingFace |

`FluidInference/kokoro-82m-coreml` on HuggingFace is also Apache 2.0.

Two things separate these for Corpospeak specifically:

- **Core ML/ANE beats MLX here.** Corpospeak is already running the Foundation Models rewrite on
  the Neural Engine. A Core ML port that is ANE-resident shares that path; an MLX port runs on the
  GPU via Metal, which is a second engine to keep warm and a second memory budget. That counts
  against `mlalma/kokoro-ios` and the MLX half of `mweinbach/kokoro-swift`.
- **Being able to bundle beats being able to download.** See below.

## Two corrections to the brief's assumptions

**Size — the brief was right and the "~300MB" figure going round is not.** Measured against the
HuggingFace file listing rather than a blog post: `FluidInference/kokoro-82m-coreml` is **4.7GB**
in total, because it carries every variant — Mandarin (557MB), Japanese (94MB), duration-bucketed
StyleTTS2 builds at ~325MB each, and a `.mlpackage` twin of every `.mlmodelc`. None of that is
what you ship. The English Neural Engine subset actually needed is:

| Part | Size |
| --- | --- |
| The 7-stage ANE chain (`KokoroVocoder` 49MB, `KokoroPostAlbert` 14MB, `KokoroProsody` 8.5MB, `KokoroAlbert` 5.8MB, `KokoroNoise_v2` 4.7MB, `KokoroTail`, `KokoroAlignment`) | 82MB |
| `af_heart` voice pack | 0.5MB |
| Shared G2P (`G2PEncoder`, `G2PDecoder`, vocab) | 1.6MB |
| `us_lexicon_cache.json` (Misaki weak forms — pronunciation quality) | 10.4MB |
| **Total in the app bundle** | **95MB** |

So the brief's "roughly 80MB" was the right order of magnitude and my earlier correction of it was
wrong. 95MB is comfortably under the 200MB cellular-download threshold, which makes bundling an
easy call rather than a grudging one.

**Where the performance risk actually is.** The reported 0.08 real-time factor is Kokoro measured
*alone*. In Corpospeak it won't be alone: the design streams sentence-by-sentence, so synthesis of
sentence N overlaps Foundation Models generating sentence N+1 — **both contending for the Neural
Engine**. The number worth measuring is RTF while a rewrite is streaming, not in isolation.

## Measured

`Tools/KokoroCheck` reproduces all of this — it loads the same files the app bundles, with the
network switched off, and prints to stderr:

```
load: 8.31s (offline)
warm-up: 1.67s (discarded)
  [1]  3.95s audio in  0.21s  RTF 0.053  (19x faster than real time)
  [2]  4.20s audio in  0.22s  RTF 0.051  (20x faster than real time)
  [3]  3.33s audio in  0.18s  RTF 0.055  (18x faster than real time)
overall RTF 0.053 — 19.0x faster than real time
```

**Synthesis is not the bottleneck.** A four-second sentence costs about a fifth of a second, so
the first sentence is speaking long before the rewrite has finished writing the rest. The brief's
0.08 estimate was, if anything, pessimistic.

Two things that only showed up by running it:

- **The first load on a device costs minutes, once.** Core ML compiles the seven-stage chain for
  this particular Neural Engine the first time it sees it, and caches the result: 342s cold
  against 8.3s warm, with `KokoroVocoder` alone accounting for four minutes of the cold figure.
  It is a one-time, per-device cost, but it is why `KokoroEngine.prepare()` loads in the
  background and publishes Kokoro into the voice list only when it is ready — on a new install
  the app talks in an Apple voice and switches to Kokoro when it can, rather than going quiet.
- **Measure one process at a time.** An early run had two harnesses competing for the Neural
  Engine on a cold cache and reported RTF 1.58 to 53 — *slower* than real time, which would have
  killed the whole approach if believed. Anything that looks that bad here is contention, not
  Kokoro.

Both figures are from the Mac. The iPhone 15 Pro Max number is the one that decides it — see
"Measuring on the oldest supported device" below.

## Decision: bundle the model, don't download it

Ship the model and a small set of English voices inside the app. Reasons, in order of weight:

1. **PRIVACY.md says "Corpospeak makes no network connections."** The README repeats it and it is
   in the App Store review notes. Fetching a model from HuggingFace on first run makes that claim
   false and makes a third-party server a runtime dependency of an app whose whole promise is that
   nothing leaves the device. `CLAUDE.md` calls that constraint load-bearing rather than a privacy
   footnote, and it is right.
2. **The first-run wait conflicts with the app feeling instant**, as the brief itself says.
3. **The device floor is already high.** Corpospeak requires Apple Intelligence, so the user has
   already downloaded a multi-gigabyte model to use the app at all. Another ~100MB in the bundle is
   not the imposition it would be in a small app.

This is achievable with FluidAudio specifically: `ModelHub.offlineMode` makes network operations
throw rather than silently reach out, and models can be loaded from a bundled directory. Set
offline mode explicitly so the no-network promise is enforced by the code and not just intended.

**There is only one English voice to ship.** The brief expects "50-plus voices across about 10
languages", which is true of Kokoro in general and not true of the Neural Engine build
FluidAudio standardised on. Counting the voice packs in the repo: Mandarin has ~100, Japanese has 5, and
English has exactly one — `ANE/af_heart.bin`. The 54 voices in the repo's `voices/` folder are
`.json` for the older, deprecated StyleTTS2 backend, not `.bin` packs the ANE chain can load.

That collapses the settings work: there is no Kokoro voice picker to build, just a single "Kokoro"
entry sitting between the Personal Voice and Apple's list. If a male or British Kokoro voice is
wanted later, the `.json` embeddings look convertible — `af_heart.bin` is 523,264 bytes, exactly
511 x 256 x 4, the same tensor the JSON holds — but that is a conversion script and a listening
test, not a checkbox, and it is not in this change.

**If the size turns out to be unacceptable**, the fallback is Apple's On-Demand Resources — hosted
by Apple and delivered as part of app delivery rather than app behaviour — and the privacy wording
would need revisiting even then. Direct HuggingFace fetches at runtime are out under any
circumstance.

## Where it plugs into the app

Personal Voice and the Apple built-ins are the *same* engine with different voices, so this is not
three engines; it is two, behind one catalogue:

- `Speaker` stays the coordinator and keeps everything the UI already binds to — the voice
  catalogue, the selection and its `UserDefaults` persistence, `sentences`, `currentSentence`, the
  generation counter that makes `stop()` prompt.
- `VoiceOption` grows a `source` (`.personal` / `.kokoro` / `.system`) in place of the current
  boolean `isPersonalVoice`, which is what the default-selection ladder sorts on. Keep
  `isPersonalVoice` as a computed property so `ContentView` and `CorpospeakModel` don't churn.
- The default ladder in `refresh()` becomes: saved choice → first Personal Voice → **Kokoro's
  default voice** → Apple's default. Today's last two lines already do the first and last steps.
- A `KokoroEngine` owns the model, publishes its voices, and synthesizes. When it can't load, it
  publishes no voices, and the ladder falls through to Apple with no special-casing.
- **Sentence pipelining**: `Speaker.split` already cuts text into sentences with `NLTokenizer` and
  `speak(_:AsyncStream<String>)` already accepts them as they stream out of the rewrite. Kokoro
  needs one addition — synthesize sentence N+1 while sentence N is playing, with a queue depth of
  one or two — because unlike `AVSpeechSynthesizer` it produces a buffer rather than playing for
  us. That is the whole of the "streaming" the brief asks for; there is no token-level audio
  streaming to chase.
- **Playback**: `AudioSession` is already `.playAndRecord` with `.defaultToSpeaker`, so PCM
  playback through an `AVAudioEngine` player node fits without touching the session. Listening is
  already paused while speaking, so the app still won't transcribe itself.

The one genuinely port-dependent piece is a single adapter: *text plus voice id in, 24kHz mono PCM
out*. All four candidates fit that shape, which is why everything above could be settled before the
port was.

## Measuring on the oldest supported device

The oldest supported device is fixed by Apple Intelligence, not by Kokoro: **iPhone 15 Pro / A17
Pro / M1** (`CONTRIBUTING.md`). Alex's iPhone 15 Pro Max *is* that floor device, so the measurement
the brief asks for needs no extra hardware. Kokoro's own floor (iOS 15+, iOS 17+ for the good ANE
paths) is far below Corpospeak's, so the risk of it failing to beat real time there is low.

Measure anyway, and measure the right thing:

- RTF per sentence on the iPhone 15 Pro Max, **while a rewrite is streaming**, not standalone.
- Time from end-of-speech to first audio — the number the user actually feels — compared against
  the current `AVSpeechSynthesizer` path.
- Whether first-sentence synthesis can be hidden behind the rewrite's own latency, the way
  `Translator.prewarm()` already hides the prompt's cost.

## MeSing

Noted, not scoped, per the brief. Kokoro is a speech model: no pitch or duration conditioning for
melody, so it will not fix MeSing's uncanny-valley singing. It could plausibly improve *spoken*
passages there. A singing model is a different search.

## Status

**Settled: FluidAudio 0.15.6, pinned exactly.** The Actionable streaming-diarization task chose it
and wrote down why in `Actionable/docs/speech-stack-decision.md`, which asks Corpospeak to use the
same package and version — the two apps drifting onto different Core ML conversions is a debugging
problem nobody wants, so they bump together. That decision checked the *weights* (`ls-eend-coreml`
MIT, `kokoro-82m-coreml` Apache 2.0); the espeak-ng question above covers the step in front of
them, and FluidAudio's Core ML G2P clears it. Between them the licence position is clean.

It independently matches what the diligence here concluded: Apache 2.0, no espeak-ng anywhere near
it, ANE-resident Core ML rather than MLX, and an offline mode that lets the no-network promise stay
literally true.

One thing that decision doesn't cover, because Actionable doesn't need it: **bundling**. Actionable
can let FluidAudio download to `~/.cache/fluidaudio`. Corpospeak can't, so it ships the models and
copies the shared G2P assets into that cache on first launch. Verified: with `ModelHub.offlineMode`
on, the harness logs *"found in cache"* and downloads nothing.

[hexgrad/kokoro#247]: https://github.com/hexgrad/kokoro/issues/247
[FluidInference/FluidAudio]: https://github.com/FluidInference/FluidAudio
[mweinbach/kokoro-swift]: https://github.com/mweinbach/kokoro-swift
[mlalma/kokoro-ios]: https://github.com/mlalma/kokoro-ios
[mattmireles/kokoro-coreml]: https://github.com/mattmireles/kokoro-coreml
