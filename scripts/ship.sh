#!/bin/bash
# Ship Corpospeak to App Store Connect, one RELEASING.md step per subcommand.
#
#   ship.sh preflight                 check the tree, tools, and current version/build
#   ship.sh bump [N] [--version X.Y]  set CFBundleVersion (default: current + 1), regenerate
#   ship.sh archive <ios|mac>         Release archive for one platform into build/
#   ship.sh upload <ios|mac>          export that archive straight to App Store Connect
#   ship.sh all [--ios-only]          bump, then archive + upload each platform
#   ship.sh builds                    what commit each uploaded build was cut from
#
# Every step is safe to re-run. Archives take several minutes each, so run them one at a
# time (or `all` in the background) and read build/ship-*.log if anything fails.
#
# Archives are not kept — they are hundreds of megabytes and build/ is ignored — so the only
# record of what is inside a build on sale is a `build-N` tag. `upload` writes that tag
# itself, because the convention was written down in .claude/ship-it.yml and then honoured
# exactly once: macOS 1.0 (1) is live and cannot be reproduced from this repo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT_YML="project.yml"
INFO_PLIST="Corpospeak/Info.plist"
XCODEPROJ="Corpospeak.xcodeproj"
SCHEME="Corpospeak"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
fail() { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

current_build()   { sed -n 's/^ *CFBundleVersion: *"\([^"]*\)".*/\1/p' "$PROJECT_YML"; }
current_version() { sed -n 's/^ *CFBundleShortVersionString: *"\([^"]*\)".*/\1/p' "$PROJECT_YML"; }

archive_path() {
  case "$1" in
    ios) echo "build/Corpospeak-iOS.xcarchive" ;;
    mac) echo "build/Corpospeak.xcarchive" ;;
    *) fail "platform must be ios or mac (got '$1')" ;;
  esac
}

destination() {
  case "$1" in
    ios) echo "generic/platform=iOS" ;;
    mac) echo "generic/platform=macOS" ;;
  esac
}

cmd_preflight() {
  say "Tools"
  command -v xcodegen >/dev/null || fail "xcodegen not installed (brew install xcodegen)"
  command -v xcodebuild >/dev/null || fail "xcodebuild not found; is Xcode installed and selected?"
  xcodebuild -version | head -1
  [ -f ExportOptions.plist ] || fail "ExportOptions.plist missing from repo root"

  say "Git"
  git fetch --quiet origin main
  local branch; branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "branch: $branch"
  if [ -n "$(git status --porcelain)" ]; then
    echo "working tree is NOT clean:"; git status --short
    echo "(ship from a clean tree so the bump commit is exactly what was archived)"
  else
    echo "working tree clean"
  fi
  local behind; behind="$(git rev-list --count HEAD..origin/main)"
  [ "$behind" = "0" ] || echo "HEAD is $behind commit(s) behind origin/main — pull first"

  say "Version"
  echo "project.yml : $(current_version) ($(current_build))"
  echo "Info.plist  : $("$PLIST_BUDDY" -c 'Print CFBundleShortVersionString' "$INFO_PLIST") ($("$PLIST_BUDDY" -c 'Print CFBundleVersion' "$INFO_PLIST"))"
  [ "$(current_build)" = "$("$PLIST_BUDDY" -c 'Print CFBundleVersion' "$INFO_PLIST")" ] \
    || echo "project.yml and Info.plist disagree — run 'xcodegen generate'"
  local last; last="$(git log -1 --format='%h %s (%as)' --grep='^Bump build' || true)"
  [ -n "$last" ] && echo "last bump  : $last"

  say "Build record"
  local untagged=""
  for n in $(seq 1 "$(current_build)"); do
    git rev-parse -q --verify "refs/tags/build-$n" >/dev/null || untagged="$untagged $n"
  done
  if [ -n "$untagged" ]; then
    echo "no build-N tag for:$untagged"
    echo "(only builds that actually reached App Store Connect need one — see AppStore/BUILDS.md)"
  else
    echo "every build up to $(current_build) is tagged"
  fi

  say "Changes since the last bump"
  local since; since="$(git log -1 --format=%H --grep='^Bump build' || true)"
  if [ -n "$since" ]; then
    git log --oneline --no-merges "$since..HEAD" | sed 's/^/  /'
    if git diff --quiet "$since..HEAD" -- Corpospeak/CorpospeakStyle.swift Corpospeak/Services/Translator.swift; then
      echo "prompt unchanged since last bump"
    else
      echo "PROMPT CHANGED since last bump — run the prompt-eval skill before shipping"
    fi
  fi
}

