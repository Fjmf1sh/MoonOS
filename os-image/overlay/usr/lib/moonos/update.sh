#!/bin/bash
# Moon OS system update, driven from System settings. Two phases:
#   1. Base OS package upgrade (apt).
#   2. Moon Shell self-update from a GitHub release (if a repo is configured).
#
# Progress lands in the status file the shell polls; a full transcript goes to
# /var/lib/moonos/update.log. A new shell binary takes effect on the next
# restart/reboot (offered from System settings).
set -u

STATUS=/var/lib/moonos/update-status
LOG=/var/lib/moonos/update.log
VERSION_FILE=/etc/moonos/version
CONF=/etc/moonos/update.conf

report() { echo "$1" > "$STATUS"; chmod 644 "$STATUS"; }

report "running"
ok=1
{
    echo "=== Moon OS update $(date -Is) ==="

    # Defaults, overridable by the config file.
    DO_APT=1
    MOONOS_UPDATE_REPO=""
    [ -r "$CONF" ] && . "$CONF"

    # ---- 1. OS packages -----------------------------------------------------
    if [ "${DO_APT:-1}" = "1" ]; then
        echo "--- Upgrading OS packages ---"
        export DEBIAN_FRONTEND=noninteractive
        if apt-get update && \
           apt-get -y -o Dpkg::Options::=--force-confdef \
                      -o Dpkg::Options::=--force-confold full-upgrade; then
            apt-get clean
            echo "OS packages up to date."
        else
            echo "OS package upgrade failed."
            ok=0
        fi
    fi

    # ---- 2. Moon Shell self-update -----------------------------------------
    if [ -n "${MOONOS_UPDATE_REPO:-}" ]; then
        echo "--- Checking for a Moon Shell update (${MOONOS_UPDATE_REPO}) ---"
        base="https://github.com/${MOONOS_UPDATE_REPO}/releases/latest/download"
        remote_ver="$(curl -fsSL "${base}/version" 2>/dev/null | tr -d '[:space:]')"
        local_ver="$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null)"
        echo "installed: ${local_ver:-unknown}   available: ${remote_ver:-unreachable}"

        if [ -z "$remote_ver" ]; then
            echo "Could not reach the release channel; skipping shell update."
        elif [ "$remote_ver" = "$local_ver" ]; then
            echo "Moon Shell already current."
        elif [ "$(printf '%s\n%s\n' "$local_ver" "$remote_ver" | sort -V | tail -1)" != "$remote_ver" ]; then
            echo "Installed version is newer than the channel; skipping."
        else
            tmp="$(mktemp -d)"
            if curl -fsSL -o "$tmp/moon-shell" "${base}/moon-shell-arm64" && \
               curl -fsSL -o "$tmp/moon-shell.sha256" "${base}/moon-shell-arm64.sha256"; then
                expected="$(cut -d' ' -f1 "$tmp/moon-shell.sha256")"
                actual="$(sha256sum "$tmp/moon-shell" | cut -d' ' -f1)"
                if [ -n "$expected" ] && [ "$expected" = "$actual" ]; then
                    install -m 755 "$tmp/moon-shell" /usr/bin/moon-shell
                    echo "$remote_ver" > "$VERSION_FILE"
                    echo "Updated Moon Shell to ${remote_ver} (restart to apply)."
                else
                    echo "Checksum mismatch — refusing to install (got '$actual', expected '$expected')."
                    ok=0
                fi
            else
                echo "Download failed."
                ok=0
            fi
            rm -rf "$tmp"
        fi
    else
        echo "No update repository configured; shell self-update disabled."
    fi

    echo "=== done (ok=$ok) ==="
} >> "$LOG" 2>&1

if [ "$ok" = "1" ]; then
    report "success"
else
    report "failed: see logs (developer mode → View logs)"
fi

chown moon:moon "$LOG" 2>/dev/null || true
