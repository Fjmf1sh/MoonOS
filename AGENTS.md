# AGENTS.md — instructions for AI coding agents working on this repo

This file is read by AI coding agents (Claude Code, Cursor, Copilot, Codex,
etc.) before they work in this repository. If you are an agent: read this
whole file before making changes.

## What Moon OS is

**Moon OS** is a dedicated game-streaming console operating system for
Raspberry Pi 4 and 5. It flashes as a single `.img` and boots straight into
**Moon Shell** — a fullscreen, controller-first, Big-Picture-style UI — with
no desktop environment, no terminal, and no visible Linux underneath.

- **Moon Shell** (`moon-shell/`) is a fork of
  [moonlight-qt](https://github.com/moonlight-stream/moonlight-qt): the actual
  streaming client (pairing, host discovery, hardware-decoded video, input) is
  moonlight-qt's real C++ backend, not a CLI wrapper. Moon OS replaces only the
  QML frontend and adds native system services (Wi-Fi via NetworkManager
  D-Bus, Bluetooth controllers via BlueZ D-Bus, HDMI-CEC via libcec, power via
  logind).
- **`third_party/moonlight-qt`** is a git submodule pointing at the upstream
  repo, pinned to a specific public commit. It is patched at *build time* by
  `scripts/prepare-fork.sh` — see "The moonlight-qt submodule" below before
  touching anything in `third_party/`.
- **`os-image/`** builds the flashable image with pi-gen (Raspberry Pi OS Lite,
  arm64/bookworm base).
- **`.github/workflows/release.yml`** builds just the `moon-shell` binary in
  the cloud (arm64 emulation) and publishes it as a GitHub Release so flashed
  consoles can self-update from System settings.
- Full architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Build/flash
  instructions: [README.md](README.md). Fixing a broken build/boot:
  [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## The moonlight-qt submodule — read this before touching `third_party/`

`third_party/moonlight-qt` must **always** point at a real, publicly pushed
commit on the upstream repo. This repo has broken before because something
committed *inside* the submodule checkout (with the Moon OS fork patch already
applied), creating a private commit that only existed on a local machine. That
pointer got committed into the superproject, and GitHub Actions — which
clones fresh — could not fetch it (`remote error: upload-pack: not our ref`),
breaking CI for everyone.

Rules:
- **Never `git commit` or `git add` inside `third_party/moonlight-qt`.** The
  fork is applied by `scripts/prepare-fork.sh` at build time via
  `moon-shell/fork/0001-moon-os-fork.patch` and must never be baked into the
  submodule's history.
- If you need to change the fork's integration points (the `#ifdef MOON_OS`
  hooks in `app/main.cpp` / `app/app.pro`), edit
  `moon-shell/fork/0001-moon-os-fork.patch` directly (or regenerate it — see
  "Updating the fork" in docs/ARCHITECTURE.md), not the submodule checkout.
- Before committing anything under `third_party/moonlight-qt` at the
  superproject level, run `bash scripts/prepare-fork.sh` and confirm
  `git submodule status third_party/moonlight-qt` shows a commit that exists
  on `https://github.com/moonlight-stream/moonlight-qt` (no leading `+`/stray
  local commit).
- CI does not trust the submodule pointer at all: `release.yml` checks out
  with `submodules: false` and lets `prepare-fork.sh` clone moonlight-qt fresh
  at the pinned `MOONLIGHT_REF` commit. Keep it that way.

## Commit messages

Write real commit messages. This repo has history like `upd`, `upd`, and a
joke message — don't add to that pile.

- **Imperative mood, one line summary, ~50–72 chars**: "Fix Bluetooth agent
  auto-accept for Just Works pairing", not "fixed bt" or "updates".
- **Say why, not just what**, when it isn't obvious from the diff. "Cap CI
  build parallelism to 2 (avoid OOM under QEMU emulation)" beats "change
  make -j".
- **Scope prefix when it helps**: `moon-shell:`, `os-image:`, `CI:`, `docs:`
  are fine, e.g. `os-image: pin runtime libs so ldd never breaks on the Pi`.
- **Reference the failure mode you fixed**, if any — future readers (and
  future agents) debugging a recurrence will grep for it.
- Body (optional, blank line after summary) for anything a reviewer would
  otherwise have to ask about: what broke, what you verified, what's still
  untested.
- No filler commits. Don't commit "wip"/"checkpoint"/"upd" — squash or write
  a real message before it lands on `main` (pushes to `main` under
  `moon-shell/**` auto-trigger a release build).

## Before you commit — quick checklist

- [ ] If `third_party/moonlight-qt` changed: ran `prepare-fork.sh`, confirmed
      the submodule points at a public upstream commit.
- [ ] If you touched `moon-shell/`: does it still need to compile inside the
      pi-gen chroot (Qt 6, no extra deps beyond what's declared in
      `moon-shell/moon.pri` and `os-image/stage-moonos/00-packages`)?
- [ ] If you added a new dlopen'd Qt plugin/library dependency: does
      `os-image/stage-moonos/02-build-shell/00-run.sh`'s library-pinning scan
      still cover it, or does it need adding to `00-packages` explicitly?
  (This project shipped a build once where a runtime `.so` was silently
  stripped by cleanup and the binary died with `error while loading shared
  libraries` on first boot — don't reintroduce that class of bug.)
- [ ] Does the commit message say what changed and why?

## What NOT to do

- Don't shell out to `moonlight stream`/`moonlight pair`/`moonlight list` for
  streaming logic — Moon Shell calls moonlight-qt's native C++ objects
  (`ComputerManager`, `AppModel`, `Session`, etc.) directly. See
  docs/ARCHITECTURE.md.
- Don't add a desktop environment, window manager, or terminal to the boot
  path. Moon OS boots straight to `moon-shell.service` on tty1 via EGLFS/KMS.
- Don't hide the mouse cursor (`QT_QPA_EGLFS_HIDECURSOR`) — Moon OS supports
  mouse navigation alongside controller/keyboard/CEC remote.
- Don't skip the friendly-error convention: raw errors/log excerpts must stay
  behind developer mode (`MoonSettings.developerMode`), never shown to a
  normal user by default.
