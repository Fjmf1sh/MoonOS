#!/bin/bash
# Moon OS update for the git/install model.
set -u

DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            echo "Usage: update.sh [--dry-run]"
            exit 0
            ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

if [ "$DRY_RUN" = "1" ]; then
    STATUS="${MOONOS_UPDATE_STATUS:-$(pwd)/.moon-update-status}"
    LOG="${MOONOS_UPDATE_LOG:-$(pwd)/.moon-update.log}"
else
    STATUS=/var/lib/moonos/update-status
    LOG=/var/lib/moonos/update.log
fi
INSTALL_CONF=/etc/moonos/install.conf
UPDATE_CONF=/etc/moonos/update.conf

run() {
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] $*"
        return 0
    fi
    "$@"
}

report() {
    mkdir -p "$(dirname "$STATUS")"
    echo "$1" > "$STATUS"
    chmod 644 "$STATUS"
}

report "running"
ok=1

{
    echo "=== Moon OS update $(date -Is) ==="

    DO_APT=1
    [ -r "$UPDATE_CONF" ] && . "$UPDATE_CONF"
    [ -r "$INSTALL_CONF" ] && . "$INSTALL_CONF"

    if [ -z "${MOONOS_REPO_DIR:-}" ]; then
        echo "No MOONOS_REPO_DIR in $INSTALL_CONF; cannot update from git."
        ok=0
    elif [ ! -d "$MOONOS_REPO_DIR/.git" ]; then
        echo "Configured repo is not a git checkout: $MOONOS_REPO_DIR"
        ok=0
    fi

    if [ "${DO_APT:-1}" = "1" ]; then
        echo "--- Upgrading OS packages ---"
        export DEBIAN_FRONTEND=noninteractive
        if run apt-get update && \
           run apt-get -y -o Dpkg::Options::=--force-confdef \
                          -o Dpkg::Options::=--force-confold full-upgrade; then
            run apt-get clean
            echo "OS packages up to date."
        else
            echo "OS package upgrade failed."
            ok=0
        fi
    fi

    if [ "$ok" = "1" ]; then
        echo "--- Updating Moon OS git checkout ---"
        cd "$MOONOS_REPO_DIR" || ok=0
        if [ "$ok" = "1" ]; then
            before="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
            branch="$(git symbolic-ref --short HEAD 2>/dev/null || true)"
            if [ -z "$branch" ]; then
                echo "Checkout is detached at $before; fetching only."
                run git fetch --all --prune || ok=0
            else
                run git fetch --all --prune && run git pull --ff-only || ok=0
            fi
            after="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
            echo "Git revision: $before -> $after"
        fi
    fi

    if [ "$ok" = "1" ]; then
        echo "--- Re-running installer ---"
        installer_args=(--from-update)
        [ "$DRY_RUN" = "1" ] && installer_args+=(--dry-run --no-build --no-restart)
        if bash "$MOONOS_REPO_DIR/install.sh" "${installer_args[@]}"; then
            echo "Installer completed."
        else
            echo "Installer failed."
            ok=0
        fi
    fi

    echo "--- Legacy cleanup audit ---"
    if [ -e /etc/moonos/eglfs-kms.json ]; then
        run mkdir -p /var/lib/moonos
        if [ ! -e /var/lib/moonos/eglfs-kms.json ]; then
            run mv /etc/moonos/eglfs-kms.json /var/lib/moonos/eglfs-kms.json
            run chown moon:moon /var/lib/moonos/eglfs-kms.json 2>/dev/null || true
            echo "Migrated legacy /etc/moonos/eglfs-kms.json."
        else
            run rm -f /etc/moonos/eglfs-kms.json
            echo "Removed duplicate legacy /etc/moonos/eglfs-kms.json."
        fi
    fi
    run rm -f /usr/lib/moonos/update-release.sh /etc/systemd/system/moon-shell-update.service

    echo "--- Service audit ---"
    run systemctl daemon-reload
    for unit in moon-shell.service moon-update.service moon-uninstall.service moon-firstboot.service moon-factory-reset.service; do
        if [ "$DRY_RUN" = "1" ] || systemctl cat "$unit" >/dev/null 2>&1; then
            echo "$unit present"
        else
            echo "$unit missing"
            ok=0
        fi
    done
    if [ "$DRY_RUN" = "1" ] || systemctl is-enabled moon-shell.service >/dev/null 2>&1; then
        echo "moon-shell.service enabled"
    else
        ok=0
    fi

    echo "=== done (ok=$ok) ==="
} >> "$LOG" 2>&1

if [ "$ok" = "1" ]; then
    report "success"
else
    report "failed: see logs (developer mode -> View logs)"
fi

run chown moon:moon "$LOG" 2>/dev/null || true
