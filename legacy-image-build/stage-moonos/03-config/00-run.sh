#!/bin/bash -e
# Boot-to-Moon-Shell wiring: firmware config, quiet boot + splash, service
# enablement, and console cleanup.

# ---- firmware config (Pi 4 + Pi 5, single image) ---------------------------
cat >> "${ROOTFS_DIR}/boot/firmware/config.txt" << 'EOF'

# ---- Moon OS ----
# Full KMS graphics (required for Qt EGLFS and V4L2 hardware decode)
dtoverlay=vc4-kms-v3d
max_framebuffers=2
# Hide the rainbow splash; plymouth shows the Moon OS splash instead
disable_splash=1
# Let KMS handle scaling; the shell has its own safe-area control
disable_overscan=1

[pi4]
# Allow 4K60 output on Pi 4 (HDMI0)
hdmi_enable_4kp60=1

[all]
EOF

# ---- quiet boot + splash ----------------------------------------------------
CMDLINE="${ROOTFS_DIR}/boot/firmware/cmdline.txt"
sed -i 's/console=tty1/console=tty3/' "$CMDLINE"
sed -i '1 s/$/ quiet splash loglevel=3 logo.nologo vt.global_cursor_default=0 plymouth.ignore-serial-consoles/' "$CMDLINE"

on_chroot << 'CHROOT'
set -e

# Moon OS plymouth theme
plymouth-set-default-theme moonos || true

# Boot straight into the shell; no login prompt on the console
systemctl disable getty@tty1.service
systemctl enable moon-firstboot.service
systemctl enable moon-factory-reset.service
systemctl enable moon-shell.service
systemctl enable NetworkManager
systemctl enable bluetooth

# SSH stays off unless developer mode turns it on
systemctl disable ssh || true

# Wi-Fi regulatory domain so the radio is not rfkill-blocked on first boot.
# (Default US — change from developer mode / roadmap: wizard region step.)
raspi-config nonint do_wifi_country US || true

# Persistent, size-capped journal so a failed boot is still readable after a
# power-cycle (mount the SD's rootfs and run: journalctl -D <root>/var/log/journal).
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\nSystemMaxUse=64M\n' > /etc/systemd/journald.conf.d/moonos.conf
mkdir -p /var/log/journal

# Emergency fallback console (last resort if the UI cannot render at all).
# Not "enabled" — it is pulled in only via OnFailure= from moon-recovery.
systemctl disable moon-emergency.service 2>/dev/null || true
CHROOT

# Rebuild the initramfs so the plymouth theme is available at early boot
on_chroot << 'CHROOT'
update-initramfs -u || true
CHROOT
