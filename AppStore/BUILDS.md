# What is in each build

Archives are not kept. They are hundreds of megabytes each and `build/` is ignored, so the
only record of what went into a binary on the App Store is a `build-N` tag on the commit it
was cut from. `scripts/ship.sh upload` now writes that tag itself; it used to be a line of
prose in `.claude/ship-it.yml`, which was honoured once and then forgotten.

Build 5 is the first one tagged automatically. Everything before it predates that, and this
file says for each one **how well it is actually known**. The distinction matters: an earlier
session identified a build's commit with `git rev-list -1 --before=<upload time>` and reported
it as fact. The tag existed and pointed somewhere else. The conclusion happened to survive. **A
tag is a record, a timestamp is a guess** — so nothing below is written as fact unless
something was checked.

| Build | Commit | Reached App Store Connect? | How the commit is known |
|-------|--------|---------------------------|-------------------------|
| 1 | not established | Yes — uploaded 4 Sep, **attached to the live macOS 1.0** | No tag, no archive. Upper bound only — see below. |
| 2 | `422660d` (inferred) | Uploaded, never attached to a version | The commit that first set `CFBundleVersion: "2"`. |
| 3 | `a270a23` (inferred) | Uploaded, never attached | The commit that set `CFBundleVersion: "3"`. |
| 4 | `987620a` | Uploaded, attached to iOS 1.0, superseded by build 5 | **Tagged `build-4`, and confirmed against the uploaded binary.** See below. |
| 5 | `cce1024` | **Uploaded for iOS, 16 Sep 2026** | **Tagged `build-5` by `ship.sh upload` itself.** The first build the convention actually caught. |

Build 5 is the one this file was written for. `ship.sh archive` recorded the commit it built
from, `ship.sh upload` tagged it on success and pushed the tag, and nobody had to remember to
do it. Note the commit is `cce1024`, not the `87ad550` that merely set `CFBundleVersion: "5"`.
That is exactly the difference between a tag and an inference, and why builds 2, 3 and 5's
bump commits were never good enough as answers.

Upload and attachment status comes from `BACKLOG.md` item 3, written from App Store Connect
on 2026-09-10; the commits come from this repo. The two are separate claims and only the
second is checkable from here.

## Build 4 — confirmed, not assumed

A TestFlight copy of iOS 1.0 (4) is installed on Alex's Mac at
`/Applications/Corpospeak.app/Wrapper/Corpospeak.app` (it is an iOS build running on Apple
silicon; `iTunesMetadata.plist` says `betaTesterType`, so TestFlight rather than the App
Store). That bundle is a copy of what was actually uploaded, which is exactly what a kept
archive would have given us. Two checks against it, both of which the tagged commit passes:

1. **The parody opening is absent.** `b946910` (10 Sep 08:00) added the line beginning
   "You write parody" to `CorpospeakStyle.swift`. `strings` finds no "parody" in the shipped
   binary, so the build predates `b946910`.
2. **`PrivacyInfo.xcprivacy` is absent from the bundle.** `fd1c911` (10 Sep 07:37) created
   that file. Control: a build from today's tree does contain it, so its absence is evidence
   rather than an artefact of how resources are copied.

`CFBundleVersion` first became 4 at `987620a` (10 Sep 07:24), so the build was cut at or
after it; both checks put it before `fd1c911` (07:37). That leaves `987620a` alone, which is
where `build-4` points. Confirmed.

One string that *is* in the tagged source but not in the binary — "Rewrite every sentence" —
is a red herring: it belongs to the reverse-direction prompt, which the Release optimiser
dead-strips. Don't read a missing string as a mismatch without checking it is reachable.

## Build 1 — what can and cannot be said

The live macOS 1.0 (1) is the one that cannot be reproduced from this repo.

`BACKLOG.md` records it as uploaded on 4 Sep, which agrees with the bound below.

**Bounded, from the repo:** build 1 was never set deliberately. `422660d` (4 Sep 21:35) moved
the build number into `project.yml` and its message explains why — "xcodegen rewrites
Info.plist from project.yml on every generate, so a version edited only in the plist was
silently reset to 1". So build 1 is whatever was built while `project.yml` carried no
`CFBundleVersion` at all, and Xcode defaulted it to 1. The last such commit is `f5c0941`
(4 Sep 21:34:44), one commit and twenty seconds before `422660d`.

**So: at or before `f5c0941`.** That is an upper bound, not an identification, and it is not
tagged, deliberately — writing a guess into a tag is worse than leaving the gap visible.

**How to close it properly, cheaply:** install the live macOS app from the App Store and run
the same bundle checks used for build 4 above. The shipped binary settles it; history cannot.
That slot on this Mac is currently taken by the iOS TestFlight copy, so it needs Alex.
