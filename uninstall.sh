#!/usr/bin/env bash
# Remove Moon OS from a Raspberry Pi OS installation.
set -euo pipefail

YES=0
DRY_RUN=0
ORIG_ARGS=("$@")

while [ $# -gt 0 ]; do
    case "$1" in
        --yes) YES=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '1,80p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

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

if [ "$YES" != "1" ]; then
    printf 'This will stop Moon OS, remove its system files, and restore the normal tty1 login.\n'
    printf 'Type "uninstall moonos" to continue: '
    read -r answer
    [ "$answer" = "uninstall moonos" ] || { echo "Aborted."; exit 1; }
fi

echo "==> Stopping Moon OS services"
run systemctl disable --now moon-shell.service moon-recovery.service moon-emergency.service \
    moon-update.service moon-firstboot.service moon-factory-reset.service \
    moon-devmode-on.service moon-devmode-off.service moon-config-export.service \
    moon-config-import.service 2>/dev/null || true
run systemctl disable moon-uninstall.service 2>/dev/null || true

echo "==> Restoring tty1 login"
run systemctl enable getty@tty1.service
run systemctl restart getty@tty1.service 2>/dev/null || true

echo "==> Removing installed files"
REMOVE_MOON_USER=0
[ -f /var/lib/moonos/.created-moon-user ] && REMOVE_MOON_USER=1
run rm -f /usr/bin/moon-shell
run rm -rf /usr/lib/moonos
run rm -f /etc/systemd/system/moon-*.service
run rm -f /etc/polkit-1/rules.d/50-moonos.rules
run rm -rf /etc/moonos
run rm -rf /var/lib/moonos
run rm -f /boot/firmware/moon-shell.log /boot/firmware/moon-recovery.log 2>/dev/null || true
run systemctl daemon-reload

if [ "$REMOVE_MOON_USER" = "1" ] && id moon >/dev/null 2>&1; then
    echo "==> Removing moon service user"
    run userdel -r moon 2>/dev/null || true
fi

cat <<'EOF'

Moon OS has been uninstalled.
The normal Raspberry Pi OS tty1 login has been restored.
Reboot when convenient: sudo reboot
EOF
