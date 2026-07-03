#!/bin/bash
# System update, driven from System settings. Progress lands in the status
# file the shell polls; details go to /var/lib/moonos/update.log.
set -u

STATUS=/var/lib/moonos/update-status
LOG=/var/lib/moonos/update.log

report() {
    echo "$1" > "$STATUS"
    chmod 644 "$STATUS"
}

report "running"
{
    echo "=== Moon OS update $(date -Is) ==="
    export DEBIAN_FRONTEND=noninteractive
    if apt-get update && apt-get -y -o Dpkg::Options::=--force-confdef \
                                  -o Dpkg::Options::=--force-confold full-upgrade; then
        apt-get clean
        report "success"
    else
        report "failed: package installation error (see update.log)"
    fi
} >> "$LOG" 2>&1

chown moon:moon "$LOG" 2>/dev/null || true
