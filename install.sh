#!/usr/bin/env bash
# Install Moon OS onto an existing Raspberry Pi OS Lite 64-bit system.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$REPO_ROOT/install/overlay"
STATE_DIR="${MOONOS_STATE_DIR:-/var/lib/moonos}"
INSTALL_CONF="/etc/moonos/install.conf"
JOBS="${JOBS:-$(nproc)}"
ORIG_ARGS=("$@")

DRY_RUN=0
NO_BUILD=0
NO_RESTART=0
FROM_UPDATE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --no-build) NO_BUILD=1 ;;
        --no-restart) NO_RESTART=1 ;;
        --from-update) FROM_UPDATE=1 ;;
        -h|--help)
            sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
run() {
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

if [ "$DRY_RUN" != "1" ] && [ "$(id -u)" -ne 0 ]; then
    exec sudo -E bash "$0" "${ORIG_ARGS[@]}"
fi

check_host() {
    if [ "${MOONOS_ALLOW_UNSUPPORTED:-0}" = "1" ]; then
        log "Skipping host compatibility checks (MOONOS_ALLOW_UNSUPPORTED=1)"
        return
    fi

    [ "$(uname -m)" = "aarch64" ] || die "Moon OS installs only on 64-bit arm64/aarch64 Raspberry Pi OS."
    [ -r /etc/os-release ] || die "Cannot read /etc/os-release."
    . /etc/os-release
    local is_rpi_os=0
    case "${ID:-}:${ID_LIKE:-}:${PRETTY_NAME:-}" in
        *raspbian*|*Raspberry\ Pi\ OS*|debian:*raspbian*) is_rpi_os=1 ;;
    esac
    [ -r /etc/rpi-issue ] && is_rpi_os=1
    if [ -r /proc/device-tree/model ] &&
       ! tr -d '\0' < /proc/device-tree/model | grep -qi 'Raspberry Pi'; then
        die "This machine does not look like a Raspberry Pi."
    fi
    if [ "$is_rpi_os" != "1" ] &&
       ! grep -Rqs 'archive\.raspberrypi\.com\|raspbian\.raspberrypi\.com' \
            /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        die "This does not look like Raspberry Pi OS. Install Raspberry Pi OS Lite 64-bit first."
    fi
}

first_available_package() {
    local pkg
    for pkg in "$@"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            printf '%s\n' "$pkg"
            return 0
        fi
    done
    return 1
}

install_dependencies() {
    log "Installing runtime and build dependencies"
    export DEBIAN_FRONTEND=noninteractive
    run apt-get update

    local avcodec avformat swscale libcec qt_svg_dev
    avcodec="$(first_available_package libavcodec61 libavcodec60 libavcodec59 || true)"
    avformat="$(first_available_package libavformat61 libavformat60 libavformat59 || true)"
    swscale="$(first_available_package libswscale8 libswscale7 libswscale6 || true)"
    libcec="$(first_available_package libcec7 libcec6 || true)"
    qt_svg_dev="$(first_available_package libqt6svg6-dev qt6-svg-dev || true)"

    local packages=(
        ca-certificates curl git rsync file make g++ pkg-config \
        network-manager bluez polkitd plymouth plymouth-label \
        libqt6svg6 qt6-qpa-plugins \
        qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-templates \
        qml6-module-qtquick-layouts qml6-module-qtquick-window qml6-module-qtqml \
        qml6-module-qtqml-models qml6-module-qtqml-workerscript \
        libsdl2-2.0-0 libsdl2-ttf-2.0-0 libopus0 \
        libva2 libva-drm2 libva-wayland2 libva-x11-2 libvdpau1 \
        libdrm2 libegl1 libgles2 libgbm1 libinput10 libxkbcommon0 cec-utils \
        fontconfig fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji \
        alsa-utils rfkill \
        build-essential qt6-base-dev qt6-declarative-dev qt6-base-dev-tools \
        libgl1-mesa-dev libegl1-mesa-dev libopus-dev libsdl2-dev libsdl2-ttf-dev \
        libssl-dev libavcodec-dev libavformat-dev libswscale-dev libva-dev \
        libvdpau-dev libdrm-dev libxkbcommon-dev wayland-protocols libcec-dev
    )
    [ -n "$avcodec" ] && packages+=("$avcodec")
    [ -n "$avformat" ] && packages+=("$avformat")
    [ -n "$swscale" ] && packages+=("$swscale")
    [ -n "$libcec" ] && packages+=("$libcec")
    [ -n "$qt_svg_dev" ] && packages+=("$qt_svg_dev")

    run apt-get install -y --no-install-recommends "${packages[@]}"
}

