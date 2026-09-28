# JTAG: FT4232H Mini Module → Basys-2, step by step

> **Not used for Ben's Basys-2 (decided 2026-09-28).** The Rev D board has no
> FPGA JTAG header, so it's programmed through its own USB with `bin/basys2`
> instead (see [programming-options.md](programming-options.md)). Steps 1–3
> stay as a record of the working FT4232H setup.

How to use an **FTDI FT4232H Mini Module (PCB Rev 1.1, ©2010 FTDI Ltd,
mini-B USB)** as a JTAG adapter for the **Digilent Basys-2 (XC3S100E)** from
macOS, with openFPGALoader. No drivers or `sudo` needed.

The background and alternatives are in [`REPORT.md` §8](../REPORT.md#8-programming-the-board-from-macos).
Pin numbers come from FTDI datasheet **FT_000115 v1.8**
([FTDI](https://ftdichip.com/wp-content/uploads/2020/07/DS_FT4232H_Mini_Module.pdf),
[archived copy](https://web.archive.org/web/2016id_/http://www.ftdichip.com/Support/Documents/DataSheets/Modules/DS_FT4232H_Mini_Module.pdf)),
tables 3.1 and 3.2 and §3.

## Progress

| Step | What | Status |
|---|---|---|
| 1 | Power jumper, CN3-1 ↔ CN3-3 | ✅ done 2026-09-26 |
| 2 | I/O power wire, CN2-5 → CN2-11 | ✅ done 2026-09-26 |
| 3 | Module check on the Mac | ✅ passed 2026-09-26 |
| 4 | JTAG wiring to the Basys-2 | ⛔ blocked: no JTAG header on Rev D ([details](basys2-board.md#-theres-no-fpga-jtag-header)) |
| 5 | Chain detect (XC3S100E + XCF02S), record the IDCODE | ⬜ to do |
| 6 | Patch openFPGALoader for the XC3S100E, load a blinky | ⬜ to do |

---

## Parts

- [ ] FT4232H Mini Module, Rev 1.1
- [ ] USB A → mini-B cable that **carries data** (not charge-only)
- [ ] 1 × 2.54 mm jumper cap (an old PC-motherboard jumper works)
- [ ] 6 × **female–female** jumper wires (1 for I/O power, 5 for JTAG)
- [ ] Basys-2 and its own USB cable (for power)

## Safety rules

1. **Unplug the module before changing any jumper or wire.**
2. **Never bridge across the two rows at CN3 pins 1–2.** Pin 2 is GND, so
   that shorts USB 5 V to ground.
3. **Don't connect the Basys-2's JTAG VDD pin.** Both boards have their own
   USB power, and tying their supplies together can back-feed one into the
   other.
4. Both sides run at **3.3 V**, so no level shifting is needed.

## Finding the pins

CN2 and CN3 are 2×13 headers (2.54 mm pitch), pins pointing down from the
underside. **Pin 1 is the square pad.** Odd pins run along the row that
has pin 1, and even pins along the other row. Viewed from the top, component
side up:

```
            board edge
   2   4   6   8  10  12 ... 26     ← even row
  [1]  3   5   7   9  11 ... 25     ← odd row (pin 1 = square pad)
   ↑
 end nearest the USB connector
```

- Pin 3 is **next to** pin 1 in the same row. Pin 2 is **across** from
  pin 1.
- From underneath the picture is mirrored left to right, but the rule
  "odd numbers along the square-pad row" still holds.
- Count along the odd row: 1, 3, 5, 7, 9, **11**. Pin 11 is the 6th pin in
  that row.

## Pins used

| Pin | Name | Role here |
|---|---|---|
| CN3-1 | VBUS | USB 5 V out (to the jumper) |
| CN3-3 | VCC | Regulator input (from the jumper) |
| CN2-1 / 3 / 5 | V3V3 | 3.3 V from the regulator |
| CN2-11 (also CN2-21, CN3-12, CN3-22) | VIO | Chip I/O supply. All four are one net. |
| CN2-2 / 4 / 6 | GND | Ground |
| CN2-7 | AD0 | **TCK** |
| CN2-10 | AD1 | **TDI** |
| CN2-9 | AD2 | **TDO** |
| CN2-12 | AD3 | **TMS** |

AD1 and AD2 are **not** in pin order: AD2 is on pin 9 and AD1 is on pin 10.

---

## Step 1: power jumper ✅

Fit a jumper cap on **CN3-1 ↔ CN3-3**, along the odd row.

**Without it:** the module is completely dead and doesn't appear on USB at
all. That's what we saw on the first attempt.

## Step 2: I/O power wire ✅

A female–female wire from **CN2-5** (pin 1 or 3 also works) to **CN2-11**.

The datasheet says to link all four VIO pins (CN2-11, CN2-21, CN3-12,
CN3-22). They're a single net on the board, so one link is enough to work.
Adding the others is optional.

**Without it:** the module shows up on USB, but as `Quad RS232-HS` with
**no serial number**, and openFPGALoader fails with
`mpsse_write: fail to write with error -1 (usb bulk write failed)`, even
with `sudo`. The FT4232H's I/O side (including the settings EEPROM) has no
power.

## Step 3: check the module on the Mac ✅

Plug in the module only, with nothing on the JTAG pins.

```sh
system_profiler SPUSBHostDataType | grep -A8 'FT4232H'
ls /dev/cu.usbserial-*
openFPGALoader -c ft4232 --detect; echo "exit=$?"
```

**Expected (observed 2026-09-26):**
- A USB device named **`FT4232H MiniModule`**, manufacturer FTDI,
  VID:PID **0x0403:0x6011**, 480 Mb/s, **with a serial number**.
- Four serial ports, `/dev/cu.usbserial-<serial>0` to `…3`. These come from
  macOS's own driver (`com.apple.DriverKit-AppleUSBFTDI`). They're harmless:
  openFPGALoader can still use channel A while they exist.
- openFPGALoader prints `Jtag frequency : requested 6.00MHz -> real 6.00MHz`,
  finds no devices, and gives **`exit=0`**. No `sudo` needed.

## Step 4: JTAG wiring to the Basys-2

> ⚠️ **Blocked (2026-09-28):** Ben's Basys-2 is Rev D, and it has **no FPGA
> JTAG header**. The only 6-pin header, J4, is the USB chip's programming
> header and has no TMS. See [basys2-board.md](basys2-board.md#-theres-no-fpga-jtag-header)
> for the options.

Unplug the module and leave the Basys-2 unpowered. Use the **labels printed
on the Basys-2** next to its 6-pin JTAG header. Don't assume a pin order.

| FT4232H | Wire | Basys-2 JTAG |
|---|---|---|
| CN2-7 | → | TCK |
| CN2-10 | → | TDI |
| CN2-9 | ← | TDO |
| CN2-12 | → | TMS |
| CN2-2 | — | GND |
| — | not connected | VDD |

Checklist before powering up:
- [ ] 5 wires, each checked against the table
- [ ] Basys-2 VDD left unconnected
- [ ] Power jumper and I/O power wire from steps 1 and 2 still in place
- [ ] No wire touching a neighbouring pin

## Step 5: detect the JTAG chain

1. Power the Basys-2 from its own USB cable.
2. Plug the module into the Mac.
3. Run:
   ```sh
   openFPGALoader -c ft4232 --detect
   ```

**Expected:** two devices in the chain.
- Index 0: **XC3S100E**. openFPGALoader v1.1.1 doesn't know this part, so an
  "unknown device" message is expected. **Write down the IDCODE it prints.**
  The datasheet value is `0x01C10093`; the first hex digit is the silicon
  revision and may differ.
- Index 1: **XCF02S** platform flash, IDCODE `0x?5045093`. openFPGALoader
  knows this one.

## Step 6: patch openFPGALoader and load a bitstream

Add the XC3S100E to openFPGALoader's part table, build it locally, and
load a bitstream built with `bitgen -g StartUpClk:JtagClk`. See
[`REPORT.md` §8, "XC3S100E patch for openFPGALoader"](../REPORT.md#xc3s100e-patch-for-openfpgaloader).
Before relying on the patch, confirm that the IDCODE you recorded in step 5
matches.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Module doesn't appear on USB at all | Power jumper (CN3-1↔3) missing; charge-only cable; flaky hub | Fit the jumper; try a known data cable; plug straight into the Mac |
| Appears as `Quad RS232-HS` with no serial number | I/O power wire (V3V3→VIO) missing | Step 2 |
| `usb bulk write failed` / `low level FTDI init failed` | Same: VIO not powered | Step 2. It wasn't macOS's serial driver, and `sudo` doesn't help. |
| `unable to claim` / `busy` | Another program has a `/dev/cu.usbserial-…0` port open | Close that program (serial terminal etc.) |
| Detect finds no devices after wiring | Basys-2 not powered; GND missing; wires on the wrong pins | Check power and GND; recheck the step 4 table |
| IDCODE reads `0xFFFFFFFF` | TDO not connected, or TDI/TDO swapped | Check CN2-9 ← TDO and CN2-10 → TDI |
| IDCODE reads `0x00000000` | TDO shorted to GND, or TCK/TMS swapped | Check CN2-7 (TCK) and CN2-12 (TMS) |
| Detect is unreliable | Long or loose wires | Shorter wires; lower the clock with `--freq 1M` |
