#!/usr/bin/env bash
# Builds the flashable Moon OS image: deploy/moon-os-rpi4-rpi5.img
#
# Must run on Debian/Ubuntu (or the pi-gen Docker path) as root, with
# qemu-user-static + binfmt for the arm64 chroot. See README.md
# "Building the image" for the exact host requirements.
#
# Usage:
#   sudo os-image/build.sh            # native pi-gen build
#   sudo os-image/build.sh --docker   # containerized build (needs Docker)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PI_GEN_DIR="$REPO_ROOT/os-image/pi-gen"
PI_GEN_REPO="${PI_GEN_REPO:-https://github.com/RPi-Distro/pi-gen}"
# The arm64 branch produces 64-bit images — required for Pi 4/5 and the
# V4L2 stateless HEVC decode path moonlight uses.
PI_GEN_BRANCH="${PI_GEN_BRANCH:-arm64}"
USE_DOCKER=0
[ "${1:-}" = "--docker" ] && USE_DOCKER=1

echo "==> Preparing the Moonlight fork"
"$REPO_ROOT/scripts/prepare-fork.sh"

echo "==> Fetching pi-gen ($PI_GEN_BRANCH)"
if [ ! -d "$PI_GEN_DIR" ]; then
    git clone --depth 1 --branch "$PI_GEN_BRANCH" "$PI_GEN_REPO" "$PI_GEN_DIR"
else
    rm -rf "$PI_GEN_DIR/export-image"
    git -C "$PI_GEN_DIR" reset --hard
    git -C "$PI_GEN_DIR" clean -fdx
    git -C "$PI_GEN_DIR" fetch --depth 1 origin "$PI_GEN_BRANCH"
    git -C "$PI_GEN_DIR" checkout -f FETCH_HEAD
fi

# Keep pi-gen scripts usable when this repo is checked out from Windows.
git -C "$PI_GEN_DIR" ls-files -z | (
    cd "$PI_GEN_DIR"
    xargs -0 sed -i 's/\r$//'
)

# pi-gen's Docker wrapper currently sources config without quotes, which
# breaks when this repository lives in a path containing spaces.
if [ -f "$PI_GEN_DIR/build-docker.sh" ]; then
    sed -i 's/source ${CONFIG_FILE}/source "${CONFIG_FILE}"/' "$PI_GEN_DIR/build-docker.sh"
    sed -i 's/binfmt_misc_required=1/binfmt_misc_required=0/' "$PI_GEN_DIR/build-docker.sh"
fi
APT_SETUP="$PI_GEN_DIR/stage0/00-configure-apt/00-run.sh"
if [ -f "$APT_SETUP" ]; then
    sed -i '/raspberrypi-archive-keyring.pgp/a install -m 644 /usr/share/keyrings/debian-archive-keyring.pgp "${ROOTFS_DIR}/usr/share/keyrings/"' "$APT_SETUP"
fi
STAGE2_PACKAGES="$PI_GEN_DIR/stage2/01-sys-tweaks/00-packages"
if [ -f "$STAGE2_PACKAGES" ]; then
    sed -i \
        -e 's/\brpi-swap rpi-loop-utils\b//' \
        -e 's/\brpi-usb-gadget\b//' \
        -e '/^[[:space:]]*$/d' \
        "$STAGE2_PACKAGES"
fi
STAGE2_TWEAKS="$PI_GEN_DIR/stage2/01-sys-tweaks/01-run.sh"
if [ -f "$STAGE2_TWEAKS" ]; then
    sed -i 's/systemctl enable rpi-resize/systemctl enable rpi-resize || true/' "$STAGE2_TWEAKS"
fi
rm -rf "$PI_GEN_DIR/stage2/04-cloud-init"

echo "==> Installing the Moon OS stage into pi-gen"
rm -rf "$PI_GEN_DIR/stage-moonos"
cp -a "$REPO_ROOT/os-image/stage-moonos" "$PI_GEN_DIR/stage-moonos"
cp -a "$REPO_ROOT/os-image/overlay" "$PI_GEN_DIR/stage-moonos/overlay"

echo "==> Bundling prepared source for the in-chroot build"
SRC_TAR="$PI_GEN_DIR/stage-moonos/02-build-shell/files/moonlight-src.tar.gz"
mkdir -p "$(dirname "$SRC_TAR")"
tar -C "$REPO_ROOT/third_party" \
    --exclude='moonlight-qt/.git' \
    --exclude='moonlight-qt/build' \
    -czf "$SRC_TAR" moonlight-qt

echo "==> Writing pi-gen config"
VERSION="$(date +%Y.%m.%d)"
echo "$VERSION" > "$PI_GEN_DIR/stage-moonos/overlay/etc/moonos/version"
cat > "$PI_GEN_DIR/config" <<EOF
IMG_NAME="moon-os"
RELEASE="bookworm"
DEPLOY_COMPRESSION="none"
TARGET_HOSTNAME="moonos"
FIRST_USER_NAME="moon"
FIRST_USER_PASS="moonos"
DISABLE_FIRST_BOOT_USER_RENAME=1
ENABLE_SSH=0
LOCALE_DEFAULT="en_US.UTF-8"
KEYBOARD_KEYMAP="us"
KEYBOARD_LAYOUT="English (US)"
TIMEZONE_DEFAULT="Etc/UTC"
STAGE_LIST="stage0 stage1 stage2 stage-moonos"
EOF

echo "==> Running pi-gen (this takes a while — Qt compiles inside the chroot)"
cd "$PI_GEN_DIR"
if [ "$USE_DOCKER" = "1" ]; then
    ./build-docker.sh
else
    ./build.sh
fi

echo "==> Collecting the image"
mkdir -p "$REPO_ROOT/deploy"
IMG_SRC="$(ls -t "$PI_GEN_DIR"/deploy/*moon-os*.img 2>/dev/null | head -1)"
if [ -z "$IMG_SRC" ]; then
    echo "ERROR: pi-gen did not produce an image — check $PI_GEN_DIR/deploy and the build log." >&2
    exit 1
fi
cp -f "$IMG_SRC" "$REPO_ROOT/deploy/moon-os-rpi4-rpi5.img"

# Collect the self-update artifacts emitted by the 02-build-shell stage
# (the compiled aarch64 binary + version + checksum) so scripts/release.sh
# can publish them without re-extracting from the image.
if [ -f "$PI_GEN_DIR/deploy/moon-shell-arm64" ]; then
    mkdir -p "$REPO_ROOT/deploy/update"
    cp -f "$PI_GEN_DIR/deploy/moon-shell-arm64" "$REPO_ROOT/deploy/update/moon-shell-arm64"
    cp -f "$PI_GEN_DIR/deploy/moon-shell-arm64.sha256" "$REPO_ROOT/deploy/update/moon-shell-arm64.sha256" 2>/dev/null || true
    if [ -f "$PI_GEN_DIR/deploy/moon-shell-version" ]; then
        cp -f "$PI_GEN_DIR/deploy/moon-shell-version" "$REPO_ROOT/deploy/update/version"
    else
        echo "$VERSION" > "$REPO_ROOT/deploy/update/version"
    fi
    echo "==> Update artifacts ready in $REPO_ROOT/deploy/update"
fi

echo ""
echo "Done: $REPO_ROOT/deploy/moon-os-rpi4-rpi5.img (Moon OS $VERSION)"
echo "Flash it with Raspberry Pi Imager → 'Use custom image'."
echo "Publish this build as an update with:  scripts/release.sh"
