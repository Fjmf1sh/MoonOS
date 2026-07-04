#!/bin/bash
# Moon Shell launcher. moonlight-qt's own startup logic auto-detects the
# bare-console environment and selects Qt EGLFS + SDL KMSDRM, so we only
# provide Moon OS specifics here.
#
# stdout/stderr are captured to /boot/firmware/moon-shell.log by the service
# unit, so the header below (and any Qt/QML error) is readable on the FAT
# boot partition from any computer.
set -u

find_eglfs_card_override() {
    local saw_headless=0
    local card card_name has_display status_file connector

    for card in /dev/dri/card*; do
        [ -e "$card" ] || continue

        card_name="$(basename "$card")"
        has_display=0

        for status_file in /sys/class/drm/"${card_name}"-*/status; do
            [ -e "$status_file" ] || continue
            has_display=1
            break
        done

        if [ "$has_display" = "0" ]; then
            for connector in /sys/class/drm/"${card_name}"-*; do
                [ -e "$connector" ] || continue
                has_display=1
                break
            done
        fi

        if [ "$has_display" = "1" ]; then
            if [ "$saw_headless" = "1" ]; then
                printf '%s\n' "$card"
            fi
            return 0
        fi

        saw_headless=1
    done
}

use_auto_eglfs_card_config() {
    local card_override config_file

    [ -z "${QT_QPA_EGLFS_KMS_CONFIG:-}" ] || return 0

    card_override="$(find_eglfs_card_override)"
    [ -n "$card_override" ] || return 0

    config_file="$(mktemp "${TMPDIR:-/tmp}/moonos-eglfs-kms.XXXXXX")" || return 0
    if ! printf '{ "device": "%s" }\n' "$card_override" > "$config_file"; then
        rm -f "$config_file"
        return 0
    fi

    export QT_QPA_EGLFS_KMS_CONFIG="$config_file"
    echo "using auto KMS card config: $QT_QPA_EGLFS_KMS_CONFIG ($card_override)"
}

echo "===== Moon OS shell start: $(date -Is) ====="
if [ "${MOONOS_RECOVERY:-0}" = "1" ]; then
    echo "mode        : recovery"
else
    echo "mode        : normal"
fi
echo "user        : $(id -un) ($(id -u))  groups: $(id -Gn)"
echo "qt platform : ${QT_QPA_PLATFORM:-auto (eglfs expected)}"
echo -n "dri devices : "; ls /dev/dri 2>/dev/null | tr '\n' ' '; echo
echo -n "drm master  : "; [ -w /dev/dri/card0 ] && echo "card0 writable" || echo "card0 NOT writable (session may be inactive)"
echo "moon-shell  : $(command -v moon-shell || echo MISSING)"
echo "----------------------------------------------------"

# Staged display-mode override from Settings -> Display. The shell writes this
# into its own state dir (writable by the moon user); fall back to the legacy
# /etc path for images built before that change. Recovery mode ignores it so a
# bad mode can never wedge the console.
MOONOS_STATE_DIR="${MOONOS_STATE_DIR:-/var/lib/moonos}"
KMS_CONFIG=""
if [ -s "${MOONOS_STATE_DIR}/eglfs-kms.json" ]; then
    KMS_CONFIG="${MOONOS_STATE_DIR}/eglfs-kms.json"
elif [ -s /etc/moonos/eglfs-kms.json ]; then
    KMS_CONFIG=/etc/moonos/eglfs-kms.json
fi
if [ "${MOONOS_RECOVERY:-0}" != "1" ] && [ -n "$KMS_CONFIG" ]; then
    export QT_QPA_EGLFS_KMS_CONFIG="$KMS_CONFIG"
    echo "using staged KMS config: $QT_QPA_EGLFS_KMS_CONFIG"
fi

# moonlight-qt has its own DRM-card override for systems where /dev/dri/card0
# is headless and the real display is on a later card. Pre-create the same
# EGLFS KMS config here so Qt never has to parse moonlight-qt's temporary file
# while it is still being written.
use_auto_eglfs_card_config

exec /usr/bin/moon-shell
