#!/usr/bin/env bash
# Builds the moon-shell binary natively on a Debian/Raspberry Pi OS (bookworm)
# machine — used for development on a Pi and by the image build inside the
# pi-gen chroot. Produces third_party/moonlight-qt/build/app/moon-shell.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/third_party/moonlight-qt"
JOBS="${JOBS:-$(nproc)}"

if [ ! -f "$UPSTREAM/app/moon/moon.pri" ]; then
    "$REPO_ROOT/scripts/prepare-fork.sh"
fi

if [ "${SKIP_DEPS:-0}" != "1" ]; then
    echo "==> Installing build dependencies (sudo apt)"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        build-essential pkg-config \
        qt6-base-dev qt6-declarative-dev qt6-base-dev-tools libqt6svg6-dev \
        libgl1-mesa-dev libegl1-mesa-dev \
        libopus-dev libsdl2-dev libsdl2-ttf-dev libssl-dev \
        libavcodec-dev libavformat-dev libswscale-dev \
        libva-dev libvdpau-dev libdrm-dev \
        libxkbcommon-dev wayland-protocols \
        libcec-dev
fi

echo "==> Building moon-shell (-j$JOBS)"
mkdir -p "$UPSTREAM/build"
cd "$UPSTREAM/build"
qmake6 "$UPSTREAM/moonlight-qt.pro"
make -j"$JOBS"

echo "==> Built: $UPSTREAM/build/app/moon-shell"
