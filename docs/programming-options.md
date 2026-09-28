# Programming the Basys-2 (Rev D) from macOS: options

Decision input, written 2026-09-28. Background: [basys2-board.md](basys2-board.md).

> **Decision (2026-09-28): option A.** adepttool is vendored in
> `tools/adepttool/` (with the macOS patch) and run through `bin/basys2`:
>
> ```sh
> bin/basys2 detect          # board and JTAG chain
> bin/basys2 prog top.bit    # load a bitfile into the FPGA (volatile)
> ```

## Starting point

- The board's only programming path is its **on-board USB**. There's an
  Atmel AT90USB chip running Digilent's closed "Adept" firmware, and it
  shows up on the Mac as `Digilent Adept USB Device` with USB ID
  **1443:0007**.
- **There's no FPGA JTAG header.** J4 is the programming header for the USB
  chip itself, has no TMS, and isn't fitted. So REPORT.md §8 option A (the
  FT4232H on a JTAG header) doesn't work as written.
- **REPORT.md option B assumed a Cypress FX2** USB chip. That's wrong for
  this board, so ixo-usb-jtag and fxload don't apply.
- **openFPGALoader can't talk to this board.** Its Digilent support covers
  only Digilent's FTDI-based cables (HS1/HS2 and boards with an FTDI chip),
  not the AT90USB firmware.
- **The JTAG chain on the board:** the USB chip drives TMS/TCK/TDI. The chain
  runs XCF02S (configuration flash) → XC3S100E (FPGA).

## The options

### A. `adepttool`, natively on macOS (open source)

