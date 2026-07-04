#!/bin/bash
# Developer mode toggle: SSH on/off + the flag file the shell reads.
set -e

FLAG=/var/lib/moonos/devmode

case "${1:-}" in
on)
    # Regenerate host keys if a factory reset (or first boot) removed them
    ssh-keygen -A
    systemctl enable --now ssh
    touch "$FLAG"
    chmod 644 "$FLAG"
    ;;
off)
    systemctl disable --now ssh
    rm -f "$FLAG"
    ;;
*)
    echo "usage: devmode.sh on|off" >&2
    exit 1
    ;;
esac
