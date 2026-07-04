#!/usr/bin/env bash
# Moon OS legacy one-command update releaser.
#
# Extracts the compiled Moon Shell binary from the latest build and publishes
# it as a GitHub Release for the retired release-binary updater.
#
#   legacy-image-build/release.sh --repo owner/repo
#   legacy-image-build/release.sh --build --repo owner/repo
#   legacy-image-build/release.sh --version 2026.07.10 --repo owner/repo
#   legacy-image-build/release.sh --dry-run --repo owner/repo
#
# Requirements: git-bash/WSL/Linux with the GitHub CLI (`gh`) authenticated
# (`gh auth login`). For --build you also need Docker.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE_DIR="$REPO_ROOT/deploy/update"

DO_BUILD=0
DRY_RUN=0
REPO=""
VERSION=""
NOTES=""
EXTRA_FLAGS=""

die() { echo "ERROR: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --build)       DO_BUILD=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --repo)        REPO="$2"; shift ;;
        --version)     VERSION="$2"; shift ;;
        --notes)       NOTES="$2"; shift ;;
        --prerelease)  EXTRA_FLAGS="$EXTRA_FLAGS --prerelease" ;;
        --draft)       EXTRA_FLAGS="$EXTRA_FLAGS --draft" ;;
        -h|--help)     grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)             die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

[ -n "$REPO" ] || die "no target repo. Pass --repo owner/repo."

# ---- tooling checks ---------------------------------------------------------
command -v gh >/dev/null 2>&1 || die "GitHub CLI 'gh' not found. Install it and run 'gh auth login'."
if [ "$DRY_RUN" = "0" ]; then
    gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"
fi

# ---- build if asked ---------------------------------------------------------
if [ "$DO_BUILD" = "1" ]; then
    echo "==> Building the legacy image (this compiles moon-shell)..."
    sudo "$REPO_ROOT/legacy-image-build/build.sh" --docker
fi

# ---- locate the release assets ----------------------------------------------
# Preferred: artifacts the build dropped in deploy/update/. Fallback: extract
# from the pi-gen work tree via package-update.sh (native builds only).
if [ ! -f "$UPDATE_DIR/moon-shell-arm64" ]; then
    echo "==> No prebuilt artifact in deploy/update; trying package-update.sh..."
    "$REPO_ROOT/legacy-image-build/package-update.sh" || true
fi
[ -f "$UPDATE_DIR/moon-shell-arm64" ] || die "no moon-shell-arm64 found. Run a build first."

# Ensure version + checksum exist and are consistent.
if [ -z "$VERSION" ]; then
    [ -f "$UPDATE_DIR/version" ] || die "no version file in $UPDATE_DIR."
    VERSION="$(tr -d '[:space:]' < "$UPDATE_DIR/version")"
fi
[ -n "$VERSION" ] && [ "$VERSION" != "development" ] || die "invalid version '$VERSION'."
echo "$VERSION" > "$UPDATE_DIR/version"

# Regenerate the checksum so it always matches the binary being shipped.
( cd "$UPDATE_DIR" && sha256sum moon-shell-arm64 > moon-shell-arm64.sha256 )

if command -v file >/dev/null 2>&1 && ! file "$UPDATE_DIR/moon-shell-arm64" | grep -q 'aarch64'; then
    echo "WARNING: moon-shell-arm64 does not look like an aarch64 binary." >&2
fi

TAG="v$VERSION"
[ -n "$NOTES" ] || NOTES="Moon OS $VERSION"

echo ""
echo "  repo    : $REPO"
echo "  tag     : $TAG"
echo "  version : $VERSION"
echo "  assets  : moon-shell-arm64 ($(du -h "$UPDATE_DIR/moon-shell-arm64" | cut -f1)), .sha256, version"
echo ""

if [ "$DRY_RUN" = "1" ]; then
    echo "(dry run - nothing published)"
    exit 0
fi

# ---- publish (create, or update an existing release in place) ---------------
ASSETS=(
    "$UPDATE_DIR/version"
    "$UPDATE_DIR/moon-shell-arm64"
    "$UPDATE_DIR/moon-shell-arm64.sha256"
)

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "==> Release $TAG exists - updating its assets..."
    gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber
    gh release edit "$TAG" --repo "$REPO" --latest --notes "$NOTES" $EXTRA_FLAGS
else
    echo "==> Creating release $TAG..."
    gh release create "$TAG" "${ASSETS[@]}" \
        --repo "$REPO" --title "Moon OS $VERSION" --notes "$NOTES" --latest $EXTRA_FLAGS
fi

echo ""
echo "Published: https://github.com/$REPO/releases/tag/$TAG"
echo "Legacy release published. Supported installs now update from git instead."
