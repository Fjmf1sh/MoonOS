# Moon OS architecture

## The one-binary model

Moon OS ships a single UI process, `moon-shell`, which **is** moonlight-qt —
compiled with an extra `app/moon/` directory and a small patch
(`moon-shell/fork/0001-moon-os-fork.patch`, currently ~50 lines). Everything
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

### The crash-recovery chain

Three systemd units form a ladder, each catching the failure of the one
above it, so a broken UI degrades gracefully instead of showing a black
screen forever:

```
moon-shell.service  --OnFailure (4 crashes/90s)-->  moon-recovery.service
                                                       │
                                        --OnFailure (3 crashes/120s)-->
                                                       ▼
                                              moon-emergency.service
                                        (readable text banner + root login,
                                         never a silent black screen)
```

- **moon-shell.service** — normal operation. Mirrors its stdout/stderr to
  `/boot/firmware/moon-shell.log` (the FAT boot partition, readable from any
  Windows/Mac machine — no ext4 tools needed) in addition to the journal, so a
  boot failure is self-diagnosing without SSH.
- **moon-recovery.service** — same binary, `MOONOS_RECOVERY=1`: skips any
  staged KMS mode override and shows `RecoveryView.qml` instead of the normal
  UI, with one-button fixes (restart, reset display settings, factory reset).
  Logs to `/boot/firmware/moon-recovery.log`.
- **moon-emergency.service** — last resort if *even recovery* can't render
  (e.g. a fault in the QML engine itself, not just a bad display setting).
  Prints a plain-text Moon OS banner to tty1 explaining where the logs are
  and how to recover, then hands the console to `agetty` so a developer can
  log in directly. This is the one path guaranteed not to depend on Qt/QML
  working at all.

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

