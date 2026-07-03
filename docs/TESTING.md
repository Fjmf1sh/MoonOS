# Moon OS testing checklist

Hardware matrix: run the full list on **Pi 4 (4 GB)** and **Pi 5**, each
over HDMI to at least one TV and one monitor. Host: Sunshine (latest) on
Windows and on Linux.

## Build & flash
- [ ] `sudo os-image/build.sh` completes; `deploy/moon-os-rpi4-rpi5.img` exists
- [ ] Image flashes with Raspberry Pi Imager (custom image path)
- [ ] Rootfs auto-expands to the full SD card on first boot

## Boot experience
- [ ] Power-on → Moon OS splash (no rainbow text, no scrolling kernel log)
- [ ] Splash → shell handoff without a console flash
- [ ] Cold boot to interactive Home in < 30 s (Pi 4) / < 20 s (Pi 5)
- [ ] No getty/login prompt on any connected display
- [ ] Reboot and power-off from the UI work; TV shows no Linux text during shutdown

## First-boot wizard
- [ ] "Welcome to Moon OS" wizard appears exactly once
- [ ] Keyboard-only, controller-only, and CEC-remote-only navigation all complete it
- [ ] Wi-Fi step skipped automatically when Ethernet is up
- [ ] Safe-area slider visibly shrinks the UI live; persists after reboot
- [ ] Wizard never reappears after completion (and does reappear after factory reset)

## Network
- [ ] Scan lists nearby SSIDs sorted by strength, lock icon on secured ones
- [ ] Join WPA2 network via on-screen keyboard (controller only)
- [ ] Wrong password → friendly error, retry path works
- [ ] Saved network auto-reconnects after reboot; Forget removes it
- [ ] Status strip shows IP, SSID, signal %; updates within ~10 s of changes

## Controllers
- [ ] Xbox One/Series, DualShock 4, DualSense, 8BitDo pair from the UI
- [ ] Battery % shows where supported; Forget + re-pair works
- [ ] Paired controller reconnects on power-up without touching the UI
- [ ] UI navigation: A select, B back, X context actions, D-pad + sticks move focus

## Pairing & library
- [ ] Sunshine host on same subnet appears via mDNS within ~5 s
- [ ] Manual IP add works across subnets; bad IP → friendly error with retry
- [ ] PIN pairing completes; host survives reboot (persisted)
- [ ] Library shows apps with box art; filter (Y) narrows the grid
- [ ] Offline host → clear offline state; Wake-on-LAN offer on click

## Streaming (the big one)
- [ ] 1080p60 H.264 and HEVC streams start in < 5 s on LAN
- [ ] Hardware decode confirmed (Pi 4: HEVC via V4L2; check no software-decode warning in devmode logs)
- [ ] Audio through selected HDMI output, in sync
- [ ] Controller input works in-game, multiple controllers if enabled
- [ ] Start+Select+L1+R1 exits stream → back at shell, UI nav restored
- [ ] Launch → quit → relaunch 5× without restart (no DRM/session leak)
- [ ] "App already running" flow: stop-and-play works
- [ ] Pulling Ethernet mid-stream → session ends → friendly error, not a hang
- [ ] Per-host profile saves and auto-loads (verify by differing resolutions on two hosts)

## Display, CEC, recovery
- [ ] Mode list matches TV EDID; staging + "Apply now" restarts into the new mode
- [ ] Bad-mode simulation: hand-write an invalid eglfs-kms.json → crash loop → Recovery screen appears → "Reset display settings" fixes it
- [ ] CEC: TV remote navigates the shell; toggle off stops it; "Wake TV" turns a standby TV on and grabs the input
- [ ] kill -9 the shell 4× fast → recovery screen (not a black screen, never a terminal)

## System
- [ ] Update runs, status reaches success, log in devmode
- [ ] Developer mode on → SSH reachable; off → connection refused
- [ ] Export to USB → file on stick; import on a *fresh* flash restores hosts + settings
- [ ] Factory reset → wizard on next boot, no paired hosts/networks/BT remain
- [ ] Nothing ever shows a terminal, a Qt error dialog, or a raw log excerpt outside devmode

## Soak
- [ ] 4-hour stream session: no thermal throttling artifacts (Pi 5 with fan), no memory creep (`smem` over SSH before/after)
- [ ] 48 h idle at Home: clock correct, no burn-in from static elements (glow subtle), still responsive
