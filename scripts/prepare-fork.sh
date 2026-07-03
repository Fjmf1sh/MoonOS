#!/usr/bin/env bash
# Prepares the moonlight-qt fork tree for building Moon Shell:
#   1. makes sure moonlight-qt is checked out at the pinned upstream commit
#   2. copies moon-shell/ into the tree as app/moon/
#   3. applies the Moon OS integration patch (idempotent)
#
# The fork is ALWAYS applied at build time and never committed into the
# moonlight-qt tree — committing it there would pin the superproject to a
# private commit that GitHub/CI can't fetch ("not our ref"), which is exactly
# what this script's hard reset to $MOONLIGHT_REF guards against.
#
# Safe to run repeatedly; run it after every `git pull` of this repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/third_party/moonlight-qt"
PATCH="$REPO_ROOT/moon-shell/fork/0001-moon-os-fork.patch"

# Public upstream commit the fork patch is generated against. Override with
# MOONLIGHT_REF=<sha|tag>. Must be reachable from a ref on the upstream remote
# (i.e. an actual pushed commit) so CI can fetch it.
MOONLIGHT_URL="${MOONLIGHT_URL:-https://github.com/moonlight-stream/moonlight-qt}"
MOONLIGHT_REF="${MOONLIGHT_REF:-fd34a1fd28e9cc5b856e1c1cbcbf824866697f46}"

if [ ! -e "$UPSTREAM/.git" ]; then
    # No checkout present (e.g. CI cloned the superproject with submodules
    # disabled). Clone moonlight-qt fresh at the pinned commit.
    echo "==> Cloning moonlight-qt at $MOONLIGHT_REF"
    rm -rf "$UPSTREAM"
    git clone "$MOONLIGHT_URL" "$UPSTREAM"
    git -C "$UPSTREAM" checkout -f "$MOONLIGHT_REF"
    git -C "$UPSTREAM" submodule update --init --recursive
else
    # Existing checkout (local dev / submodule). Force it onto the pinned
    # commit so any stray local commit or leftover fork files are discarded.
    echo "==> Pinning moonlight-qt to $MOONLIGHT_REF"
    git -C "$UPSTREAM" fetch --quiet "$MOONLIGHT_URL" "$MOONLIGHT_REF" 2>/dev/null || \
        git -C "$UPSTREAM" fetch --quiet --all 2>/dev/null || true
    git -C "$UPSTREAM" checkout -f "$MOONLIGHT_REF"
    git -C "$UPSTREAM" clean -fdq app 2>/dev/null || true
    git -C "$UPSTREAM" submodule update --init --recursive
fi

echo "==> Syncing Moon Shell sources into app/moon/"
rm -rf "$UPSTREAM/app/moon"
mkdir -p "$UPSTREAM/app/moon"
cp -a "$REPO_ROOT/moon-shell/moon.pri" \
      "$REPO_ROOT/moon-shell/moon.qrc" \
      "$REPO_ROOT/moon-shell/src" \
      "$REPO_ROOT/moon-shell/qml" \
      "$UPSTREAM/app/moon/"

echo "==> Applying fork patch"
if git -C "$UPSTREAM" apply --reverse --check "$PATCH" 2>/dev/null; then
    echo "    already applied, skipping"
elif git -C "$UPSTREAM" apply --check "$PATCH" 2>/dev/null; then
    git -C "$UPSTREAM" apply "$PATCH"
else
    echo "ERROR: patch does not apply to this moonlight-qt revision." >&2
    echo "Upstream moved — refresh moon-shell/fork/0001-moon-os-fork.patch" >&2
    echo "(see docs/ARCHITECTURE.md, section 'Updating the fork')." >&2
    exit 1
fi

echo "==> Fork ready at $UPSTREAM"