**Updating the fork** when upstream moves: bump `MOONLIGHT_REF` in
`scripts/prepare-fork.sh` to the new public commit, run `prepare-fork.sh`;
if the patch no longer applies, re-do the two edits by hand (they're tiny),
regenerate with `git -C third_party/moonlight-qt diff >
moon-shell/fork/0001-moon-os-fork.patch`, then reset the submodule
(`prepare-fork.sh` does this for you) and commit the pointer + patch.

**Never commit inside `third_party/moonlight-qt`.** `prepare-fork.sh` applies
the patch as *uncommitted working-tree changes* by design — the fork must
never be baked into the submodule's own history. This repo broke CI once
already by doing exactly that: a local commit with the fork already applied
got referenced by the superproject's gitlink, and since it was never pushed
to the public moonlight-qt repo, GitHub Actions' checkout failed with
`remote error: upload-pack: not our ref`. `prepare-fork.sh` now force-resets
the submodule to `MOONLIGHT_REF` on every run specifically to make this
unrecoverable-by-accident; see AGENTS.md for the rule stated for contributors
and coding agents.

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
- **Controller auto-onboarding**: `BluetoothService::startControllerAutoConnect()`
  solves the chicken-and-egg of needing input to set up input. Called from
  the setup wizard's first screen, it powers on the adapter, reconnects any
  already-paired controller, starts scanning, and auto-pairs any *newly
  discovered device that looks like a controller* (icon/name heuristics),
  once per device per session — so the user only has to hold their
  controller's pair button. `moonregister.cpp` also calls
  `reconnectControllers()` unconditionally at every startup (not just first
  boot), so a previously-paired pad reconnects before Home even renders.
- **Friendly errors**: services translate raw D-Bus/protocol errors into
  human text at the boundary (`friendlyNmError`, `friendlyBtError`,
  `friendlyStageError`); raw detail rides along and renders only in
  developer mode.

### Display pipeline

- Boot: firmware (`vc4-kms-v3d`) → plymouth splash on KMS → `moon-shell.service`
  runs `plymouth quit` (not `--retain-splash`: retaining the splash
  framebuffer was found to block EGLFS from claiming the CRTC on some HDMI
  sinks — see docs/TROUBLESHOOTING.md) → Qt EGLFS picks the display mode,
  with `QT_QPA_EGLFS_ALWAYS_SET_MODE=1` forcing a fresh modeset rather than
  trusting whatever mode the splash left behind.
- Mode changes: `DisplayService` enumerates modes via libdrm, stages the
  choice into `/etc/moonos/eglfs-kms.json` (Qt's `QT_QPA_EGLFS_KMS_CONFIG`),
  applied by restarting the shell unit. Recovery mode ignores the file, so a
  bad mode can never brick the UI.
- Streaming: upstream sets `SDL_HINT_KMSDRM_REQUIRE_DRM_MASTER=0` +
  DRM-master hooks so the SDL stream surface and Qt coexist; the Qt window
  hides during the stream.
- Safe area: pure UI scaling (`MoonSettings.safeAreaPct` scales the root
  item) — like game-console safe-area settings, no modeline hacks.
- Mouse cursor: deliberately **not** hidden
  (`QT_QPA_EGLFS_HIDECURSOR` is unset). Qt EGLFS only ever draws a cursor
  when a pointer device is actually attached, so this costs nothing on a
  controller-only setup and enables full mouse navigation when a mouse is
  plugged in.
- Fonts: Raspberry Pi OS Lite ships almost no fonts, which left the shell's
  icon glyphs (🎮 🖥 ⚙ ‹ › …) rendering as empty "tofu" boxes. `fontconfig` +
  `fonts-dejavu-core` + `fonts-noto-core` + `fonts-noto-color-emoji` are
  installed, with a fallback rule
  ([`/etc/fonts/local.conf`](../os-image/overlay/etc/fonts/local.conf))
  appending the emoji font to every font-family match so no glyph can fall
  through.

### Input & navigation architecture

Every screen is drivable by gamepad, keyboard, mouse, or TV remote at once —
this took a couple of non-obvious fixes worth recording so they aren't
reintroduced:

- **Gamepad polling is gated on window focus.** moonlight-qt's
  `SdlGamepadKeyNavigation` only pumps its SDL polling timer while
  `notifyWindowFocus(true)` has been called — upstream's own `main.qml` does
  this from `onActiveChanged`/`onVisibleChanged`. `MoonRoot.qml` calls it
  explicitly at startup and keeps it in sync with window visibility; skipping
  this leaves a gamepad completely unresponsive with no error anywhere.
  `SdlGamepadKeyNavigation.setUiNavMode(false)` is also set explicitly so the
  D-pad/stick emit arrow keys (spatial navigation) rather than Tab/Backtab.
- **Every StackView page must own active focus.** `MoonRoot.qml`'s
  `StackView` force-focuses `currentItem` on every push/pop; without an
  explicitly focused item, Qt delivers key events but nothing is listening
  for them.
- **Controls that live in a `ListView` header are not reachable by
  arrow-key/gamepad navigation** — a `ListView`'s built-in `keyNavigationEnabled`
  only ever moves between delegates, never into the header. The Wi-Fi/
  Bluetooth toggle-and-scan controls therefore live as ordinary focusable
  buttons *above* the list (not in a `header:`), with an explicit
  `Keys.onUpPressed` bridge on the list so pressing Up at the top row returns
  focus to them.
- **On-screen keyboard vs. physical keyboard is disambiguated by
  `event.text`.** Synthetic key-events from the gamepad bridge and from the
  CEC remote carry no `text` (they're pure `Qt.Key_*` codes); real keystrokes
  from a physical keyboard do. `OnScreenKeyboard.qml` and `TextEntryDialog.qml`
  use that single distinction to route printable `event.text` straight into
  the field while letting text-less events drive on-screen key selection —
  so a plugged-in keyboard types directly with zero extra wiring, and
  controller/remote navigation of the on-screen keyboard is unaffected.
- **Mouse** is hover-to-focus (`MouseArea.hoverEnabled` on every card/button)
  plus click-to-activate; sliders are click/drag on the track.
- **Background:** `SpaceBackdrop.qml` — a starfield (each star twinkling on
  its own randomized cycle), periodic shooting stars, and a moon that
  animates to a new pose (`Behavior on x/y/width`) each time
  `StackView.onCurrentItemChanged` fires, i.e. every screen change.

### Security posture

- Shell runs as `moon` with a logind session on tty1 (device ACLs give
  `/dev/dri`, `/dev/input`).
- polkit rules ([50-moonos.rules](../os-image/overlay/etc/polkit-1/rules.d/50-moonos.rules))
  allow exactly: reboot/power-off, NetworkManager control, and
  `manage-units` restricted to units whose name starts with `moon-`.
- SSH is off by default; developer mode enables it explicitly and per-device
  host keys are generated on first use.

### Update / release pipeline

Moon Shell is a compiled binary, not an apt package, so "Update" in System
settings does two independent things (`update.sh`):

1. **`apt full-upgrade`** for the base OS — always available, no configuration
   needed.
2. **Moon Shell self-update** — downloads a new `moon-shell` binary from a
   GitHub Release, gated by `MOONOS_UPDATE_REPO` in
   [`/etc/moonos/update.conf`](../os-image/overlay/etc/moonos/update.conf).
   The console compares its `/etc/moonos/version` against the release's
   `version` asset (string-sorted, so a console never "updates" to something
   older or equal), downloads `moon-shell-arm64`, verifies it against
   `moon-shell-arm64.sha256` (refuses to install on mismatch), and applies it
   on the next shell restart.

Releases are produced entirely in the cloud by
[`.github/workflows/release.yml`](../.github/workflows/release.yml): it
compiles just the `moon-shell` binary (not the whole image) on GitHub's
native arm64 hosted runner, inside a Debian-bookworm Docker container, then
publishes/updates a GitHub Release with the three assets above. Native arm64
keeps the build out of QEMU user-mode emulation while the container keeps the
binary aligned with the Pi's Debian bookworm runtime. It runs on a push to
`main` touching `moon-shell/**` or the pinned submodule commit, on a manual
"Run workflow" click, or on a `v*` tag. A `scripts/release.sh` +
`scripts/package-update.sh` pair does the same thing from a local
Linux/WSL/git-bash shell with the GitHub CLI, for anyone who'd rather not use
the cloud path.

CI-specific gotchas already hit and fixed once, worth knowing before touching
`release.yml` again:
- **Keep the release job on a native arm64 runner.** The old
  `uraimo/run-on-arch-action` path used QEMU user-mode emulation and failed
  before compilation when Debian's `python3` post-install script exited under
  emulation. Use GitHub's current hosted arm64 runner label and a normal
  `debian:bookworm` Docker container instead of adding QEMU/binfmt setup.
- **`qmake6` can fail to parse the compiler's search-path output inside the
  release container** (`failed to parse default search paths from compiler
  output`), even though the identical call succeeds in the pi-gen chroot
  `os-image/build.sh` uses — a locale/output-formatting issue in qmake's
  compiler probing, not a source problem. Worked around by forcing
  `LC_ALL=C LANG=C TERM=dumb GCC_COLORS=` right before `qmake6`; a compiler
  diagnostic sample is printed just before it so a recurrence is diagnosable
  from the log instead of another guess.

### State map

| Path | Contents | Owner |
|---|---|---|
| `/var/lib/moonos/moon.ini` | Moon settings, recent games, per-host profiles | moon |
| `/var/lib/moonos/{update-status,config-io-status,devmode}` | Helper status/flags | root (world-readable) |
| `/var/lib/moonos/update.log` | Full transcript of the last update run | root |
| `/home/moon/.config/Moonlight Game Streaming Project/` | Upstream: paired hosts, client cert, stream prefs | moon |
| `/etc/moonos/eglfs-kms.json` | Staged display mode | moon (group-writable dir) |
| `/etc/moonos/update.conf` | `MOONOS_UPDATE_REPO`, whether apt upgrades run | root |
| `/etc/moonos/version` | Installed Moon Shell version (compared against Release `version`) | root |
| `/boot/firmware/moon-shell.log`, `moon-recovery.log` | Startup diagnostics for the shell/recovery unit, readable from any OS | root |
| `/etc/NetworkManager/system-connections/` | Saved Wi-Fi | root (via NM D-Bus) |
| `/var/lib/bluetooth/` | Pairings | root (via BlueZ D-Bus) |