[mwkmwkmwk/adepttool](https://github.com/mwkmwkmwk/adepttool) is an
open-source (MIT) Python 3 + libusb reimplementation of Digilent's USB
protocol, written for the Basys 2. Its device table is exactly this board's
chain: `xc3s100e` and `xcf02s`. `basys2_prog.py file.bit` loads a bitfile
into the FPGA over JTAG.

**Tested on this Mac, 2026-09-28** (Python 3.14, python-libusb1 3.4.0,
Homebrew libusb, no `sudo`, no drivers):

| Step | Result |
|---|---|
| Find the device, read its name, serial and firmware version | ✅ `Digilent Basys2-100`, SN `210155444658` (matches the `D444658` sticker on the back), FW `0116` |
| Bulk transfers | ❌ at first (`LIBUSB_ERROR_NOT_FOUND`), ✅ after a **one-line patch**: `claimInterface(0)` after opening the device. macOS libusb requires this; Linux doesn't. |
| Open the JTAG port | ✅ port 0, 4 MHz |
| Read the chip IDs | ✅ `d5045093` **xcf02s** and `11c10093` **xc3s100e**, with SW8 on. (With SW8 off it reads `ffffffff`, because the FPGA side is unpowered.) |
| Load a JtagClk bitfile (Digilent `basys2_100userdemoJtagClk.bit`) | ✅ DONE in 0.67 s |
| Load a CClk bitfile (Ben's 2014 `Switches_LEDs_Module_4/switches_leds.bit`) | ✅ DONE. So bitfiles built with ISE's default startup clock also load over JTAG |

- ✅ Native on macOS, with no VM or container. Fits the "no Windows, minimal
  layers" goal of the project.
- ✅ Uses the board as it is: no soldering, and the Digilent firmware stays.
- ✅ Small (about 600 lines). Easy to vendor into this repo, patch, and call
  from the Makefile.
- ⚠️ Unmaintained since 2019 (7 stars). The macOS patch would be ours to keep.
- ⚠️ Loads the FPGA only (volatile). It can't write the XCF02S flash, so a
  design doesn't survive a power cycle. The chain is detected, and writing
  the flash could be added later: the XCF02S is programmed over JTAG with a
  known algorithm.

### B. Digilent `djtgcfg` in an arm64 Linux VM (official)

Digilent ships Adept 2 Runtime and Utilities for Linux as `.deb`/`.rpm`,
including **arm64** builds (e.g.
[adept utilities 2.7.1 arm64](https://digilent.s3.amazonaws.com/Software/AdeptUtilities/2.7.1/digilent.adept.utilities_2.7.1-arm64.deb)).
Run them in an arm64 Linux VM with USB passthrough, such as UTM, Parallels or
VMware Fusion. Docker Desktop and OrbStack have no USB passthrough. Then:
`djtgcfg enum`, `djtgcfg prog -d Basys2 -i 1 -f design.bit`.

I didn't find a macOS build of the Adept Utilities.

- ✅ Official, and can also program the **XCF02S flash** (`-i 0`), so designs
  persist.
- ✅ Native arm64, so no Rosetta is needed for this part.
- ⚠️ Closed source, and Digilent has stopped developing Adept for Windows
  (2024). Whether current Linux builds still support the old AT90USB boards
  needs a quick check.
- ⚠️ A whole VM, plus moving the USB device into it, for every programming
  run. It's clunky next to a `make prog`.

### C. Solder an external JTAG adapter (the FT4232H on hand)

Solder wires onto TMS, TCK, TDI, TDO and GND (at vias or resistor pads, e.g.
R88/R89 on the TDI/TCK lines) and drive them with the FT4232H through
openFPGALoader.

- ✅ Uses the open, maintained toolchain that's already planned
  (openFPGALoader), once the XC3S100E patch is in.
- ❌ Modifies the board.
- ❌ **The USB chip is wired straight to the same JTAG lines.** It has to be
  kept from driving them. Holding it in reset (J4 pin 1) probably **turns
  off the board's power rails**, because the same chip drives the
  regulator's enable signal (`USB-ON`). So you'd have to rely on the
  firmware leaving the pins undriven when idle, which isn't verified.
- ❌ The most work and the most risk of the four.

### D. Replace the USB chip's firmware

Fit a header on J4, erase the AT90USB with an AVR programmer, and write
open firmware (e.g. a LUFA-based JTAG or XVC bridge).

- ❌ **Irreversible.** Digilent's firmware is closed and probably
  read-protected, so it can't be backed up and restored.
- ❌ The firmware has to be written first; none exists for this board.
- ❌ Soldering and an AVR programmer are needed.

## Comparison

| | A: adepttool (macOS) | B: djtgcfg in VM | C: solder JTAG | D: new firmware |
|---|---|---|---|---|
| Runs natively on the Mac | ✅ | ❌ (VM) | ✅ | ✅ |
| Board modification | none | none | solder wires | header + reflash |
| Reversible | ✅ | ✅ | mostly | ❌ |
| Load FPGA over JTAG | ✅ tested | ✅ | ✅ | ✅ (after writing it) |
| Write the XCF02S flash | ❌ (could be added) | ✅ | ✅ (openFPGALoader) | depends |
| Open source | ✅ MIT | ❌ | ✅ | ✅ |
| Effort to first bitfile | ~1 h | ~2–3 h | ~half a day + risk | days |
| Status | **chosen, working** | fallback | dropped | dropped |

## Recommendation

1. **Go with A.** Retest the chip-ID read with SW8 on, then load
   `basys2_100userdemoJtagClk.bit` from `data/` (see
   [data-inventory.md](data-inventory.md)). If both work, vendor adepttool
   with the macOS patch into the repo as the `make prog` backend, and update
   REPORT.md §8.
2. **Keep B as the fallback,** and for writing the XCF02S flash, which is
   rarely needed.
3. **Drop C and D.** The FT4232H module isn't needed for this board.
4. REPORT.md §8 needs rewriting either way: option A (JTAG header) and
   option B (FX2) are both based on wrong assumptions about the board.

## Writing the flash (XCF02S), added 2026-09-28

adepttool can't write the flash itself, so the Xilinx algorithm comes from
**iMPACT** (in the ISE container) as an SVF file. A small SVF player added
to our adepttool copy plays it over the board's USB:

```sh
make -C legacy/kronometer5 flash   # any project using mk/ise.mk
make -C boards/basys2 factory      # put Digilent's factory demo back
make -C boards/basys2 verify-factory  # read-only: does the flash hold the factory demo?
bin/basys2 reload                  # FPGA reloads from flash (like a power cycle)
```

`make flash` runs these steps:
1. `bitgen` with `StartUpClk:CClk`
2. `promgen -x xcf02s` to make the `.mcs` image
3. `impact -batch` with `program -p 2 -e -v` (erase, program, verify) into an SVF
4. `bin/basys2 svf` to play it (about 33 s at 1 MHz)
5. `bin/basys2 reload`

Tested on the board, 2026-09-28:

| Test | Result |
|---|---|
| Verify-only SVF of Digilent's `basys2_100userdemoCClk.bit` against the flash as delivered | ✅ 260 checks: **the factory flash holds exactly that file**, so `make factory` restores it |
| Verify-only SVF of kronometer5 against that flash (negative test) | ✅ fails as it should (56 of 8192 bits differ in the first block) |
| `make flash` of kronometer5 | ✅ erase, program and verify: 259 checks, 33 s; `reload` → DONE |
| `make factory`, then the verify from the first row again | ✅ factory contents back |
