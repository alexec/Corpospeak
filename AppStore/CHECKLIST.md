# Corpospeak's App Store assets, and how to regenerate them

Everything here comes off Alex's own iPhone 15 Pro Max, driven by a UI test with nobody at the
desk. **A simulator cannot produce any of it**: on-device speech recognition never starts there
(the `en_US` model ships as a cryptex the simulator does not mount) and no simulator has a
Personal Voice. Both are in shot.

```bash
SLOT=~/.claude/skills/simulator-testing/assets/sim-slot.sh
UDID=$("$SLOT" claim-device iphone --app Corpospeak)
scripts/device_capture.sh both
"$SLOT" release --mine
```

The Mac speaks the sentences through its own speakers and the phone hears them, so everything in
the shot is the shipping pipeline: a real recogniser, the on-device rewrite, and his own Personal
Voice reading the reply back.

## iPhone, 6.9-inch, portrait — `screenshots/en-US`

**1290 × 2796, which App Store Connect accepts. Upload them as they are. Do not resample.**

| File | What it shows |
|---|---|
| `1-midloop.png` | `YOU SAID` holding a plain sentence, the rewrite under it, the pill on **Speaking**. |
| `2-waiting.png` | The empty state, `Say something in plain English.`, pill on **Listening**. |
| `3-voice-menu.png` | The voice menu with **Your Voice** at the top and his Personal Voice selected. |
| `4-midread.png` | A long reply being read, **Copy** visible. |

## The Guideline 2.1 screen recording

`scripts/device_capture.sh recording` writes it to `build/device-capture/recording` as an mp4 at
1290 × 2796, 30 fps. It is not committed — it runs to tens of megabytes — so regenerate it when
it is needed.

**It starts by deleting the app**, which is the whole point: the reviewer sees the microphone and
speech-recognition prompts as a new user meets them, then the app transcribing and reading a
sentence back. **It has no audio track.** Apple sets no rules on length, aspect or framing for a
review attachment, so that is acceptable, but mux audio in if a future one needs sound.

## What still needs a decision

- **The iPad set.** His iPad (A16) is not Apple Intelligence eligible and its screen is not an
  accepted size, so the iPad frames cannot come off his hardware at all. `~/Tracking/CAPTURE.md`
  has the detail and it needs a decision from him rather than a capture session.
- **The room has to be quiet.** The phone's microphone hears whatever else is talking. The test
  checks the transcript against the line the Mac spoke and refuses the frame otherwise, so a
  noisy room costs a re-run rather than a wrong screenshot — but it does cost a re-run.
