# Moon OS troubleshooting

Most problems are fixable from the TV (Recovery screen) or over SSH
(developer mode). `ssh moon@moonos`, password `moonos` unless changed.

## Image build

**pi-gen fails early with binfmt/qemu errors**
Install `qemu-user-static binfmt-support` and re-run; or use
`sudo os-image/build.sh --docker`.

**`E: Unable to locate package libavcodec59` (or similar)**
The FFmpeg runtime package names in
`os-image/stage-moonos/00-packages/00-packages` are pinned to bookworm.
Check the current names with `apt-cache search libavcodec` inside the
target release and update the list.

**`patch does not apply` from prepare-fork.sh**
The submodule moved past the pinned commit (or you bumped it). Follow
"Updating the fork" in docs/ARCHITECTURE.md.

**qmake6 not found inside the chroot**
`qt6-base-dev-tools` didn't install — check the apt output in the
02-build-shell step; usually a stale package cache (`sudo rm -rf
os-image/pi-gen/work` and rebuild).

## Boot

**Rainbow screen / no splash**
Normal for ~2 s. If it never leaves: re-flash — the image is likely corrupt
(verify the SD card).

**Splash forever, shell never appears**
SSH in (if devmode was on) or mount the SD card's rootfs on a PC and check
`journalctl -u moon-shell` / `var/log/`. Typical causes:
- `moon-shell` crashed 4× → recovery screen should appear; if even recovery
  fails, delete `etc/moonos/eglfs-kms.json` on the card.
- EGLFS could not find a display: make sure the HDMI cable was connected at
  power-on (KMS probes at boot), and on Pi 4 use the HDMI0 port (nearest
  USB-C).

**Text console flashes during boot**
Cosmetic; verify `quiet splash` survived in `/boot/firmware/cmdline.txt`
and that `plymouth-set-default-theme` says `moonos`
(then `sudo update-initramfs -u`).

## Display & audio

**Black screen after changing resolution**
Recovery screen appears after the crash-loop threshold → "Reset display
settings". Over SSH: `sudo rm /etc/moonos/eglfs-kms.json && sudo systemctl
restart moon-shell`.

**No sound in streams**
Settings → Display & sound → Sound output → pick the HDMI device
(`vc4hdmi0` is the port nearest power on Pi 4). Check the TV isn't muted;
`speaker-test -D default:CARD=vc4hdmi0` over SSH isolates OS vs stream.

**TV remote does nothing**
Enable CEC on the TV itself (every vendor renames it: Anynet+, Bravia Sync,
Simplink, …). Then Settings → Display & sound → toggle "TV remote control"
off/on. `cec-ctl --list-devices` over SSH should show `/dev/cec0`.

## Network & pairing

**PC never appears in Pair PC**
- Same subnet? mDNS doesn't cross VLANs — use "Add PC by IP address".
- Sunshine running, and its firewall allows 47984/47989 (TCP) +
  streaming ports 47998–48010 (UDP/TCP)?
- Some routers filter multicast on Wi-Fi ("IGMP snooping") — wire the Pi.

**Pairing PIN rejected**
The PIN times out after a couple of minutes; restart pairing and enter it in
Sunshine's web UI (**PIN** tab), not in a game window.

**"Your network is blocking the stream"**
The port test found blocked streaming ports. Open UDP 47998–48000 and
TCP/UDP 48010 on the PC's firewall; for internet play forward them on the
router (LAN play needs no forwarding).

**Wi-Fi joins then drops during streams**
2.4 GHz + neighbors = pain. Use 5 GHz or Ethernet; lower the bitrate in
Stream settings as a stopgap.

## Controllers

**Controller won't pair**
Put it in *pairing* mode (not just on): Xbox = hold Pair until fast blink;
DualShock/DualSense = hold PS+Share/Create; Switch Pro = hold Sync. If it
was paired to this Pi before, "Forget device" first — controllers refuse to
re-pair with a stale bond.

**Paired but no UI navigation**
The shell needs an SDL mapping for exotic gamepads. Developer mode → check
`journalctl -u moon-shell` for "Unmapped gamepad"; add a mapping line to
`/usr/share/moonos/gamecontrollerdb.txt` (community DB ships in the image).

**Works in menus, not in games**
Enable "Multiple controllers" in Stream settings; verify the PC side sees a
virtual controller (Sunshine needs its virtual gamepad driver on Windows).

## Escape hatches

- Recovery screen: automatic after repeated crashes.
- SSH (devmode): full system access, `sudo` enabled.
- SD card surgery: the rootfs is plain ext4 — mount it on any Linux PC and
  delete `/etc/moonos/eglfs-kms.json` (display), `/var/lib/moonos`
  (settings) or touch `/var/lib/moonos/.factory-reset` (full reset).
