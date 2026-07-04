#!/bin/bash
# One-time provisioning after install.
set -e

STATE_DIR=/var/lib/moonos

mkdir -p "$STATE_DIR"
chown moon:moon "$STATE_DIR"
chmod 755 "$STATE_DIR"

# Config staging area writable by the shell
mkdir -p /etc/moonos
chown root:moon /etc/moonos
chmod 775 /etc/moonos

# Fresh machine gets fresh SSH host keys the day developer mode first
# turns SSH on — remove any keys baked into the image.
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

touch "$STATE_DIR/.provisioned"
