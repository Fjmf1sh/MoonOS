# Legacy Image Build Path

This folder contains the retired Moon OS image/release workflow.

Moon OS is now installed onto Raspberry Pi OS Lite 64-bit with:

```bash
git clone <repo> moon-os
cd moon-os
./install.sh
```

The old pi-gen image builder and GitHub Release binary updater are kept here
only as historical reference for maintainers who need to inspect how the
flashable-image era worked. This path is unsupported going forward:

- no CI runs it,
- new installer/updater work should not be added here,
- docs should not tell normal users to build or flash these images.

If you revive anything in this directory, make it a deliberate migration back
into the supported install flow rather than another parallel distribution path.
