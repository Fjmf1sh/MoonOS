#!/bin/bash
# Moon Shell launcher. moonlight-qt's own startup logic auto-detects the
# bare-console environment and selects Qt EGLFS + SDL KMSDRM, so we only
# provide Moon OS specifics here.
#
# stdout/stderr are captured to /boot/firmware/moon-shell.log by the service
# unit, so the header below (and any Qt/QML error) is readable on the FAT
# boot partition from any computer.
set -u

echo "===== Moon OS shell start: $(date -Is) ====="
echo "mode        : ${MOONOS_RECOVERY:+RECOVERY}${MOONOS_RECOVERY:-normal}"
echo "user        : $(id -un) ($(id -u))  groups: $(id -Gn)"
echo "qt platform : ${QT_QPA_PLATFORM:-auto (eglfs expected)}"
echo -n "dri devices : "; ls /dev/dri 2>/dev/null | tr '\n' ' '; echo
echo -n "drm master  : "; [ -w /dev/dri/card0 ] && echo "card0 writable" || echo "card0 NOT writable (session may be inactive)"
echo "moon-shell  : $(command -v moon-shell || echo MISSING)"
echo "----------------------------------------------------"

# Staged display-mode override from Settings -> Display. Recovery mode
# ignores it so a bad mode can never wedge the console.
if [ "${MOONOS_RECOVERY:-0}" != "1" ] && [ -s /etc/moonos/eglfs-kms.json ]; then
    export QT_QPA_EGLFS_KMS_CONFIG=/etc/moonos/eglfs-kms.json
    echo "using staged KMS config: $QT_QPA_EGLFS_KMS_CONFIG"
fi

exec /usr/bin/moon-shell
