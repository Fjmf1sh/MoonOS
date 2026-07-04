# Moon OS

Moon OS turns a Raspberry Pi 4 or 5 running Raspberry Pi OS Lite 64-bit into
a dedicated game-streaming console. It boots into **Moon Shell**, a fullscreen,
controller-first Qt/QML interface built on a real fork of
[Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt). Pair it with
a PC running [Sunshine](https://github.com/LizardByte/Sunshine) and stream your
games from the couch.

Moon OS is now installed on top of Raspberry Pi OS Lite. The old custom image
builder is archived under `legacy-image-build/` and is no longer the supported
distribution path.

## Quick Start

1. Flash **Raspberry Pi OS Lite 64-bit** with the official Raspberry Pi Imager.
2. Boot the Pi, log in, and install Git if needed:
   ```bash
   sudo apt update
   sudo apt install -y git
   ```
3. Clone this repository and run the installer:
   ```bash
   git clone --recurse-submodules https://github.com/Fjmf1sh/MoonOS.git moon-os
   cd moon-os
   ./install.sh
   ```
4. Reboot:
   ```bash
   sudo reboot
   ```

After reboot, Moon Shell takes over tty1 and starts the first-run setup wizard.

## What Gets Installed

| Piece | What it is |
|---|---|
| **Moon Shell** | Fullscreen Qt 6/QML 10-foot UI for home, library, pairing, setup, settings, recovery, update, and uninstall |
| **Moon Core** | The moonlight-qt fork: native pairing, mDNS discovery, app listing, hardware-decoded streaming, and input |
| **Moon services** | systemd units and helper scripts for shell startup, updates, recovery, config import/export, and factory reset |
| **System integration** | NetworkManager, BlueZ, logind/systemd, libcec, polkit rules, fonts, and EGLFS/KMS defaults |

The installer is idempotent. Re-running `./install.sh` updates the installed
files, rebuilds Moon Shell, refreshes systemd units, and cleans known legacy
paths without creating duplicate services.

## Installer

`install.sh` must be run from the repository checkout on Raspberry Pi OS Lite
64-bit. It checks the host OS and architecture, installs runtime and build
dependencies, prepares the moonlight-qt fork, builds `moon-shell`, installs the
overlay files into `/etc`, `/usr/lib`, and `/usr/share`, and enables
`moon-shell.service`.

Useful options:

```bash
./install.sh --no-build       # reinstall service/config files using an existing binary
./install.sh --no-restart     # do not restart moon-shell at the end
./install.sh --dry-run        # print actions without changing the system
```

For CI or non-Pi smoke testing only:

```bash
MOONOS_ALLOW_UNSUPPORTED=1 ./install.sh --dry-run --no-build --no-restart
```

## Updating

Settings -> System -> **Update Moon OS** runs `/usr/lib/moonos/update.sh`.
The updater now follows the clone-and-install model:

1. Optionally runs `apt full-upgrade` for Raspberry Pi OS packages.
2. Uses the installed repository path recorded in `/etc/moonos/install.conf`.
3. Runs `git fetch --all --prune` and `git pull --ff-only` when the checkout is
   on a branch.
4. Re-runs `install.sh --from-update` so new code, service files, helper
   scripts, and dependencies are actually applied.
5. Removes or migrates known leftovers from the old image/release updater path.
6. Audits the expected Moon OS systemd units and writes a readable log to
   `/var/lib/moonos/update.log`.

Set `DO_APT=0` in `/etc/moonos/update.conf` if you want Moon OS updates to skip
OS package upgrades.

## Uninstalling

Settings -> System -> **Uninstall Moon OS** shows a confirmation dialog and
starts `moon-uninstall.service`, which runs `/usr/lib/moonos/uninstall.sh --yes`.

You can also run it from the checkout:

```bash
./uninstall.sh
```

The uninstaller stops and disables Moon OS services, restores
`getty@tty1.service`, removes installed Moon OS files and systemd units, and
removes the `moon` service user only if the installer created it.

## Pairing With Sunshine

1. On your gaming PC, install [Sunshine](https://app.lizardbyte.dev/Sunshine/)
   and finish its web setup at `https://localhost:47990`.
2. In Moon Shell, choose **Pair PC**. PCs on the same network appear
   automatically with mDNS; otherwise use **Add PC by IP address**.
3. Moon Shell shows a 4-digit PIN. Enter it in Sunshine's web UI.
4. The PC appears on Home, and its games/apps appear in the Library.

## Developer Mode And Recovery

Settings -> System -> **Developer mode** enables SSH and exposes raw logs in
developer-only UI surfaces. Normal users keep friendly errors instead of raw
log excerpts.

Recovery paths:

- Repeated shell crashes start the Recovery screen.
- Recovery failure starts the emergency text banner on tty1.
- Display settings can be reset from Recovery or with:
  ```bash
  sudo rm -f /var/lib/moonos/eglfs-kms.json /etc/moonos/eglfs-kms.json
  sudo systemctl restart moon-shell
  ```
- Factory reset wipes paired PCs, networks, Bluetooth state, and Moon settings,
  then reruns the setup wizard.

## Legacy Image Builder

The old flashable image flow has been moved to `legacy-image-build/`. It is kept
as historical reference for advanced users, but it is unsupported. New installs
should use Raspberry Pi OS Lite plus `./install.sh`.

## Repository Layout

```
install/               Runtime overlay installed by install.sh
legacy-image-build/    Unsupported archived pi-gen image builder
moon-shell/            Moon Shell UI + native services
scripts/               Fork prep, shell build, smoke tests
third_party/           Upstream moonlight-qt submodule
docs/                  Architecture, troubleshooting, testing
.github/workflows/     CI smoke tests
AGENTS.md              Instructions for AI coding agents
```

Docs: [Architecture](docs/ARCHITECTURE.md) |
[Troubleshooting](docs/TROUBLESHOOTING.md) |
[Testing checklist](docs/TESTING.md) |
[AGENTS.md](AGENTS.md)

## Project Status And Known Limitations

Moon OS is under active hardware validation on Raspberry Pi 4 and Pi 5.

- The fork pins moonlight-qt at a specific public commit. See
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before rebasing it.
- The installer targets Raspberry Pi OS Lite bookworm arm64. A trixie rebase
  may require dependency name updates.
- Wi-Fi regulatory domain defaults still need a first-run region step.
- Recent games are keyed by host name because upstream does not expose stable
  host UUIDs to QML.
- Updates are git-based, not apt-repository based. There is no automatic
  rollback yet if a branch update is bad.
- Licensing needs a maintainer decision.

## License

The root [`LICENSE`](LICENSE) file is MIT, while
`third_party/moonlight-qt/LICENSE` is GPLv3. Moon Shell is compiled into the
same binary as moonlight-qt through the fork patch, so distributed binaries
must be treated as GPLv3-compatible combined works unless a maintainer resolves
the licensing split differently.