cmd_bump() {
  local new="" version=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --version) version="$2"; shift 2 ;;
      -*) fail "unknown option $1" ;;
      *) new="$1"; shift ;;
    esac
  done
  local old; old="$(current_build)"
  [ -n "$old" ] || fail "could not read CFBundleVersion from $PROJECT_YML"
  [ -n "$new" ] || new=$((old + 1))
  [[ "$new" =~ ^[0-9]+$ ]] || fail "build number must be an integer (got '$new')"
  [ "$new" -ge "$old" ] || fail "build $new is lower than the current $old; App Store Connect rejects reused or lower numbers"

  say "Bump build $old -> $new${version:+, version $(current_version) -> $version}"
  sed -i '' "s/^\( *CFBundleVersion: *\)\"[^\"]*\"/\1\"$new\"/" "$PROJECT_YML"
  if [ -n "$version" ]; then
    sed -i '' "s/^\( *CFBundleShortVersionString: *\)\"[^\"]*\"/\1\"$version\"/" "$PROJECT_YML"
  fi
  xcodegen generate >/dev/null
  local plist_build; plist_build="$("$PLIST_BUDDY" -c 'Print CFBundleVersion' "$INFO_PLIST")"
  [ "$plist_build" = "$new" ] || fail "Info.plist has build $plist_build after xcodegen; expected $new"
  git --no-pager diff --stat -- "$PROJECT_YML" "$INFO_PLIST"
}

cmd_archive() {
  local platform="${1:-}"; [ -n "$platform" ] || fail "usage: ship.sh archive <ios|mac>"
  local archive; archive="$(archive_path "$platform")"
  local log="build/ship-$platform-archive.log"
  [ -d "$XCODEPROJ" ] || xcodegen generate >/dev/null
  mkdir -p build
  rm -rf "$archive"

  say "Archive $platform -> $archive (log: $log)"
  if ! xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" -configuration Release \
        -destination "$(destination "$platform")" -archivePath "$archive" \
        -allowProvisioningUpdates archive >"$log" 2>&1; then
    grep -E 'error:|\*\* ARCHIVE' "$log" | tail -20 >&2
    fail "archive failed; full log in $log"
  fi
  local built; built="$("$PLIST_BUDDY" -c 'Print :ApplicationProperties:CFBundleVersion' "$archive/Info.plist")"
  [ "$built" = "$(current_build)" ] || fail "archive contains build $built but project.yml says $(current_build)"

  # Which commit this came out of, written down now rather than worked out later. HEAD can
  # move between archiving and uploading, so upload reads this file and not HEAD.
  local dirty="clean"
  [ -n "$(git status --porcelain)" ] && dirty="DIRTY"
  printf '%s %s %s\n' "$(git rev-parse HEAD)" "$dirty" "$built" > "$archive.commit"
  [ "$dirty" = "clean" ] || echo "warning: archived from a DIRTY tree — the tag will say so, but the build is not reproducible"
  echo "archived $(current_version) ($built) for $platform from $(git rev-parse --short HEAD) ($dirty)"
}

