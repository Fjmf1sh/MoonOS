# Moon OS

A dedicated game-streaming console OS for Raspberry Pi 4 and 5. Flash one
image, plug the Pi into your TV, and it boots straight into **Moon Shell** —
a controller-first, Big-Picture-style interface built around a real fork of
[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt). Pair it
with a PC running [Sunshine](https://github.com/LizardByte/Sunshine) and
play your library from the couch.

No desktop. No terminal. No Linux showing through.

```
power on → Moon OS splash → Moon Shell → pick a game → play
```

## What's inside

| Piece | What it is |
|---|---|
| **Moon Shell** | Fullscreen Qt 6/QML 10-foot UI (home, library, pairing, wizard, settings) |
| **Moon Core** | The moonlight-qt fork: native pairing, mDNS discovery, app listing, hardware-decoded streaming |
| **Moon services** | Native D-Bus clients for NetworkManager (Wi-Fi), BlueZ (controllers), logind/systemd (power, updates), plus libcec (TV remote) |
| **Moon OS image** | pi-gen–built Raspberry Pi OS Lite (bookworm, arm64) that boots straight into the shell |

### Why these technical choices

- **Fork of Moonlight Qt, not a CLI wrapper.** Moon Shell links the actual
  moonlight-qt backend (`ComputerManager`, `NvPairingManager`, `Session`,
  mDNS discovery, the FFmpeg/V4L2/DRM video path). The fork surface is a
  17-line patch ([moon-shell/fork/0001-moon-os-fork.patch](moon-shell/fork/0001-moon-os-fork.patch))
  plus a self-contained `app/moon/` directory — trivial to rebase when
  upstream moves. Nothing shells out to `moonlight pair/stream/list`.
- **Qt 6 QML on EGLFS/KMS.** moonlight-qt is already a Qt app with first-class
  embedded support: it auto-detects the bare console, drives the display via
  KMS without any X11/Wayland, and hands the DRM master to SDL for the
  low-latency stream path. Reusing that means the hardest embedded problems
  (hardware decode, display handoff, gamepad input) use upstream's
  battle-tested code.
- **pi-gen + Raspberry Pi OS Lite (arm64) as the base.** pi-gen is the tool
  that builds official Raspberry Pi OS images: it produces
  Pi-Imager-compatible `.img` files, supports Pi 4 and Pi 5 from a single
  image, and gives us Debian's maintained Qt/FFmpeg/V4L2 stack. Buildroot or
  Yocto would produce smaller images at a much higher maintenance cost —
  wrong trade-off for this project.

## Building the image

### Build machine requirements

- Debian 12 / Ubuntu 22.04+ (x86_64 is fine — the build uses an arm64 chroot),
  or any Linux with Docker for the containerized path
- ~20 GB free disk, 30–90 min (Qt compiles inside an emulated chroot)
- Packages (native path):
  ```bash
  sudo apt install coreutils quilt parted qemu-user-static debootstrap zerofree \
      zip dosfstools libarchive-tools libcap2-bin grep rsync xz-utils file git \
      curl bc gpg pigz xxd arch-test binfmt-support
  ```

### Build

```bash
git clone --recurse-submodules <this-repo> moon-os
cd moon-os
sudo os-image/build.sh            # or: sudo os-image/build.sh --docker
```

Output: **`deploy/moon-os-rpi4-rpi5.img`**

The script: prepares the moonlight-qt fork (`scripts/prepare-fork.sh`),
clones pi-gen (arm64 branch), injects the `stage-moonos` stage, and builds.
The shell compiles inside the arm64 chroot against Raspberry Pi OS's own
Qt 6 — the binary always matches the image's libraries.

### Flash with Raspberry Pi Imager

1. Open Raspberry Pi Imager → **Choose OS → Use custom** → select
   `moon-os-rpi4-rpi5.img`.
2. Choose your SD card (16 GB+ recommended) → **Write**.
   Skip Imager's OS customization screen — Moon OS has its own setup wizard.
3. Boot the Pi with HDMI and (ideally) Ethernet connected.

First boot shows the **Welcome to Moon OS** wizard: controller pairing,
Wi-Fi, safe area, audio output, and PC pairing.

## Pairing with Sunshine

1. On your gaming PC, install [Sunshine](https://app.lizardbyte.dev/Sunshine/)
   and finish its web setup (`https://localhost:47990`).
2. On Moon OS: **Pair PC**. PCs on the same network appear automatically
   (mDNS); otherwise use **Add PC by IP address**.
3. Moon OS shows a large 4-digit PIN. Enter it in Sunshine's web UI → **PIN**.
4. Done — the PC appears on Home, and its games/apps in the Library.

## Developer mode / SSH

Settings → System → **Developer mode**. That starts SSH (`ssh moon@moonos`,
default password `moonos` — change it immediately: `passwd`), shows a log
viewer in the UI, and appends raw error details to friendly error screens.
Turning developer mode off stops SSH again. Fresh SSH host keys are
generated per device, never baked into the image.

## Recovering from a broken config

Moon OS is designed so you never need to reflash:

- **Crash loop** → after 4 crashes in 90 s, systemd starts the **Recovery
  screen** (safe mode: no resolution override, CEC optional) with one-button
  fixes: restart, reset display settings, factory reset.
- **Blank screen after changing resolution** → power-cycle twice quickly or
  wait for the crash-loop recovery; or from SSH:
  `sudo rm /etc/moonos/eglfs-kms.json && sudo systemctl restart moon-shell`.
- **Factory reset** → Settings → System → Factory reset (also available in
  Recovery). Wipes paired PCs, networks, Bluetooth and settings at the next
  boot, then reruns the wizard.
- **Settings backup** → Settings → System → Export/Import settings to a USB
  drive (`moonos-config.tar.gz`).

## Project status & known limitations

**Status: code-complete, pre-hardware-validation.** Every feature above is
fully implemented (no stubs, no fake data), but this tree has not yet been
burned to an SD card and soak-tested on real Pi 4/5 hardware. Expect the
first image build to surface integration issues — that's what
[docs/TESTING.md](docs/TESTING.md) is for. Known limitations:

- The fork pins moonlight-qt at the submodule commit; rebasing to newer
  upstream may need a patch refresh (see docs/ARCHITECTURE.md).
- FFmpeg runtime package names in `00-packages` are bookworm-specific
  (`libavcodec59` etc.); a trixie rebase must update them.
- Wi-Fi regulatory domain defaults to US (set in the image); other regions
  need developer mode for now — a wizard region step is on the roadmap.
- Recent games are keyed by host *name* (upstream's model doesn't expose
  UUIDs to QML); renaming a PC orphans its recent-games entries.
- `Update` upgrades OS packages; shipping Moon Shell updates through it
  needs a Moon OS apt repo (roadmap).
- HDR streaming depends on upstream moonlight-qt's Pi HDR support and the
  TV; the toggle greys out when unsupported.
- No PIN/parental lock, no multiple user profiles.

## Roadmap

- Wizard language/region step (locale + Wi-Fi country)
- Moon OS apt repository for shell self-updates + A/B rollback
- Box-art caching and richer library metadata
- Wake-on-LAN button on offline host cards (backend already supports it)
- CEC standby → console sleep, and TV power-off on console shutdown
- Overclock/fan profiles for Pi 5

## Repository layout

```
moon-shell/       Moon Shell UI + services (becomes app/moon/ in the fork)
  src/            C++: D-Bus services, CEC, settings, registration
  qml/            The whole 10-foot UI
  fork/           The patch applied to moonlight-qt
third_party/
  moonlight-qt/   Upstream, pinned as a submodule (patched at build time)
os-image/         pi-gen stage, rootfs overlay, image build script
scripts/          prepare-fork.sh, build-shell.sh (on-device dev build)
docs/             ARCHITECTURE, TROUBLESHOOTING, TESTING
```

Docs: [Architecture](docs/ARCHITECTURE.md) ·
[Troubleshooting](docs/TROUBLESHOOTING.md) · [Testing checklist](docs/TESTING.md)

## License

Moon OS inherits GPLv3 from moonlight-qt. Moon OS additions are GPLv3.
