# Luxury audit — Corpospeak

_2026-09-10 · 12 Swift files, 2705 lines · gate audit for the move into `review`_

## Score: 47 / 100 — ceiling 68

**The first thing anyone meets is not the app. It is two system permission dialogs, back to
back, before a single word has been said.** The sweep set out to photograph the app's own
interface in light, dark and the largest accessibility type, and in all four images it caught a
permission alert instead. On a phone there is a third, for the Personal Voice. Nothing else in
this report costs as much, and App Review meets it before anyone else does.

The gap between 47 and 68 is what has never been checked by hand: frame rate, gesture feel and
haptics cannot be scored from a simulator, so they rest at 3 — "no visible defects, unproven" —
rather than at 5.

| # | Dimension | Score / ceiling | Evidence |
|---|---|---|---|
| 1 | Cold start | 3 / 5 | instrumented, 5 cold launches |
| 2 | Ready on open | **2** / 2 | static + screenshots |
| 3 | Frame rate & scrolling | 3 / 5 | static only |
| 4 | Touch responsiveness | 2 / 4 | static only |
| 5 | Blocking states | 3 / 5 | static, nothing matched |
| 6 | Gesture fidelity | 3 / 5 | static only |
| 7 | Animation quality | **2** / 2 | static |
| 8 | Type, spacing & colour | **2** / 2 | static + screenshots |
| 9 | Platform integration | **2** / 2 | static, conclusive |
| 10 | Sound & haptics | **1** / 2 | static |
| 11 | Errors & edge cases | 2 / 2 | static |
| 12 | Accessibility | 2 / 2 | static |

## Three things

**The permission wall is the whole first impression.** `CorpospeakModel.start()` runs
`listener.start()` and then `speaker.requestAuthorizationIfNeeded()`, so a fresh install fires
Speech Recognition, then Microphone, then Personal Voice — none of them primed, all before the
app has done anything. The house pattern is a priming view in the app's own voice, at the moment
of use, saying what the feature does and why it needs the access. At the largest accessibility
type Apple's own alert clips mid-word ("Speech Recogn…"), which is not something the app can fix
from inside the alert — but a priming screen means the person already knows what they are being
asked before the alert appears.

**Nothing lands in the hand.** Thirteen interactive controls, zero haptic call sites. Mute, stop,
copy and choosing a voice are all physical-feeling actions with no feedback at all. This is the
one place the app contradicts a value stated everywhere else in these projects.

**Opening the app stops your music.** `AudioSession.activate()` takes `.playAndRecord` at launch
and holds it for the app's lifetime. Some of that is inherent — it is a listening app — but it
claims the session on launch rather than at first use, so opening Corpospeak to look at it kills
whatever was playing.

## Fixes, in priority order

`impact = weight × severity`.

1. **Prime every permission** — `CorpospeakModel.swift:57–64`, `SpeechListener.swift:75,320`,
   `Speaker.swift:117`. A view in the app's voice before each alert, asked when the feature is
   first used rather than at launch. `in-app-help` has the house pattern. *(ready, 12)*
2. **Don't claim the audio session until first use** — `AudioSession.swift:6`. Activate when
   listening actually starts, and deactivate when the app backgrounds. *(snd, 6)*
3. **Add haptics to the four controls** — mute `ContentView.swift:537`, stop `:451`, copy `:232`,
   voice selection `:595`. `.sensoryFeedback(.selection, trigger:)` for the menu, `.impact` for
   mute and stop, `.success` for copy. *(snd, 6)*
4. **Make the fixed sizes scale** — `ContentView.swift:452, 459, 538, 669, 729`.
   `.custom(_:relativeTo:)` keeps the look and follows Dynamic Type. *(type, 8)*
5. **Honour Reduce Motion** — nothing in the repo reads `accessibilityReduceMotion`, and the
   sentences rise in one after another with a per-index delay (`ContentView.swift:121`). *(a11y, 5)*
6. **Replace fixed-duration curves with springs** on anything a finger drives —
   `ContentView.swift:247` (copy), `:475` (hover), `:126`, `:139`. Fourteen sites use
   `.easeInOut(duration:)`; the state-driven ones are defensible, the touch-driven ones are not.
   *(anim, 8)*
7. **Stop showing framework error text** — `CorpospeakModel.swift:222`,
   `SpeechListener.swift:97,118`. `error.localizedDescription` is Apple's words, not the app's.
   *(err, 5)*
8. **Label the glyphs** — `ContentView.swift:232, 451, 537, 664, 728`. VoiceOver reads the SF
   Symbol name otherwise. The voice menu at `:591` already does this correctly. *(a11y, 5)*
9. **Enlarge the small hit regions** — `ContentView.swift:540, 731` are 30×30. Keep the ink,
   grow the tappable area to 44. *(touch, 10)*
10. **A share sheet for the rewrite** — there is a `CopyButton` but no `ShareLink`. The output of
    this app is a joke you send to someone. *(plat, 6)*
11. **An App Intent** — "Corpospeak this" from Shortcuts or the share sheet is the natural second
    entry point, and there is no App Intents surface at all. *(plat, 6)*
12. **Move the colour literal out of the view** — `ContentView.swift:378`. *(type, 8)*

Cut for length: Spotlight indexing, Handoff, Live Activities, matched-geometry transitions, and
the `GeometryReader` uses at `:91` and `:383` (layout-level, not per-row — checked, not a
finding).

## Checked and discarded

- `.task { await model.start() }` (`CorpospeakApp.swift:11`) does **not** gate first paint. The
  view draws its full chrome immediately; confirmed on the simulator.
- `try! NSRegularExpression` (`CorpospeakModel.swift:250`) is a static literal pattern. It can
  only fail in development, never for a user.
- `WindowDragGesture()` (`ContentView.swift:48`) is macOS window dragging, not a re-implemented
  scroll view.
- The "settled at 3317ms" from the launch probe is an artefact: the listening waveform animates
  continuously by design, so the app never stops moving. Two of five runs never settled at all.

## Not raised

- **Dark only.** `.preferredColorScheme(.dark)` is the design. Recorded in `.claude/luxury.yml`
  so it stops being raised.
- **On-demand model downloads.** `BACKLOG.md`'s *Won't build* settles this.

## By hand — five minutes with the phone

The simulator cannot judge any of these.

1. Does the first launch feel like an interrogation? Delete the app first.
2. Mute, then unmute. Does anything land in the hand?
3. Press stop mid-sentence. Does speech cut immediately, or finish the word?
4. Start music, then open Corpospeak. What happens to the music?
5. Scroll a long reply while it is still being spoken. Any hitch?
6. Switch voice mid-reply. Does it change cleanly or stutter?
7. Largest accessibility type, Settings → Display: does the app's own layout hold?
8. Reduce Motion on: do the sentences still fly in?
9. VoiceOver on the four toolbar buttons: are they named or read as symbols?
10. On the Mac: drag the window by its background. Does it feel native?

## History

| date | score | ceiling | note |
|---|---|---|---|
| 2026-09-10 | 47 | 68 | first audit; gate for `review` |
