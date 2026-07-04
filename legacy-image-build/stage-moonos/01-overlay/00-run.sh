#!/bin/bash -e
# Copy the Moon OS rootfs overlay (systemd units, polkit rules, helper
# scripts, plymouth theme, /etc/moonos defaults) and prepare users/dirs.

rsync -a "${STAGE_DIR}/overlay/" "${ROOTFS_DIR}/"

on_chroot << 'CHROOT'
set -e

# The console user needs bluetooth (BlueZ D-Bus policy) on top of the
# default Pi groups (video, render, input, audio, netdev).
usermod -aG bluetooth moon

# Moon OS state directory, owned by the shell user
mkdir -p /var/lib/moonos
chown moon:moon /var/lib/moonos
chmod 755 /var/lib/moonos

# /etc/moonos holds shell-writable display/audio staging config
mkdir -p /etc/moonos
chown root:moon /etc/moonos
chmod 775 /etc/moonos

# Helper scripts are root-run; make sure they are executable
chmod +x /usr/lib/moonos/*.sh
CHROOT
