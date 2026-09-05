# Phone probe

A throwaway iOS app that runs prompt variants against the phone's own on-device model and
prints one line per reply to stderr, which `xcrun devicectl device process launch --console`
streams back to the Mac. It exists because the model differs between OS versions and there is
no other way to see what a phone's model does with a prompt.

`run_probe.sh` stages everything into `<repo>/build/Probe/`:

- `Probe/Probe.swift` — harness: test sentences, scoring, the run loop. Rarely needs editing.
- `Probe/Variants.swift` — **the file to edit**: the named prompt variants to compare.
- `Corpospeak/CorpospeakStyle.swift` copied in as-is, so `CorpospeakStyle.*` is the working tree.
- `OldStyle.swift` — the last commit's copy with the enum renamed, so `OldStyle.*` is HEAD.
- `project.yml` with the team id read from the app's `project.yml`; bundle id
  `com.alexcollins.CorpSpeak.probe`, automatic signing.

Options: `--runs N` replies per sentence per variant (default 1), `--device ID` (default: the
first iPhone `devicectl` lists), `--build-only` to stop before installing, `--keep` to leave the
probe installed afterwards.

Reading output: `OK [variant] k/n [COPIED] | reply…`, `FAILED [variant] … REFUSED`, then
`SUMMARY [variant] facts X% of answered, refused r/n, copied c`. `DONE` means the app exited on
its own. No lines for a minute after `availability:` means the phone locked: unlock it and rerun.
