#!/bin/bash
# Factory reset, staged from the UI (MoonSystem.factoryReset touches the
# flag and reboots; this runs early on the next boot, before moon-shell).
set -e

STATE_DIR=/var/lib/moonos

rm -f "$STATE_DIR/.factory-reset"

# Moon OS state (settings, recent games, devmode flag, status files)
find "$STATE_DIR" -mindepth 1 -delete

# moonlight-qt state: paired hosts, client certificate, stream prefs
rm -rf /home/moon/.config /home/moon/.cache

# Network + Bluetooth pairings
rm -f /etc/NetworkManager/system-connections/*
rm -rf /var/lib/bluetooth/*

# Display/audio overrides
rm -f /etc/moonos/eglfs-kms.json
rm -f "$STATE_DIR/eglfs-kms.json"

# SSH back off; host keys regenerate on next devmode enable
systemctl disable --now ssh 2>/dev/null || true
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

chown moon:moon "$STATE_DIR"
touch "$STATE_DIR/.provisioned"
