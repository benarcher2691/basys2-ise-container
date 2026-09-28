# Vendored: adepttool

An open-source driver for Digilent's USB firmware, used here to program the
Basys-2 from macOS. See [docs/programming-options.md](../../docs/programming-options.md).

- **Upstream:** https://github.com/mwkmwkmwk/adepttool
- **Commit:** `99ff19414bb458ea322a1eb99e74fd9d8a22c38b` (2019-11-12)
- **License:** MIT (`COPYING`)

## Local changes

1. `adepttool/device.py`: call `claimInterface(0)` after opening the device.
   Without it, macOS libusb fails the first bulk transfer with
   `LIBUSB_ERROR_NOT_FOUND`. Linux doesn't need this.
2. `adepttool/jtag.py`: 5-second timeouts in `wait_for_init` and
   `wait_for_done`. Upstream loops forever if a bitfile doesn't configure.
3. `requirements.txt`: `libusb1>=3.0` instead of the pinned `1.6.6`.
   Tested with python-libusb1 3.4.0 on Python 3.14.

Not copied: `50-digilent.rules` (a Linux udev rule; macOS needs no rules or
drivers).

Use it through `bin/basys2`, which sets up `.venv/` on first run.
