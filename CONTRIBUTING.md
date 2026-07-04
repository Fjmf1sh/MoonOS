# Contributing

Moon OS now uses a clone-and-install workflow. New user-facing work should
assume Raspberry Pi OS Lite 64-bit plus:

```bash
git clone --recurse-submodules <repo> moon-os
cd moon-os
./install.sh
```

Do not add new custom-image distribution paths. The old pi-gen image builder is
kept in `legacy-image-build/` for unsupported historical reference only.

Before opening a PR:

- Run `bash scripts/smoke-install-roundtrip.sh` when working on install,
  update, uninstall, services, or docs around those paths.
- Run the relevant Moon Shell build/test steps for UI or C++ changes.
- Do not commit inside `third_party/moonlight-qt`.
- Keep commit messages imperative and specific.

Updates are git-based: the shell's Update Moon OS action pulls the installed
checkout and re-runs `install.sh --from-update`. If you change service files,
helper scripts, dependencies, or installed paths, make the updater clean or
migrate old state where practical.
