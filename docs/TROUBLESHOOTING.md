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

**`git submodule update` (or CI checkout) fails with `remote error:
upload-pack: not our ref <sha>`**
The submodule pointer references a commit that was never pushed to the
public moonlight-qt repo — almost always caused by committing *inside*
`third_party/moonlight-qt` while the fork patch was applied (see
AGENTS.md — never do this). Fix: `git -C third_party/moonlight-qt checkout -f
<public-commit>` (the commit `MOONLIGHT_REF` names in
`scripts/prepare-fork.sh`), then `git add third_party/moonlight-qt` at the
superproject level and commit the corrected pointer. `prepare-fork.sh` now
force-resets to `MOONLIGHT_REF` on every run so this shouldn't recur, but if
it does, this is the fix.

**qmake6 not found inside the chroot**
`qt6-base-dev-tools` didn't install — check the apt output in the
02-build-shell step; usually a stale package cache (`sudo rm -rf
os-image/pi-gen/work` and rebuild).

**`error while loading shared libraries: lib....so.N: cannot open shared
object file` when `moon-shell` starts (image built and flashed fine, boot
gets to the shell but it exits instantly)**
A runtime library `moon-shell` (or a Qt plugin/QML module it dlopens) needs
was stripped by the build stage's cleanup — it was only ever pulled in as a
dependency of a `-dev` package, so purging the build toolchain removed it
too. `02-build-shell/00-run.sh` scans the compiled binary and every Qt
plugin/QML `.so` for their real dependencies and `apt-mark manual`s the
owning packages *before* purging, and fails the build outright if `ldd`
still shows anything "not found" afterward — so a fresh build shouldn't hit
this. If it does anyway (a newly added dependency the scan didn't catch),
add the specific package to `00-packages` explicitly (this happened once
already with `libva-wayland2`/`libva-x11-2`, both listed there now with a
comment explaining why).

## GitHub Actions release workflow

**The release job is queued for a long time or says no matching runner is
available**
`release.yml` uses GitHub's native arm64 hosted runner label
`ubuntu-24.04-arm`, then compiles inside a `debian:bookworm` Docker
container. This avoids QEMU user-mode emulation while preserving the Pi's
Debian bookworm runtime ABI. If GitHub changes or temporarily disables that
runner label, check GitHub's hosted-runner reference and update the label
rather than reintroducing `uraimo/run-on-arch-action`.

**Apt fails while installing packages in the Debian build container**
This should now be a real Debian/package issue, not QEMU emulation. The old
workflow used `uraimo/run-on-arch-action`, and failed once during
`python3`'s post-install script under emulation before compilation even
started. The current native-arm runner path should not need
`docker/setup-qemu-action`, binfmt registration, or a `base_image:` workaround.

**`qmake6` fails with `toolchain.prf:76: Variable QMAKE_CXX.COMPILER_MACROS
is not defined` / `Project ERROR: failed to parse default search paths from
compiler output`**
qmake runs the compiler to auto-detect its default include/library search
paths, then parses the plain-English diagnostic text; a non-C locale (or
colorized/reformatted gcc output) can break that parser. `release.yml`
exports `LC_ALL=C LANG=C TERM=dumb GCC_COLORS=` right before `qmake6` and
prints `g++ --version` / `g++ -dumpmachine` / a macro-probe sample first, so
if this recurs the log shows exactly what qmake's probe actually saw instead
of just the bare parse failure. Notably, the identical `qmake6
../moonlight-qt.pro` call succeeds fine inside the pi-gen chroot that
`os-image/build.sh` uses — so if this keeps failing only in the release
container, the difference is something about that container setup, not the
moonlight-qt source.

**`make: *** No targets specified and no makefile found. Stop.` right after
`qmake6` succeeds**
moonlight-qt sets `CONFIG += debug_and_release`, and on some qmake/container
combinations this produces `Makefile.Release` instead of a generic
`Makefile`. `release.yml` prints the generated makefiles and builds either
`make release` or `make -f Makefile.Release`, then finds the produced
`moon-shell` binary under `app/`.

**Job runs out of disk space or gets silently killed mid-`make`**
GitHub-hosted runners have ~14GB free by default; Qt/FFmpeg dev headers plus
the container image can exceed that, and a wide `make -j$(nproc)` can get
OOM-killed with no compiler error at all. `release.yml` frees disk space
first (removes unused preinstalled toolchains) and caps the build at
`make -j2` — if it still runs out, lower this further or split the job.

## Boot

**First thing to check for ANY boot problem: the log on the boot partition.**
`moon-shell.service` mirrors its startup output to
`/boot/firmware/moon-shell.log` (and recovery mode to `moon-recovery.log`) —
that's the small FAT partition ("bootfs") that shows up as a normal drive
when the SD card is put in a Windows or Mac computer, no ext4 tools needed.
It includes a header (running user/groups, whether `/dev/dri/card0` is
writable, the Qt platform) plus the exact error if the shell crashed. This is
how the "missing shared library" and "dead input" issues below were actually
diagnosed on real hardware — read it before guessing.

**Rainbow screen / no splash**
Normal for ~2 s. If it never leaves: re-flash — the image is likely corrupt
(verify the SD card).

**Splash, then a black screen (with or without an HDMI "no signal" message)**
Check `moon-shell.log` on the boot partition first (see above) — it will say
exactly why. Two real causes seen so far on this project:
- **Black screen, HDMI still has signal**: `moon-shell` crashed on launch.
  The log's last line names it — most often a missing shared library
  (`error while loading shared libraries: ...`, see "Image build" above,
  now guarded against at build time) or, before that, a QML load error.
  After 4 crashes in 90 s, the **Recovery screen** should take over
  automatically; if even that fails, `moon-emergency.service` prints a
  plain-text banner to the screen instead of staying black — you should
  never see a truly blank, unexplained screen.
- **TV reports "no signal"**: EGLFS couldn't set a display mode. Make sure
  the HDMI cable was connected *at power-on* (KMS probes at boot) and, on
  Pi 4, use the HDMI0 port (nearest the USB-C power). `moon-shell.service`
  runs `plymouth quit` (not `--retain-splash`) specifically because
  retaining the splash framebuffer was found to block EGLFS from claiming
  the display on some HDMI sinks.

**Splash forever, shell never appears (no crash, just stuck)**
SSH in (if devmode was on) or read `moon-shell.log` off the boot partition.

**Text console flashes during boot**
Cosmetic; verify `quiet splash` survived in `/boot/firmware/cmdline.txt`
and that `plymouth-set-default-theme` says `moonos`
(then `sudo update-initramfs -u`).

## Icons showing as empty boxes ("tofu")

Fixed by installing `fontconfig` + `fonts-dejavu-core` + `fonts-noto-core` +
`fonts-noto-color-emoji` and a fallback rule in `/etc/fonts/local.conf` (see
docs/ARCHITECTURE.md, "Display pipeline"). If you still see boxes after a
rebuild that includes this, check `fc-list | grep -i noto` over SSH to
confirm the fonts actually installed, and `fc-match sans-serif` to see what
fontconfig resolved to.

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

**Controller does nothing anywhere in the shell (not even Home), but pairs
fine in Bluetooth settings / shows as connected**
The shell's gamepad-to-navigation bridge only polls while the window reports
focus; `MoonRoot.qml` asserts this at startup
(`SdlGamepadKeyNavigation.notifyWindowFocus(true)`) so this shouldn't happen
on a current build, but if it recurs after a fork/upstream change, check
that call is still present — see docs/ARCHITECTURE.md, "Input & navigation
architecture".

**Can't navigate Up out of a Wi-Fi/Bluetooth device list back to the
Wi-Fi/Bluetooth toggle**
Fixed — those toggles used to live in a `ListView` header, which arrow-key
navigation can't reach. They're now separate focusable buttons above the
list with an explicit bridge. If a new settings screen reintroduces
interactive controls inside a `header:`, expect the same trap.

**USB/Bluetooth keyboard doesn't type into text fields**
Should work directly — the on-screen keyboard and `TextEntryDialog` both
route real keystrokes (anything with `event.text` set) straight into the
field, no on-screen keyboard interaction needed. If typing does nothing,
check `moon-shell.log`/journal for Qt input-related warnings; this usually
means the keyboard isn't showing up as an evdev device Qt can see
(try a different USB port, or `evtest` over SSH in developer mode to confirm
the kernel sees key events at all).

**No mouse cursor visible**
The cursor is only ever drawn when Qt EGLFS detects an actual pointer
device — nothing to configure. If a mouse is attached and still no cursor
appears, check developer mode logs for `libinput`/evdev errors; this project
does not set `QT_QPA_EGLFS_HIDECURSOR`, so a missing cursor with a mouse
attached is unexpected, not a documented default.

## Updates

**Update doesn't seem to do anything for Moon Shell (OS packages upgrade
fine)**
Shell self-updates are off until `MOONOS_UPDATE_REPO` in
`/etc/moonos/update.conf` names a real repo publishing releases (see
README.md → "Updates"). Check the value, then check
`/var/lib/moonos/update.log` (developer mode → View logs, or SSH) for the
"Checking for a Moon Shell update" section — it prints the installed vs.
available version and exactly why it did or didn't install.

