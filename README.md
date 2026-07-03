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

### Input & feel

Every screen works with a **controller**, a **keyboard**, a **mouse**, or a
**TV remote (HDMI-CEC)** — pick whichever is plugged in, or mix them:

- **Controller** — D-pad/stick for spatial navigation (A select, B back,
  X context actions), reused straight from moonlight-qt's own SDL gamepad
  bridge.
- **Keyboard** — arrow keys + Enter/Escape navigate the shell; typing into
  any text field (Wi-Fi password, IP address, search) works directly, no
  on-screen keyboard required.
- **Mouse** — hovering a card gives it focus (Big-Picture style), clicking
  activates it, right-click on a PC card opens its options, and sliders are
  click/drag. The pointer is never hidden, so it shows up the moment a mouse
  is attached.
- **On-screen keyboard** — appears automatically for every text field so a
  physical keyboard is never required; drivable by controller, remote, mouse,
  *or* a physical keyboard typing directly into it. Passwords mask by default
  with a reveal toggle; clipboard paste is available only in developer mode.
- **Background** — a twinkling starfield with occasional shooting stars, and
  a moon that drifts to a new position each time you move to a different
  screen.

### Why these technical choices

- **Fork of Moonlight Qt, not a CLI wrapper.** Moon Shell links the actual
  moonlight-qt backend (`ComputerManager`, `NvPairingManager`, `Session`,
  mDNS discovery, the FFmpeg/V4L2/DRM video path). The fork surface is a
  small patch ([moon-shell/fork/0001-moon-os-fork.patch](moon-shell/fork/0001-moon-os-fork.patch))
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

## Updates

System settings → **Update** runs [update.sh](os-image/overlay/usr/lib/moonos/update.sh),
which does two things:

1. **Base OS packages** (`apt full-upgrade`) — works out of the box, needs
   only a network connection.
2. **Moon Shell itself** — off until you point it at a release channel, because
   the shell is a compiled binary, not an apt package.

Moon Shell self-updates are already pointed at `Fjmf1sh/MoonOS` in
[`update.conf`](os-image/overlay/etc/moonos/update.conf).

### Publishing an update from the GitHub website (recommended, nothing to run locally)

A GitHub Actions workflow builds and publishes the update entirely in the cloud
— ideal if you're on Windows and don't run shell scripts. It fires three ways:

- **Automatically** whenever changes under `moon-shell/` (or the fork) land on
  `main` — updates publish themselves. Add `[skip ci]` to a commit message to
  suppress a release for that push.
- **Manually** from the **Actions tab → "Release Moon OS update" → Run
  workflow** (optionally type a version), or
- by pushing a git tag like `v2026.07.10`.

Auto-published versions are `YYYY.MM.DD.<run-number>`, so several releases in a
day still register as newer on consoles.

