---
name: prompt-eval
description: Measure whether Corpospeak's English→Corpospeak prompt keeps the speaker's facts, avoids pasting example text, and gets past the on-device model's guardrail — on this Mac's model and on a connected iPhone, whose model can behave differently. Use this whenever anything about the prompt changes (CorpospeakStyle.swift, the examples, style principles, phrasebook, rules, temperature, or Translator options), whenever someone says translations are gobbledygook, unfaithful, missing facts, repetitive, or "refused"/"wouldn't touch that", and before shipping any prompt change. Don't judge a prompt change by reading two or three replies; run this instead.
---

# Prompt eval

Corpospeak rewrites speech with Apple's ~3B on-device model. Small models are fickle: a prompt
tweak that reads better can make the model paste its few-shot examples into replies, drop the
speaker's names and numbers, loop on one sentence, or trip the safety guardrail and refuse
outright. And the model is not one model: each OS version ships its own, and they disagree
(see "What we already know"). So every prompt change gets measured twice — on the Mac, and on
a phone — before it ships.

## Two harnesses

| | Mac harness | Phone probe |
| --- | --- | --- |
| Command | `scripts/eval_prompt.sh [runs] [-v]` (repo root) | `.claude/skills/prompt-eval/scripts/probe/run_probe.sh [--runs N] [--device ID]` |
| Tests | the prompt as shipped, cleaned as the app cleans it | named variants listed in `scripts/probe/Probe/Variants.swift` (defaults: shipped prompt vs. the last commit's) |
| Needs | Apple Intelligence on this Mac, ~3 min | a paired iPhone, **unlocked and kept awake** for ~1 min per variant |
| Prints | one summary line | one line per reply plus a `SUMMARY` per variant |

Both score the same things over the same fixed sentences:

- **facts kept** — fraction of the speaker's specifics (names, dates, numbers, products) that
  survive into the reply. The point of the app is to bury the facts, not lose them.
- **copied** — a five-word run from a few-shot example appears in the reply. Copying means
  the model is echoing the prompt instead of rewriting the input.
- **runaway / long** — reply more than 3.5× the input's length, which is nearly always a loop.
- **refused** — the model's guardrail threw `guardrailViolation`. The app shows this as
  "wouldn't touch that one". Any refusal rate above the odd one-in-twenty is a prompt problem.

## Workflow

1. **Baseline first.** Before touching the prompt, run the Mac harness with `3` runs and keep
   the summary line. Without a baseline you can't tell noise from improvement; with three runs
   per sentence, differences under ~10 points of facts-kept are noise.
2. **Change the prompt** in `Corpospeak/CorpospeakStyle.swift` (or the options in
   `Translator.swift`). Build to make sure it compiles.
3. **Mac harness again.** Same runs, compare. To compare several candidates, the quickest way is
   to edit, run, note the line, edit, run — the script always tests what's in the working tree.
4. **Phone probe** for any candidate that wins on the Mac. Add it to `Variants.swift` next to
   `current` and `HEAD`, run `run_probe.sh`, and read the `SUMMARY` lines. Ask the user to
   unlock the phone and keep it awake first; the probe app is suspended the moment the screen
   locks, and the run silently stalls.
5. **Decide.** Ship a change only if it holds up on both models. If the two disagree, either
   find a prompt both accept or select by OS version the way `shortExamples` already does, and
   say so plainly in the report.
6. **Report** a small table: variant × (facts kept, copied, refused) for each device, plus one
   or two example replies. Note the sample size. Record anything durable in CLAUDE.md's
   CorpospeakStyle bullet so the next person doesn't rediscover it.

The probe script handles the fiddly parts (staging the app's style file plus the last commit's
copy renamed `OldStyle`, signing with the team from `project.yml`, building for a generic iOS
destination, installing, and streaming the app's stderr over `devicectl --console`). Read
`scripts/probe/README.md` only if it misbehaves.

## What we already know (measured 2026-09-05)

- **Few-shot examples get pasted.** With work examples ("fix the login bug before the demo"),
  the 26.5 model dropped "remediation pathway for the login experience" into replies about
  servers and launches. Everyday examples fixed it on 26.5: facts kept ~70% → ~85%, copying → 0.
- **The iOS 27 beta model refuses non-work examples.** Every everyday example alone, ten fresh
  candidates, and four generic office examples all drew "may contain unsafe content" on the
  phone; the original work examples pass. Hence `shortExamples` is chosen by OS version.
- **Trimming the prompt hurts.** Cutting the phrasebook to bare phrases, or the rules to a few
  lines, made the model copy examples, add "Certainly!" preambles, and run on. Prefill cost is
  hidden by prewarming instead.
- **No jargon word lists in the prompt.** Given one, the model sometimes replied with the list.
- **Lower temperature made copying worse** (the copy is the mode). 0.45 stays.
- **Removing examples entirely** produces loops ("alignment of the alignment of…").

## Pitfalls that cost time

- `log` is a zsh builtin; use `/usr/bin/log`. `log collect` from a device needs root, so
  device logs are not an option — that's why the probe prints to stderr over `--console`.
- CoreDevice cannot install an app from under `/tmp` ("unable to create bookmark data").
  Build into the repo's ignored `build/` directory, which the script does.
- `xcodebuild` with `-destination id=<device>` hangs when the phone is locked or flaky; the
  script uses `generic/platform=iOS`, which never needs the device.
- macOS has no `timeout` command. Rely on the Bash tool's timeout instead.
- Two simulators can share a name; address devices by id.
- In Swift scripts, long chains of string concatenation can hang the type checker; build
  prompt text with `+=` on a `var`.