**Update reports "Checksum mismatch — refusing to install"**
The downloaded binary didn't match its published `.sha256`. This is a safety
refusal, not a bug to work around — re-run the release workflow/script so
the checksum file matches the binary actually being served, and update
again.

**A freshly flashed image never "sees" an update even though a release
exists**
Consoles only update to a *higher* version than what's installed
(`/etc/moonos/version`), compared as a plain string sort. If the image's
baked-in version happens to already equal or exceed the release's version
(e.g. you flashed a build newer than the last published release), publish a
later-dated release to test the path.

## Escape hatches

- **`moon-shell.log` / `moon-recovery.log`** on the boot (FAT) partition —
  readable from Windows/Mac/Linux with nothing special, no SSH or ext4 tools
  needed. Always check this first.
- **Recovery screen**: automatic after repeated crashes.
- **Emergency console**: automatic if recovery *also* fails repeatedly — a
  plain-text Moon OS banner plus a root login prompt on the TV itself,
  guaranteed not to depend on Qt/QML working.
- **SSH (devmode)**: full system access, `sudo` enabled.
- **SD card surgery**: the rootfs is plain ext4 — mount it on any Linux PC
  (or via WSL on Windows: `wsl --mount \\.\PHYSICALDRIVEN --partition 2 --type ext4`)
  and delete `/etc/moonos/eglfs-kms.json` (display), `/var/lib/moonos`
  (settings) or touch `/var/lib/moonos/.factory-reset` (full reset).
