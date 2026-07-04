#!/bin/bash
# Export/import the console configuration to/from the first FAT/exFAT/ext4
# partition found on a removable USB disk. Archive: moonos-config.tar.gz
# with three top-level dirs: state/ (var/lib/moonos), etc/ (etc/moonos),
# userconfig/ (home/moon/.config).
set -u

MODE="${1:-}"
STATUS=/var/lib/moonos/config-io-status
MNT=/run/moonos-usb
ARCHIVE_NAME=moonos-config.tar.gz

report() {
    echo "$1" > "$STATUS"
    chmod 644 "$STATUS"
}

find_usb_partition() {
    lsblk -prno NAME,TYPE,RM,FSTYPE | while read -r name type rm fstype; do
        if [ "$type" = "part" ] && [ "$rm" = "1" ] && \
           { [ "$fstype" = "vfat" ] || [ "$fstype" = "exfat" ] || [ "$fstype" = "ext4" ]; }; then
            echo "$name"
            return
        fi
    done | head -1
}

report "running"

PART="$(find_usb_partition)"
if [ -z "$PART" ]; then
    report "failed: no USB drive found"
    exit 0
fi

mkdir -p "$MNT"
if ! mount "$PART" "$MNT"; then
    report "failed: could not mount $PART"
    exit 0
fi

STAGE="$(mktemp -d)"
cleanup() {
    umount "$MNT" 2>/dev/null
    rmdir "$MNT" 2>/dev/null
    rm -rf "$STAGE"
}
trap cleanup EXIT

case "$MODE" in
export)
    mkdir -p "$STAGE/bundle"
    cp -a /var/lib/moonos       "$STAGE/bundle/state"
    cp -a /etc/moonos           "$STAGE/bundle/etc"
    cp -a /home/moon/.config    "$STAGE/bundle/userconfig" 2>/dev/null || mkdir -p "$STAGE/bundle/userconfig"
    rm -f "$STAGE/bundle/state/update.log" \
          "$STAGE/bundle/state/.provisioned" \
          "$STAGE/bundle/state/devmode"
    if tar -C "$STAGE/bundle" -czf "$MNT/$ARCHIVE_NAME" . && sync; then
        report "success: exported to $PART"
    else
        report "failed: could not write the archive"
    fi
    ;;
import)
    if [ ! -f "$MNT/$ARCHIVE_NAME" ]; then
        report "failed: $ARCHIVE_NAME not found on the drive"
        exit 0
    fi
    mkdir -p "$STAGE/bundle"
    if ! tar -xzf "$MNT/$ARCHIVE_NAME" -C "$STAGE/bundle"; then
        report "failed: the archive could not be read"
        exit 0
    fi
    [ -d "$STAGE/bundle/state" ] && cp -a "$STAGE/bundle/state/."  /var/lib/moonos/
    [ -d "$STAGE/bundle/etc" ] && cp -a "$STAGE/bundle/etc/."      /etc/moonos/
    [ -d "$STAGE/bundle/userconfig" ] && mkdir -p /home/moon/.config && \
        cp -a "$STAGE/bundle/userconfig/." /home/moon/.config/
    chown -R moon:moon /var/lib/moonos /home/moon/.config 2>/dev/null
    touch /var/lib/moonos/.provisioned
    report "success: imported from $PART"
    ;;
*)
    report "failed: unknown mode"
    ;;
esac
