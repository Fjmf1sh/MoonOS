# Moon OS Troubleshooting

Most problems are recoverable from the TV, over SSH, or by re-running the
installer from the repository checkout.

## Install

**`install.sh` says the OS or architecture is wrong**
Moon OS installs only on Raspberry Pi OS Lite 64-bit. Check:

```bash
uname -m
cat /etc/os-release
tr -d '\0' < /proc/device-tree/model
```

Expected architecture is `aarch64`, and the OS should identify as Raspberry Pi
OS or have Raspberry Pi apt sources enabled. For CI dry runs only, use:

```bash
MOONOS_ALLOW_UNSUPPORTED=1 ./install.sh --dry-run --no-build --no-restart
```

If you are already invoking the script with `sudo`, put the override after
`sudo` because sudo drops most leading environment variables:

```bash
sudo MOONOS_ALLOW_UNSUPPORTED=1 ./install.sh
```

**Permission denied**
Run the script from the checkout as a sudo-capable user:

```bash
./install.sh
```

The script self-elevates with `sudo` for system changes. If sudo is not
installed or the user cannot use it, fix that in Raspberry Pi OS first.

**Dependency install fails**
Run:

```bash
sudo apt update
sudo apt install -f
```

Then retry `./install.sh`. Moon OS resolves the known Raspberry Pi OS
bookworm/trixie FFmpeg and libcec runtime package names automatically.

**`patch does not apply` from `prepare-fork.sh`**
The pinned moonlight-qt submodule moved or the fork patch needs refreshing.
Follow "Updating the fork" in [ARCHITECTURE.md](ARCHITECTURE.md). Do not commit
inside `third_party/moonlight-qt`.

**`git submodule update` fails with `not our ref`**
The submodule pointer references a commit that is not public upstream. Reset the
submodule to the public commit named by `MOONLIGHT_REF` in
`scripts/prepare-fork.sh`, then commit only the corrected superproject pointer.

**`qmake6` is missing**
The build dependencies did not install. Re-run the installer and check the apt
output. The relevant package is `qt6-base-dev-tools`.

## Boot

**First thing to check: the startup log**
`moon-shell.service` mirrors startup output to
`/boot/firmware/moon-shell.log`, and recovery mode writes
`/boot/firmware/moon-recovery.log`. These logs include the user, groups, DRM
device state, Qt platform, and the exact launch error.

**Splash, then black screen**
Read `moon-shell.log` first. Common causes:

- Missing runtime library: re-run `./install.sh` so dependencies and the binary
  are rebuilt.
- QML load error: check the last lines of the log for the missing file or type.
- Bad display mode: remove staged display config and restart:
  ```bash
  sudo rm -f /var/lib/moonos/eglfs-kms.json /etc/moonos/eglfs-kms.json
  sudo systemctl restart moon-shell
  ```

After repeated crashes, `moon-recovery.service` should start automatically.
If recovery also fails, `moon-emergency.service` prints a text banner on tty1.

**Text console appears instead of Moon Shell**
Check service state:

```bash
systemctl status moon-shell
journalctl -u moon-shell -b
```

If `getty@tty1.service` is active and Moon Shell is not enabled, re-run
`./install.sh`.

## Updates

**Update does nothing**
Settings -> System -> Update Moon OS runs `moon-update.service`. Check:

```bash
cat /var/lib/moonos/update-status
sudo tail -200 /var/lib/moonos/update.log
cat /etc/moonos/install.conf
```

`MOONOS_REPO_DIR` must point to the git checkout that still exists on disk.

**Updater cannot pull**
The updater uses `git fetch --all --prune` and `git pull --ff-only` on branch
checkouts. Fix local changes or divergent branches manually:

```bash
cd "$(sed -n 's/^MOONOS_REPO_DIR="\(.*\)"/\1/p' /etc/moonos/install.conf)"
git status
git pull --ff-only
```

Then run:

```bash
sudo systemctl start moon-update
```

**Updater keeps reporting stale service files**
Re-run the installer:

```bash
./install.sh --no-restart
sudo systemctl daemon-reload
systemctl cat moon-shell moon-update moon-uninstall
```

The updater automatically removes known leftovers from the old release-binary
path, including `moon-shell-update.service` and `update-release.sh`, and
migrates old `/etc/moonos/eglfs-kms.json` display config into
`/var/lib/moonos/eglfs-kms.json`.

**Skip OS package upgrades during Moon OS updates**
Edit `/etc/moonos/update.conf`:

```bash
DO_APT=0
```

Moon OS code updates will still pull git and rerun `install.sh`.

## Uninstall

**Uninstall button was pressed accidentally**
The shell shows a confirmation dialog first. The service path runs
`uninstall.sh --yes` only after confirmation.

**Manual uninstall asks for confirmation**
Type the exact prompt:

```text
uninstall moonos
```

**After uninstall, no login appears**
Restore the default tty login:

```bash
sudo systemctl enable --now getty@tty1.service
sudo systemctl daemon-reload
```

If Moon OS units remain:

```bash
sudo rm -f /etc/systemd/system/moon-*.service
sudo systemctl daemon-reload
```

## Icons And Fonts

Empty icon boxes usually mean the font packages or fontconfig rule did not
install. Re-run `./install.sh`, then check:

```bash
fc-match sans-serif
fc-list | grep -i noto
```

## Display And Audio

**Black screen after changing resolution**
Use Recovery -> Reset display settings, or run:

```bash
sudo rm -f /var/lib/moonos/eglfs-kms.json /etc/moonos/eglfs-kms.json
sudo systemctl restart moon-shell
```

**No stream audio**
Pick the HDMI device in Settings -> Display & sound. Over SSH:

```bash
speaker-test -D default:CARD=vc4hdmi0
```

**TV remote does nothing**
Enable HDMI-CEC in the TV menu, then toggle TV remote control in Moon Shell.
Over SSH:

```bash
cec-ctl --list-devices
```

## Network And Pairing

**PC never appears**
Make sure Sunshine is running, the Pi and PC are on the same subnet, and the
PC firewall allows Sunshine. mDNS often fails across VLANs; use Add PC by IP.

**Pairing PIN rejected**
Restart pairing and enter the fresh PIN in Sunshine's web UI under the PIN tab.

**Wi-Fi joins then drops during streams**
Prefer Ethernet or 5 GHz Wi-Fi. Lower stream bitrate as a temporary workaround.

## Controllers

**Controller will not pair**
Put it in pairing mode, not just powered on. If it was paired before, forget it
in Moon Shell and pair again.

**Paired but no UI navigation**
Check:

```bash
journalctl -u moon-shell -b | grep -i gamepad
```

The shell depends on SDL gamepad mappings and focused Qt windows for navigation.

## Escape Hatches

- Re-run `./install.sh` from the checkout.
- Start recovery: `sudo systemctl start moon-recovery`.
- Reset display config:
  `sudo rm -f /var/lib/moonos/eglfs-kms.json /etc/moonos/eglfs-kms.json`.
- Factory reset on next boot: `sudo touch /var/lib/moonos/.factory-reset`.
- Restore normal tty login:
  `sudo systemctl enable --now getty@tty1.service`.
- Use the unsupported archived image builder only from `legacy-image-build/`.
