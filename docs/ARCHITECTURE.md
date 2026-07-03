# Moon OS architecture

## The one-binary model

Moon OS ships a single UI process, `moon-shell`, which **is** moonlight-qt —
compiled with an extra `app/moon/` directory and a 17-line patch. Everything
below runs inside that process except the root helpers:

```
┌────────────────────────────────────────────────────────────┐
│ moon-shell (user "moon", Qt EGLFS on KMS, tty1)            │
│                                                            │
│  Moon Shell QML (qrc:/moon/qml)                            │
│   Home · Library · Pair · Wizard · Settings · Recovery     │
│        │                 │                                 │
│        │ QML types       │ QML singletons ("MoonOS 1.0")   │
│  ┌─────▼──────────┐  ┌───▼─────────────────────────────┐   │
│  │ Moon Core       │  │ Moon services (app/moon/src)   │   │
│  │ = moonlight-qt  │  │ NetworkService  → NM D-Bus     │   │
│  │ backend:        │  │ BluetoothService→ BlueZ D-Bus  │   │
│  │ ComputerManager │  │ DisplayService  → libdrm/ALSA  │   │
│  │ NvPairingManager│  │ MoonSystem      → logind/sysd  │   │
│  │ Session (FFmpeg │  │ CecService      → libcec       │   │
│  │  V4L2/DRM, SDL) │  │ MoonSettings    → /var/lib     │   │
│  └────────────────┘  └────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
   privileged actions via polkit-authorized D-Bus only
┌────────────────────────────────────────────────────────────┐
│ root helpers, each its own oneshot systemd unit            │
│ moon-update · moon-devmode-{on,off} · moon-config-{ex,im}  │
│ moon-firstboot · moon-factory-reset                        │
└────────────────────────────────────────────────────────────┘
```

### Why the streaming integration is native

The QML layer talks to the same C++ objects upstream's own UI uses:

- `ComputerManager` (singleton): mDNS discovery, host polling,
  `addNewHostManually`, persistence of paired hosts.
- `ComputerModel` / `AppModel`: list models over hosts and apps;
  `pairComputer(index, pin)` drives `NvPairingManager` (the real
  cert-exchange pairing protocol), `createSessionForApp(index)` returns a
  native `Session`.
- `Session`: the full streaming engine — moonlight-common-c protocol,
  FFmpeg with V4L2 stateless/DRM-PRIME decode on the Pi, SDL input/audio.
  `StreamView.qml` mirrors upstream's `StreamSegue` contract
  (`initialize(window)` → `start()` → signals → `sessionFinished`).
- `SdlGamepadKeyNavigation`: upstream's SDL-gamepad→key-event bridge powers
  all shell navigation (A=Return, B=Escape, X=Menu, Y/Start=Hangup).
- `StreamingPreferences`: the settings object `Session` reads; the Stream
  settings screen writes it directly, and `MoonSettings` snapshots it
  per-host for profiles.

### The fork mechanics

`third_party/moonlight-qt` stays **pristine** in git (pinned submodule).
At build time `scripts/prepare-fork.sh`:

1. `git submodule update --init --recursive`
2. copies `moon-shell/{moon.pri,moon.qrc,src,qml}` → `app/moon/`
3. applies `moon-shell/fork/0001-moon-os-fork.patch`, which only
   - adds `include(moon/moon.pri)` to `app.pro` (renames the target to
     `moon-shell`, adds sources/resources, QT += dbus, libcec/libdrm), and
   - swaps the QML entry point to `qrc:/moon/qml/MoonRoot.qml` behind
     `#ifdef MOON_OS`, after calling `Moon::registerTypes(&engine)`.

**Updating the fork** when upstream moves: bump the submodule, run
`prepare-fork.sh`; if the patch no longer applies, re-do the two edits by
hand (they're tiny), regenerate with `git -C third_party/moonlight-qt diff >
moon-shell/fork/0001-moon-os-fork.patch`, revert the submodule, commit both.

### Services: design decisions

- **All D-Bus, no shell-outs** for NetworkManager/BlueZ/logind/systemd.
  The only `QProcess` is read-only `journalctl` for the dev log screen.
- **Polling over signal subscriptions** for NM scan results and BlueZ device
  lists: `GetManagedObjects`/`GetAllAccessPoints` every 3–5 s is cheap on a
  local bus and immune to missed signals; connection state changes that
  matter (join Wi-Fi, pair controller) are event-driven via pending-call
  watchers.
- **BlueZ agent**: `NoInputNoOutput` capability at `/org/moonos/agent`,
  auto-accepting confirmation — the standard console pattern for
  "Just Works" controller pairing. Devices are `Trusted` before `Pair` so
  they can reconnect on their own later.
- **Friendly errors**: services translate raw D-Bus/protocol errors into
  human text at the boundary (`friendlyNmError`, `friendlyBtError`,
  `friendlyStageError`); raw detail rides along and renders only in
  developer mode.

### Display pipeline

- Boot: firmware (`vc4-kms-v3d`) → plymouth splash on KMS →
  `moon-shell.service` (`plymouth quit --retain-splash` for a seamless
  handoff) → Qt EGLFS picks the TV's preferred mode.
- Mode changes: `DisplayService` enumerates modes via libdrm, stages the
  choice into `/etc/moonos/eglfs-kms.json` (Qt's `QT_QPA_EGLFS_KMS_CONFIG`),
  applied by restarting the shell unit. Recovery mode ignores the file, so a
  bad mode can never brick the UI.
- Streaming: upstream sets `SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER=0` +
  DRM-master hooks so the SDL stream surface and Qt coexist; the Qt window
  hides during the stream.
- Safe area: pure UI scaling (`MoonSettings.safeAreaPct` scales the root
  item) — like game-console safe-area settings, no modeline hacks.

### Security posture

- Shell runs as `moon` with a logind session on tty1 (device ACLs give
  `/dev/dri`, `/dev/input`).
- polkit rules ([50-moonos.rules](../os-image/overlay/etc/polkit-1/rules.d/50-moonos.rules))
  allow exactly: reboot/power-off, NetworkManager control, and
  `manage-units` restricted to units whose name starts with `moon-`.
- SSH is off by default; developer mode enables it explicitly and per-device
  host keys are generated on first use.

### State map

| Path | Contents | Owner |
|---|---|---|
| `/var/lib/moonos/moon.ini` | Moon settings, recent games, per-host profiles | moon |
| `/var/lib/moonos/{update-status,config-io-status,devmode}` | Helper status/flags | root (world-readable) |
| `/home/moon/.config/Moonlight Game Streaming Project/` | Upstream: paired hosts, client cert, stream prefs | moon |
| `/etc/moonos/eglfs-kms.json` | Staged display mode | moon (group-writable dir) |
| `/etc/NetworkManager/system-connections/` | Saved Wi-Fi | root (via NM D-Bus) |
| `/var/lib/bluetooth/` | Pairings | root (via BlueZ D-Bus) |
