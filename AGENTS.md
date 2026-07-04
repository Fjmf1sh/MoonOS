# AGENTS.md — instructions for AI coding agents working on this repo

This file is read by AI coding agents (Claude Code, Cursor, Copilot, Codex,
etc.) before they work in this repository. If you are an agent: read this
whole file before making changes.

## What Moon OS is

**Moon OS** is a dedicated game-streaming console environment for Raspberry Pi
4 and 5. It installs onto Raspberry Pi OS Lite 64-bit with `./install.sh` and
boots straight into **Moon Shell** — a fullscreen, controller-first,
Big-Picture-style UI — with no desktop environment, no terminal, and no visible
Linux underneath during normal use.

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
- **`install/overlay`** contains the runtime overlay copied by `install.sh`.
- **`legacy-image-build/`** contains the retired pi-gen image builder for
  historical reference only. Do not treat it as the supported path.
- **`.github/workflows/smoke.yml`** dry-runs install, update, and uninstall
  control flow.
- Full architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Install
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
- CI does not trust the submodule pointer at all: smoke workflows check out
  with `submodules: false`; `prepare-fork.sh` is responsible for syncing the
  pinned upstream commit.

## Install / update model

- The supported install path is Raspberry Pi OS Lite 64-bit plus `./install.sh`
  from a git checkout.
- The supported update path is Settings -> System -> Update Moon OS, which
  runs the git checkout updater and then re-runs `install.sh --from-update`.
- The supported removal path is Settings -> System -> Uninstall Moon OS or
  `./uninstall.sh`.
- Do not add docs, scripts, or UI that point users at custom image downloads,
  Raspberry Pi Imager custom images, Etcher, `dd`, or GitHub Release binary
  updates except inside `legacy-image-build/`.

## Commit messages

Write real commit messages. This repo has history like `upd`, `upd`, and a
joke message — don't add to that pile.

- **Imperative mood, one line summary, ~50–72 chars**: "Fix Bluetooth agent
  auto-accept for Just Works pairing", not "fixed bt" or "updates".
- **Say why, not just what**, when it isn't obvious from the diff. "Cap CI
  build parallelism to 2 (avoid OOM under QEMU emulation)" beats "change
  make -j".
- **Scope prefix when it helps**: `moon-shell:`, `install:`, `CI:`, `docs:`
  are fine, e.g. `install: clean legacy updater units during upgrade`.
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
- [ ] If you touched `moon-shell/`: does it still compile on Raspberry Pi OS
      Lite bookworm arm64 with dependencies declared in `install.sh`?
- [ ] If you added a new runtime dependency: did you add it to `install.sh`
      and verify `scripts/smoke-install-roundtrip.sh` still passes?
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
- Don't "clean up" the licensing by deleting or silently editing the root
  `LICENSE` (MIT) or `third_party/moonlight-qt/LICENSE` (GPLv3). They
  currently disagree — see README.md, "License" — and resolving that is a
  decision for a human maintainer, not something to paper over in a commit.
