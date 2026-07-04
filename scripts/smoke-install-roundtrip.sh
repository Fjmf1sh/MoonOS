#!/usr/bin/env bash
# CI smoke test for the install/update/uninstall control flow.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cd "$REPO_ROOT"

bash -n install.sh
bash -n uninstall.sh
bash -n scripts/build-shell.sh
bash -n scripts/prepare-fork.sh
bash -n install/overlay/usr/lib/moonos/update.sh

export MOONOS_ALLOW_UNSUPPORTED=1

bash install.sh --dry-run --no-build --no-restart

MOONOS_REPO_DIR="$REPO_ROOT" \
MOONOS_UPDATE_STATUS="$TMP_DIR/update-status" \
MOONOS_UPDATE_LOG="$TMP_DIR/update.log" \
    bash install/overlay/usr/lib/moonos/update.sh --dry-run

bash uninstall.sh --dry-run --yes

grep -q '^success$' "$TMP_DIR/update-status"
grep -q 'Re-running installer' "$TMP_DIR/update.log"