ensure_moon_user() {
    log "Ensuring moon service user"
    if ! id moon >/dev/null 2>&1; then
        run useradd --create-home --home-dir /home/moon --shell /usr/sbin/nologin \
            --groups adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,render,bluetooth,netdev,gpio,i2c,spi \
            moon
        run mkdir -p "$STATE_DIR"
        run touch "$STATE_DIR/.created-moon-user"
    else
        run usermod -aG adm,dialout,cdrom,sudo,audio,video,plugdev,games,users,input,render,bluetooth,netdev,gpio,i2c,spi moon
    fi
}

build_shell() {
    if [ "$NO_BUILD" = "1" ]; then
        log "Skipping build (--no-build)"
        return
    fi
    log "Building Moon Shell"
    run env JOBS="$JOBS" SKIP_DEPS=1 bash "$REPO_ROOT/scripts/build-shell.sh"
}

install_files() {
    log "Installing Moon OS files"
    [ -d "$OVERLAY" ] || die "Missing install overlay: $OVERLAY"

    run mkdir -p "$STATE_DIR" /etc/moonos
    run chown moon:moon "$STATE_DIR"
    run chmod 755 "$STATE_DIR"
    run chown root:moon /etc/moonos
    run chmod 775 /etc/moonos

    local saved_update_conf=""
    if [ "$DRY_RUN" != "1" ] && [ -f /etc/moonos/update.conf ]; then
        saved_update_conf="$(mktemp)"
        cp -f /etc/moonos/update.conf "$saved_update_conf"
    fi

    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run] cp -a %s/. /\n' "$OVERLAY"
    else
        cp -a "$OVERLAY"/. /
        if [ -n "$saved_update_conf" ]; then
            cp -f "$saved_update_conf" /etc/moonos/update.conf
            rm -f "$saved_update_conf"
        fi
    fi

    run chmod +x /usr/lib/moonos/*.sh
    run install -m 755 "$REPO_ROOT/uninstall.sh" /usr/lib/moonos/uninstall.sh

    local built="$REPO_ROOT/third_party/moonlight-qt/build/app/moon-shell"
    if [ "$NO_BUILD" = "1" ] && [ ! -x "$built" ] && command -v moon-shell >/dev/null 2>&1; then
        built="$(command -v moon-shell)"
    fi
    [ "$DRY_RUN" = "1" ] || [ -x "$built" ] || die "Moon Shell binary not found at $built"
    run install -m 755 "$built" /usr/bin/moon-shell

    local version
    version="$(git -C "$REPO_ROOT" describe --tags --always --dirty 2>/dev/null || date +%Y.%m.%d)"
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run] write /etc/moonos/version and %s\n' "$INSTALL_CONF"
    else
        printf '%s\n' "$version" > /etc/moonos/version
        cat > "$INSTALL_CONF" <<EOF
MOONOS_REPO_DIR="$REPO_ROOT"
MOONOS_INSTALLED_VERSION="$version"
MOONOS_INSTALL_MODEL="git"
EOF
    fi
}

cleanup_legacy() {
    log "Cleaning legacy image/update leftovers"
    if [ -f /etc/moonos/eglfs-kms.json ] && [ ! -f "$STATE_DIR/eglfs-kms.json" ]; then
        run mv /etc/moonos/eglfs-kms.json "$STATE_DIR/eglfs-kms.json"
        run chown moon:moon "$STATE_DIR/eglfs-kms.json"
    else
        run rm -f /etc/moonos/eglfs-kms.json
    fi
    run rm -f /usr/lib/moonos/update-release.sh /etc/systemd/system/moon-shell-update.service
    run systemctl daemon-reload
}

enable_services() {
    log "Enabling Moon OS services"
    run systemctl enable NetworkManager bluetooth
    run systemctl disable getty@tty1.service
    run systemctl enable moon-firstboot.service moon-factory-reset.service moon-shell.service
    run systemctl daemon-reload
    if [ "$NO_RESTART" != "1" ] && [ "$FROM_UPDATE" != "1" ]; then
        run systemctl restart moon-shell.service
    elif [ "$FROM_UPDATE" = "1" ]; then
        run systemctl try-restart moon-shell.service
    fi
}

check_host
install_dependencies
ensure_moon_user
build_shell
install_files
cleanup_legacy
enable_services

cat <<'EOF'

Moon OS is installed.

Next steps:
  - Reboot, or run: sudo systemctl restart moon-shell
  - Moon Shell will take over tty1.
  - To update later, use Settings -> System -> Update Moon OS.
  - To remove it, use Settings -> System -> Uninstall Moon OS or run ./uninstall.sh.
EOF
