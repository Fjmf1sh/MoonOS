#!/bin/bash -e
# Build moon-shell (the moonlight-qt fork) inside the arm64 chroot and
# install it to /usr/bin/moon-shell. Build-only packages are purged
# afterwards, but every runtime shared library the shell needs is pinned
# first (see the "pin runtime libraries" step) so the cleanup can never
# strip it — this is what previously dropped libva-wayland2 and left the
# binary unable to start.

install -d "${ROOTFS_DIR}/opt/src"
tar -C "${ROOTFS_DIR}/opt/src" -xzf "$(dirname "$0")/files/moonlight-src.tar.gz"

on_chroot << 'CHROOT'
set -e

export DEBIAN_FRONTEND=noninteractive

BUILD_DEPS="build-essential pkg-config qt6-base-dev qt6-declarative-dev \
    qt6-base-dev-tools libqt6svg6-dev libgl1-mesa-dev libegl1-mesa-dev \
    libopus-dev libsdl2-dev libsdl2-ttf-dev libssl-dev \
    libavcodec-dev libavformat-dev libswscale-dev \
    libva-dev libvdpau-dev libdrm-dev libxkbcommon-dev wayland-protocols \
    libcec-dev"

apt-get update
apt-get install -y --no-install-recommends $BUILD_DEPS

cd /opt/src/moonlight-qt
mkdir -p build
cd build
qmake6 ../moonlight-qt.pro
make -j"$(nproc)"

install -m 755 app/moon-shell /usr/bin/moon-shell

# Stamp a real version in the SAME scheme the release workflow uses
# (YYYY.MM.DD.N), so the updater can order the installed build against GitHub
# releases with `sort -V`. Shipping the literal "development" placeholder made
# every release look older, so consoles never updated. Honour MOONOS_VERSION if
# a coordinated build passes one in.
if [ -n "${MOONOS_VERSION:-}" ]; then
    echo "${MOONOS_VERSION}" > /etc/moonos/version
else
    echo "$(date +%Y.%m.%d).0" > /etc/moonos/version
fi
echo "moon-shell version: $(cat /etc/moonos/version)"

# SDL controller mappings shipped with moonlight-qt (community database)
install -d /usr/share/moonos
install -m 644 /opt/src/moonlight-qt/app/SDL_GameControllerDB/gamecontrollerdb.txt \
    /usr/share/moonos/gamecontrollerdb.txt || true

# ---- Material Icons font ---------------------------------------------------
# The shell renders all UI glyphs from the Google "Material Icons" font (via
# MIcon.qml ligatures) instead of emoji. Install it system-wide so fontconfig
# resolves the "Material Icons" family; if the download fails the build still
# succeeds (icons just fall back to tofu) rather than blocking the whole image.
install -d /usr/share/fonts/truetype/material-icons
if curl -fsSL --retry 3 \
    -o /usr/share/fonts/truetype/material-icons/MaterialIcons-Regular.ttf \
    "https://github.com/google/material-design-icons/raw/master/font/MaterialIcons-Regular.ttf"; then
    fc-cache -f /usr/share/fonts/truetype/material-icons || true
else
    echo "WARN: could not fetch Material Icons font; UI icons may be missing" >&2
fi

# ---- pin runtime libraries -------------------------------------------------
# ld.so needs every NEEDED library of moon-shell AND of the Qt plugins/QML
# modules it dlopens at runtime (eglfs platform plugin, image formats, the
# QtQuick/Controls .so files). `ldd` on the binary alone misses the
# dlopened ones, so scan them all, resolve libraries -> owning packages,
# and mark those packages manual so `apt-get autoremove` keeps them.
QT_PLUGINS="$(qmake6 -query QT_INSTALL_PLUGINS)"
QT_QML="$(qmake6 -query QT_INSTALL_QML)"

{
    echo /usr/bin/moon-shell
    find "$QT_PLUGINS" "$QT_QML" -name '*.so' 2>/dev/null
} | while read -r sofile; do
    ldd "$sofile" 2>/dev/null || true
done \
    | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^\//) print $i }' \
    | sort -u \
    | xargs -r dpkg -S 2>/dev/null \
    | cut -d: -f1 \
    | tr ',' '\n' \
    | sort -u \
    | xargs -r apt-mark manual

cd /
rm -rf /opt/src/moonlight-qt

# Now it is safe to purge the build toolchain and let autoremove reclaim the
# orphaned -dev packages: everything the runtime actually loads is pinned.
apt-get purge -y $BUILD_DEPS
apt-get autoremove --purge -y
apt-get clean
rm -rf /var/lib/apt/lists/*

# Fail the build loudly if the shell still has an unresolved library, rather
# than shipping another image that dies at ld.so on the Pi.
if ldd /usr/bin/moon-shell | grep -q 'not found'; then
    echo "ERROR: moon-shell has unresolved libraries after cleanup:" >&2
    ldd /usr/bin/moon-shell | grep 'not found' >&2
    exit 1
fi
CHROOT

# Export the freshly compiled binary as an update artifact alongside the image
# in pi-gen's deploy dir, so scripts/release.sh can publish it directly — no
# need to crack open the .img afterwards. Named at the top level (not a subdir)
# so pi-gen's docker export reliably carries it back to the host.
if [ -n "${DEPLOY_DIR:-}" ] && [ -f "${ROOTFS_DIR}/usr/bin/moon-shell" ]; then
    mkdir -p "${DEPLOY_DIR}"
    cp "${ROOTFS_DIR}/usr/bin/moon-shell" "${DEPLOY_DIR}/moon-shell-arm64"
    cp "${ROOTFS_DIR}/etc/moonos/version" "${DEPLOY_DIR}/moon-shell-version" 2>/dev/null \
        || echo "0.0.0" > "${DEPLOY_DIR}/moon-shell-version"
    ( cd "${DEPLOY_DIR}" && sha256sum moon-shell-arm64 > moon-shell-arm64.sha256 )
    echo "==> Exported update artifact: ${DEPLOY_DIR}/moon-shell-arm64"
fi
