#!/usr/bin/env bash
# Produces the release assets the in-console updater downloads:
#   deploy/update/version
#   deploy/update/moon-shell-arm64
#   deploy/update/moon-shell-arm64.sha256
#
# Run it after legacy-image-build/build.sh (it pulls the aarch64 moon-shell binary that
# was compiled inside the pi-gen chroot). Then attach the three files to a
# GitHub release. This was used by the retired release-binary updater.
#
# Usage:
#   legacy-image-build/package-update.sh [path/to/moon-shell]
# If no path is given, it searches the pi-gen work tree from the last build.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/deploy/update"
VERSION_SRC="$REPO_ROOT/install/overlay/etc/moonos/version"

BIN="${1:-}"
if [ -z "$BIN" ]; then
    # Newest moon-shell under the pi-gen rootfs from the last build.
    BIN="$(find "$REPO_ROOT/legacy-image-build/pi-gen/work" -path '*/rootfs/usr/bin/moon-shell' \
            -type f 2>/dev/null | xargs -r ls -t 2>/dev/null | head -1 || true)"
fi

if [ -z "$BIN" ] || [ ! -f "$BIN" ]; then
    echo "ERROR: could not find a built moon-shell binary." >&2
    echo "Run legacy-image-build/build.sh first, or pass the path explicitly." >&2
    exit 1
fi

# Confirm it is the aarch64 binary the Pi will run.
if command -v file >/dev/null && ! file "$BIN" | grep -q 'aarch64'; then
    echo "WARNING: $BIN does not look like an aarch64 binary." >&2
fi

# Use the version from the SAME rootfs as the binary (build.sh stamps the
# build date into the image's /etc/moonos/version). This must match what the
# console reports, or the updater's version comparison breaks. Fall back to
# the repo overlay when a binary path is passed by hand.
ROOTFS_VERSION="${BIN%/usr/bin/moon-shell}/etc/moonos/version"
if [ "$ROOTFS_VERSION" != "$BIN" ] && [ -r "$ROOTFS_VERSION" ]; then
    VERSION="$(tr -d '[:space:]' < "$ROOTFS_VERSION")"
else
    VERSION="$(tr -d '[:space:]' < "$VERSION_SRC" 2>/dev/null || echo "0.0.0")"
fi
if [ -z "$VERSION" ] || [ "$VERSION" = "development" ]; then
    VERSION="$(date +%Y.%m.%d)"
    echo "NOTE: no stamped version found; using today's date: $VERSION" >&2
fi

mkdir -p "$OUT"
cp -f "$BIN" "$OUT/moon-shell-arm64"
echo "$VERSION" > "$OUT/version"
( cd "$OUT" && sha256sum moon-shell-arm64 > moon-shell-arm64.sha256 )

echo "Release assets ready in $OUT :"
ls -l "$OUT"
echo ""
echo "Publish them, e.g. with the GitHub CLI:"
echo "  gh release create v$VERSION $OUT/version $OUT/moon-shell-arm64 $OUT/moon-shell-arm64.sha256 \\"
echo "     --repo <owner>/<repo> --title \"Moon OS $VERSION\" --latest"
echo ""
echo "This is a legacy artifact path. The supported updater now pulls git and reruns install.sh."
