# Moon OS Testing Checklist

Hardware matrix: run the full list on Pi 4 and Pi 5, each over HDMI to at
least one TV and one monitor. Host: Sunshine on Windows and Linux.

## Install Round Trip

- [ ] Fresh Raspberry Pi OS Lite 64-bit boots and has network access
- [ ] `git clone --recurse-submodules <repo> moon-os`
- [ ] `cd moon-os && ./install.sh` completes
- [ ] Re-running `./install.sh` completes without duplicate users, services, or units
- [ ] `systemctl is-enabled moon-shell moon-update moon-uninstall` reports expected units
- [ ] `getty@tty1.service` is disabled after install
- [ ] `moon-shell` starts after reboot
- [ ] `scripts/smoke-install-roundtrip.sh` passes in CI

## Boot Experience

- [ ] Power-on -> Moon OS splash -> Moon Shell
- [ ] Cold boot to interactive Home in under 30 s on Pi 4 and under 20 s on Pi 5
- [ ] No login prompt on the connected display during normal operation
- [ ] All icon glyphs render
- [ ] `/boot/firmware/moon-shell.log` exists after boot
- [ ] Forced crash loop starts Recovery
- [ ] Forced recovery failure starts emergency text banner

## First-Run Wizard

- [ ] Wizard appears exactly once after install
- [ ] Keyboard-only, controller-only, mouse-only, and CEC-remote-only navigation complete it
- [ ] Wi-Fi step skips automatically when Ethernet is up
- [ ] Safe-area slider updates live and persists after reboot
- [ ] Factory reset makes the wizard appear again

## Network

- [ ] Wi-Fi screen uses side-by-side known and nearby layout
- [ ] Scan lists SSIDs sorted by strength, with lock icons on secured networks
- [ ] Join WPA2 network via on-screen keyboard
- [ ] Wrong password shows a friendly retry path
- [ ] Saved network reconnects after reboot
- [ ] Forget removes a saved network
- [ ] Connecting to Wi-Fi does not crash the shell

## Bluetooth

- [ ] Bluetooth screen uses side-by-side known and nearby layout
- [ ] Xbox, DualShock 4, DualSense, and 8BitDo controllers pair from the UI
- [ ] Setup wizard auto-discovers and pairs a controller in pairing mode
- [ ] Paired controller reconnects after reboot
- [ ] Battery status appears where supported
- [ ] Forget and re-pair works

## Navigation And Input

- [ ] A selects, B backs out, X opens context actions
- [ ] D-pad and analog sticks move focus predictably
- [ ] Setup wizard Back and Continue can both navigate up to the action button
- [ ] Physical keyboard types directly into every text field
- [ ] On-screen keyboard works with controller only
- [ ] Mouse hover focuses and click activates
- [ ] Text never overlaps buttons at 1080p or 4K
- [ ] GUI scale is consistent on same-size 1080p and 4K displays

## Pairing And Library

- [ ] Sunshine host appears via mDNS within about 5 s
- [ ] Manual IP add works across subnets
- [ ] Bad IP shows a friendly error
- [ ] PIN pairing completes
- [ ] Paired host persists after reboot
- [ ] Library shows apps and filtering works
- [ ] Offline host state is clear

## Streaming

- [ ] 1080p60 H.264 stream starts in under 5 s
- [ ] 1080p60 HEVC stream starts in under 5 s
- [ ] Hardware decode is used
- [ ] Audio routes to selected HDMI output
- [ ] Controller input works in-game
- [ ] Start+Select+L1+R1 exits stream back to shell
- [ ] Launch and quit a stream 5 times without restart
- [ ] Pulling network mid-stream returns to shell with a friendly error

## Display, Audio, And CEC

- [ ] Mode list matches EDID
- [ ] Changing resolution applies and persists
- [ ] Bad mode simulation triggers Recovery and Reset display settings fixes it
- [ ] Sound output setting persists after reboot
- [ ] CEC remote navigates when enabled and stops when disabled

## Update

- [ ] Settings -> System -> Update Moon OS starts `moon-update.service`
- [ ] Update status reaches `success`
- [ ] `/var/lib/moonos/update.log` records apt, git, installer, cleanup, and service audit steps
- [ ] On a branch checkout, updater pulls fast-forward changes
- [ ] Updater re-runs `install.sh --from-update`
- [ ] Running updater five times leaves one set of services and a clean status
- [ ] Legacy `moon-shell-update.service` and `update-release.sh` are removed if present
- [ ] Old `/etc/moonos/eglfs-kms.json` migrates to `/var/lib/moonos/eglfs-kms.json`

## Uninstall

- [ ] Settings -> System -> Uninstall Moon OS shows confirmation
- [ ] Cancel leaves services untouched
- [ ] Confirm starts `moon-uninstall.service`
- [ ] Manual `./uninstall.sh` requires exact text confirmation
- [ ] Uninstall stops and disables Moon OS units
- [ ] `getty@tty1.service` is enabled after uninstall
- [ ] Installed files under `/usr/lib/moonos`, `/etc/moonos`, and `/usr/bin/moon-shell` are removed
- [ ] Reboot after uninstall shows normal Raspberry Pi OS login

## Config Backup And Reset

- [ ] Export to USB writes `moonos-config.tar.gz`
- [ ] Import restores hosts and settings on another installed Pi
- [ ] Factory reset removes hosts, networks, Bluetooth state, and settings

## Soak

- [ ] 4-hour stream session shows no thermal throttling artifacts
- [ ] 48-hour idle at Home remains responsive