# The record of what is in a build on sale. Annotated so it carries who, when and which
# platform; never moved once written, because a tag that moves is not a record.
tag_build() {
  local build="$1" commit="$2" dirty="$3" platform="$4"
  local tag="build-$build"

  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    local existing; existing="$(git rev-list -n1 "$tag")"
    if [ "$existing" = "$commit" ]; then
      echo "tag $tag already records $(git rev-parse --short "$commit")"
      return 0
    fi
    fail "tag $tag already points at $(git rev-parse --short "$existing") but this upload came from $(git rev-parse --short "$commit"); two different builds cannot share a number — check what was really uploaded before touching the tag"
  fi

  git tag -a "$tag" "$commit" -m "$(current_version) ($build) uploaded for $platform on $(date -u '+%Y-%m-%d %H:%M UTC') from a $dirty tree"
  echo "tagged $tag at $(git rev-parse --short "$commit")"

  # A tag only on this Mac is the same gap in a smaller form. Push it when the commit is
  # already public; never push a tag that would drag unpublished commits along with it.
  if git merge-base --is-ancestor "$commit" origin/main 2>/dev/null; then
    git push --quiet origin "$tag" 2>/dev/null \
      && echo "pushed $tag to origin" \
      || echo "warning: could not push $tag — push it by hand so the record is not only on this Mac"
  else
    echo "warning: $commit is not on origin/main, so $tag stays local; push the commit, then 'git push origin $tag'"
  fi
}

cmd_builds() {
  say "Uploaded builds"
  local found=0
  for tag in $(git tag -l 'build-*' | sort -t- -k2 -n); do
    found=1
    printf '  %-9s %s  %s\n' "$tag" "$(git rev-parse --short "$tag"^{commit})" "$(git tag -l --format='%(contents:subject)' "$tag")"
  done
  [ "$found" = "1" ] || echo "  none — no build has been tagged"
  echo
  echo "Builds with no tag are recorded, with how well they are known, in AppStore/BUILDS.md."
}

cmd_upload() {
  local platform="${1:-}"; [ -n "$platform" ] || fail "usage: ship.sh upload <ios|mac>"
  local archive; archive="$(archive_path "$platform")"
  local log="build/ship-$platform-upload.log"
  [ -d "$archive" ] || fail "$archive not found; run 'ship.sh archive $platform' first"

  say "Upload $platform archive to App Store Connect (log: $log)"
  if ! xcodebuild -exportArchive -archivePath "$archive" \
        -exportOptionsPlist ExportOptions.plist -exportPath "build/export-$platform" \
        -allowProvisioningUpdates >"$log" 2>&1; then
    grep -E 'error:|\*\* EXPORT' "$log" | tail -20 >&2
    fail "upload failed; full log in $log"
  fi
  grep -E '\*\* EXPORT' "$log" || true
  echo "uploaded $(current_version) ($(current_build)) for $platform; Apple processes it in a few minutes"

  if [ -f "$archive.commit" ]; then
    read -r commit dirty built < "$archive.commit"
    tag_build "$built" "$commit" "$dirty" "$platform"
  else
    echo "warning: no $archive.commit — this archive predates the record, so nothing was tagged."
    echo "         Work out which commit it was cut from and 'git tag -a build-$(current_build) <commit>' by hand."
  fi
}

cmd_all() {
  local platforms="ios mac"
  [ "${1:-}" = "--ios-only" ] && platforms="ios"
  cmd_bump
  for p in $platforms; do cmd_archive "$p"; done
  for p in $platforms; do cmd_upload "$p"; done
  say "Done: $(current_version) ($(current_build)) uploaded for: $platforms"
}

case "${1:-}" in
  preflight) shift; cmd_preflight "$@" ;;
  bump)      shift; cmd_bump "$@" ;;
  archive)   shift; cmd_archive "$@" ;;
  upload)    shift; cmd_upload "$@" ;;
  all)       shift; cmd_all "$@" ;;
  builds)    shift; cmd_builds "$@" ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac
