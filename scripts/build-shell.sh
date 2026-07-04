#!/usr/bin/env bash
# Builds the moon-shell binary on Debian/Raspberry Pi OS (bookworm), or in a
# Debian bookworm Docker container with --docker. The Docker path is the
# shell-only equivalent of os-image/build.sh --docker: prepare the Moonlight
# fork, compile Moon Shell for aarch64/bookworm, and package only the updater
# assets instead of building the full flashable image.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="$REPO_ROOT/third_party/moonlight-qt"
JOBS="${JOBS:-$(nproc)}"
USE_DOCKER=0
PACKAGE_UPDATE=0
VERSION="${VERSION:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --docker) USE_DOCKER=1 ;;
        --package-update) PACKAGE_UPDATE=1 ;;
        --version) VERSION="$2"; shift ;;
        -h|--help)
            sed -n '1,18p' "$0" | sed 's/^# \{0,1\}//'
            echo ""
            echo "Usage:"
            echo "  scripts/build-shell.sh"
            echo "  scripts/build-shell.sh --docker --package-update --version 2026.07.04"
            exit 0
            ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$USE_DOCKER" = "1" ]; then
    echo "==> Preparing the Moonlight fork"
    "$REPO_ROOT/scripts/prepare-fork.sh"

    echo "==> Building moon-shell in Debian bookworm Docker"
    docker run --rm \
        --volume "$REPO_ROOT:/work" \
        --workdir /work \
        -e JOBS="$JOBS" \
        debian:bookworm \
        bash -euxo pipefail -c '
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y --no-install-recommends \
                build-essential file pkg-config \
                qt6-base-dev qt6-declarative-dev qt6-base-dev-tools libqt6svg6-dev \
                libgl1-mesa-dev libegl1-mesa-dev \
                libopus-dev libsdl2-dev libsdl2-ttf-dev libssl-dev \
                libavcodec-dev libavformat-dev libswscale-dev \
                libva-dev libvdpau-dev libdrm-dev \
                libxkbcommon-dev wayland-protocols \
                libcec-dev

            export LC_ALL=C LANG=C TERM=dumb GCC_COLORS=
            SKIP_DEPS=1 /work/scripts/build-shell.sh
        '

    if [ "$PACKAGE_UPDATE" = "1" ]; then
        "$REPO_ROOT/scripts/package-update.sh" "$UPSTREAM/build/app/moon-shell"
        if [ -n "$VERSION" ]; then
            echo "$VERSION" > "$REPO_ROOT/deploy/update/version"
            ( cd "$REPO_ROOT/deploy/update" && sha256sum moon-shell-arm64 > moon-shell-arm64.sha256 )
        fi
    fi
    exit 0
fi

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
if [ -f Makefile ]; then
    make -j"$JOBS"
elif [ -f Makefile.Release ]; then
    make -f Makefile.Release -j"$JOBS"
else
    echo "ERROR: qmake did not generate Makefile or Makefile.Release" >&2
    exit 1
fi

if [ ! -x "$UPSTREAM/build/app/moon-shell" ]; then
    echo "ERROR: expected moon-shell binary was not produced at $UPSTREAM/build/app/moon-shell" >&2
    find "$UPSTREAM/build/app" -maxdepth 4 -type f -name 'moon-shell*' -print >&2 || true
    exit 1
fi

echo "==> Built: $UPSTREAM/build/app/moon-shell"
