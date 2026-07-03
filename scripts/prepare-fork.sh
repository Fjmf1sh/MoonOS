#!/usr/bin/env bash
# Prepares the moonlight-qt fork tree for building Moon Shell:
#   1. makes sure the submodule (and its submodules) are checked out
#   2. copies moon-shell/ into the tree as app/moon/
#   3. applies the Moon OS integration patch (idempotent)
#
# Safe to run repeatedly; run it after every `git pull` of this repo.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/third_party/moonlight-qt"
PATCH="$REPO_ROOT/moon-shell/fork/0001-moon-os-fork.patch"

echo "==> Checking out moonlight-qt submodule"
git -C "$REPO_ROOT" submodule update --init --recursive --depth 1 third_party/moonlight-qt

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