It compiles just the aarch64 `moon-shell` binary in a Debian-bookworm arm64
container (matching the Pi's runtime), checksums it, and creates/updates the
matching **Release** with `version`, `moon-shell-arm64`, and
`moon-shell-arm64.sha256`. No local tools, no `gh` login — Actions uses the
repo's built-in token. Workflow: [.github/workflows/release.yml](.github/workflows/release.yml).

### Publishing from a command line (alternative)

If you'd rather do it locally (Linux/WSL/git-bash with the GitHub CLI):

```bash
scripts/release.sh --build   # build + publish, or drop --build to publish an existing build
```

`release.sh` grabs the compiled binary the build exported to `deploy/update/`,
regenerates its SHA-256, and creates/updates the GitHub Release. `--dry-run`
previews without publishing.

Consoles then compare their `/etc/moonos/version` against the release's
`version`, download + checksum-verify the new binary, install it, and apply it
on the next restart (offered from System settings). Everything is served over
HTTPS from GitHub and verified by SHA-256 before install.

> The very first flashed image can't update to its own version — publish a
> *later*-dated build to exercise the update path. Version is the build date,
> so newer builds always sort as newer.

For a fleet you don't control the release cadence of, the more robust long-term
option is a signed apt repository or A/B image updates — see the roadmap.

## Project status & known limitations

**Status: under active hardware validation on Raspberry Pi 4.** This is no
longer a paper design — it has been flashed and booted on real hardware, and
the boot chain, input stack, and font rendering have each already gone
through a real bug → fix → reflash cycle (see docs/TROUBLESHOOTING.md for the
specifics: a stripped runtime library, dead gamepad/keyboard focus, missing
icon fonts). Pi 5 and full soak testing per docs/TESTING.md are still
outstanding. Known limitations:

- The fork pins moonlight-qt at a specific public commit; rebasing to newer
  upstream needs a patch refresh (see docs/ARCHITECTURE.md, "Updating the
  fork"). Never let that commit become a private/unpushed one — see
  docs/ARCHITECTURE.md and AGENTS.md for why that broke CI once already.
- FFmpeg runtime package names in `00-packages` are bookworm-specific
  (`libavcodec59` etc.); a trixie rebase must update them.
- Wi-Fi regulatory domain defaults to US (set in the image); other regions
  need developer mode for now — a wizard region step is on the roadmap.
- Recent games are keyed by host *name* (upstream's model doesn't expose
  UUIDs to QML); renaming a PC orphans its recent-games entries.
- Moon Shell self-updates ship via GitHub Releases (see "Updates" above),
  not an apt repo — no automatic rollback if a published binary is bad; a
  signed apt repo with A/B rollback is on the roadmap for fleet-scale use.
- HDR streaming depends on upstream moonlight-qt's Pi HDR support and the
  TV; the toggle greys out when unsupported.
- No PIN/parental lock, no multiple user profiles.
- **Licensing needs a decision** — see "License" below.

## Roadmap

- Wizard language/region step (locale + Wi-Fi country)
- Signed apt repository for shell self-updates + A/B rollback (the current
  GitHub-Releases updater is one-way with no automatic revert)
- Box-art caching and richer library metadata
- Wake-on-LAN button on offline host cards (backend already supports it)
- CEC standby → console sleep, and TV power-off on console shutdown
- Overclock/fan profiles for Pi 5

## Repository layout

```
moon-shell/            Moon Shell UI + services (becomes app/moon/ in the fork)
  src/                 C++: D-Bus services, CEC, settings, registration
  qml/                 The whole 10-foot UI (screens, focus widgets, SpaceBackdrop)
  fork/                The patch applied to moonlight-qt
third_party/
  moonlight-qt/        Upstream, pinned as a submodule (patched at build time)
os-image/              pi-gen stage, rootfs overlay, image build script
  overlay/             systemd units, polkit rules, plymouth theme, /etc/moonos defaults
scripts/               prepare-fork.sh, build-shell.sh, release.sh, package-update.sh
.github/workflows/     release.yml — cloud build + publish of Moon Shell updates
docs/                  ARCHITECTURE, TROUBLESHOOTING, TESTING
AGENTS.md              Instructions for AI coding agents working in this repo
```

Docs: [Architecture](docs/ARCHITECTURE.md) ·
[Troubleshooting](docs/TROUBLESHOOTING.md) · [Testing checklist](docs/TESTING.md) ·
[AGENTS.md](AGENTS.md) (for AI coding agents)

## License

**This needs a decision — the repo currently has two licenses that don't
agree, and it should be resolved before this image is distributed to anyone
else:**

- The root [`LICENSE`](LICENSE) file is **MIT**.
- `third_party/moonlight-qt/LICENSE` (upstream) is **GPLv3**.

Moon Shell is not a separate program that happens to call moonlight-qt — the
Moon OS fork patch compiles Moon Shell's own sources directly into the same
binary as moonlight-qt's, via `app/moon/moon.pri` included from moonlight-qt's
own `app.pro` (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)). That makes
the shipped `moon-shell` binary a combined/derivative work under GPLv3, which
requires the *whole* combined work to be distributed under GPLv3 (or a
GPL-compatible license) — a plain MIT license on top isn't sufficient for the
compiled binary you flash onto the Pi, even though Moon OS's own new files
could be MIT on their own.

Until this is resolved, treat the effective license of the built image as
**GPLv3** (matching moonlight-qt), and don't rely on the root `LICENSE` file
for the compiled artifact. If MIT is genuinely wanted for Moon OS's own
source files (`moon-shell/`, `os-image/`, scripts, docs), that's fine to state
separately, but the distributed binary still needs a GPLv3-compatible
license statement alongside it.
