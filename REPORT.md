# Basys-2 on the M2 MacBook Air: running Xilinx ISE 14.7 in a container

**Status:** plan only. Nothing in this document has been run yet.
**Date:** 2026-09-26
**Target machine:** `m2.local`, Apple M2, 24 GB RAM, macOS 27.0
**Target board:** Digilent Basys-2 (Spartan-3E **XC3S100E**, CP132 package)

---

## 1. Summary

The approach from the earlier discussion holds up, with three corrections:

1. **Programming the board is the real risk, not ISE.** `xc3sprog` does not
   support the Basys-2's on-board USB port. That port is a Cypress FX2 running
   Digilent's closed "Adept" firmware, and Docker Desktop on macOS can't pass USB
   through to a container anyway. So programming has to run natively on macOS,
   and the most reliable native route is an FTDI JTAG adapter. An FT4232H
   mini module that's already on hand should do the job (see §8).
2. **Yosys support for Spartan-3E is marked EXPERIMENTAL.** Yosys is still the
   front end I'd aim for, but XST (ISE's own synthesiser) stays in the container
   as a known-good reference and fallback.
3. **The "trimmed to ~220 MB" figure comes from someone else's setup** (a
   GUI-less XC6SLX150 flow). It's a plausible target for Spartan-3E, but we
   have to do the trimming ourselves, and we only do it after a full install
   produces a working bitstream.

Recommended architecture:

```
macOS 27 / M2 (native arm64)
│
├── yosys 0.68+           synthesis → EDIF        (already installed)
├── iverilog / verilator  simulation              (iverilog installed)
├── gtkwave               waveforms
├── make                  orchestration
├── bin/ise               thin wrapper → docker run
├── openFPGALoader        programming over FTDI JTAG  (already installed)
│
└── Docker Desktop (already installed; Linux arm64 VM)
     └── linux/amd64 container, run through Rosetta (QEMU as fallback)
          --network none, fixed MAC address, project dir mounted at /work
          └── ISE 14.7 WebPACK (lin64), command line only
               ├── ngdbuild   EDIF + UCF → NGD
               ├── map        → mapped NCD
               ├── par        → placed and routed NCD
               ├── trce       timing report
               ├── bitgen     → .bit
               └── xst        (reference and fallback synthesis only)
```

The end state is `make` → `top.bit` and `make prog` → a configured FPGA.
Everything proprietary stays in one container that has no network access.

---

## 2. What was checked on this machine (read-only)

| Item | Finding |
|---|---|
| Hardware | Apple M2, 24 GB RAM |
| OS | macOS 27.0 |
| Free disk | ~100 GiB on `/` (enough, but see the disk budget in §5) |
| Docker | Docker Desktop installed, engine 29.8.0 running, linux/arm64 VM with 8 CPUs and ~7.7 GB RAM |
| Docker settings file | No overrides, so Desktop defaults apply. The Rosetta toggle still needs checking in the UI (Phase 0). |
| Existing images | `env-embedded-rust`, `hello-world`. No ISE image yet. |
| yosys | 0.68+post (Homebrew) |
| iverilog | installed (Homebrew) |
| openFPGALoader | v1.1.1 (Homebrew). Knows **xc3s250e, xc3s500e and xcf02s**, but **not xc3s100e**. Has `ft232`/`ft2232`/`digilent*`/`usb-blaster` cables. |
| xc3sprog, openocd | not installed. There's no Homebrew formula for xc3sprog. |
| Rosetta daemon | not running right now (normal; it starts on demand) |

In line with the minimise-dependencies preference, **nothing new is required
on the host for the ISE part**: Docker Desktop, yosys, iverilog and
openFPGALoader are already there.

---

## 3. Key facts and constraints

### 3.1 ISE 14.7 itself
- ISE 14.7 (2013) is the last release. It was only ever built for x86/x86-64
  Windows and Linux. We use the **Linux 64-bit** binaries (`lin64`).
- Download: `Xilinx_ISE_DS_Lin_14.7_1015_1.tar` (roughly 6 GB) from AMD. This
  needs an AMD account and an export-compliance form. **Checksum it against the
  value AMD publishes.**
- **License:** Spartan-3E XC3S100E/250E are covered by the free **WebPACK**
  license. It's node-locked to a host ID. In a container, we fix the MAC address
  (`docker run --mac-address …`) and request the license for that MAC. Store
  `Xilinx.lic` outside the image and mount it read-only.
- **Don't use images or Dockerfiles that ship a bundled "all devices" license**
  (at least one public repo does). Use our own WebPACK license only.
- **Redistribution:** the resulting image contains AMD software. It stays on
  this Mac and is never pushed to a public registry.
- Command-line tools only. No GUI, so no XQuartz and none of the security
  holes that come with opening up X11.

### 3.2 Running amd64 on Apple Silicon
- Docker Desktop runs `linux/amd64` containers through **Rosetta** (fast) when
  "Use Rosetta for x86_64/amd64 emulation" is on, and falls back to
  **QEMU** (much slower, but more compatible) when it's off.
- Rosetta has known breakages with some amd64 binaries (docker/for-mac#7137).
  If an ISE tool crashes under Rosetta, the first thing to try is QEMU. For a
  design this small, QEMU's speed is acceptable.
- **Longevity:** Apple has said Rosetta 2 as a standalone component is phased
  down after macOS 27, but that **macOS 27 builds Intel binary translation
  directly into the OS, including for Linux VMs and containers**. That's good
  news for this plan, but check it again at each major macOS upgrade.
  QEMU emulation doesn't depend on Apple, so it remains the long-term
  fallback.

### 3.3 USB
- Docker Desktop on macOS has **no USB passthrough**. Programming happens on
  the host, and the container never sees the board.

### 3.4 Basys-2 specifics
- JTAG chain: position 0 is the FPGA (XC3S100E), position 1 is the
  **XCF02S** platform flash (non-volatile config).
- The board is the **XC3S100E** variant, so the part string is
  `xc3s100e-cp132-<speed>`. The plan assumes `-4`, but **confirm the speed
  grade from the chip marking** (the digit after the `-` in e.g.
  `XC3S100E-4CP132`).
- **Bitgen gotcha:** bitstreams loaded over JTAG need
  `-g StartUpClk:JtagClk`. Bitstreams meant for the XCF02S PROM need
  `-g StartUpClk:CClk`. Getting this wrong is the classic "programmed OK but
  nothing happens" problem.
- The Digilent Basys-2 master UCF is the starting point for pin constraints.

---

## 4. Prior art (for reference, not as dependencies)

We'll **write our own small Dockerfile** and not pull third-party images. That
fits the supply-chain preference and avoids license problems. These projects
are useful reading:

| Project | Useful for |
|---|---|
| [nospam2000/xilinx-ise-docker-mac](https://github.com/nospam2000/xilinx-ise-docker-mac) | Mac-specific layout, license workflow (generate request, then mount `Xilinx.lic`) |
| [gitlab: pmnmalo/xilinx-ise-in-docker-on-mac](https://gitlab.com/pmnmalo/xilinx-ise-in-docker-on-mac) | Explicitly targets Apple Silicon |
| [I-A-S/Docked-ISE-147](https://github.com/I-A-S/Docked-ISE-147) | Headless, CLI-only, `XILINXD_LICENSE_FILE` handling |
| [codepainters/ise14](https://github.com/codepainters/ise14) | Ubuntu 14.04 base (newer bases caused problems), `ise14_spawn`-style host wrappers; full image ~24.7 GB |
| [vmunoz82/ise14](https://github.com/vmunoz82/ise14) | Trimming ideas (drop 7-series ~3 GB, EDK/SDK ~5 GB, strace-based pruning); source of the 21.3 GB → 220 MB claim |
| [bowfinger.de: ISE 14.7 in Docker](https://bowfinger.de/blog/2022/07/running-xilinx-ise-14-7-in-docker/) | Notes on bundled-libstdc++ clashes |
| [chriz2600/xilinx-ise](https://github.com/chriz2600/xilinx-ise), [andreamerello/ise-docker](https://github.com/andreamerello/ise-docker) | Batch-install recipes |

---

## 5. Plan in phases

Each phase has an exit criterion. We don't move to the next phase until the
current one is met.

### Phase 0: Decisions and prerequisites (about 30 min)
- [x] Chip variant: **XC3S100E** (confirmed).
- [ ] Speed grade from the chip marking (`-4` assumed).
- [ ] Docker Desktop → Settings → General: confirm **"Use Rosetta for
      x86_64/amd64 emulation on Apple Silicon"** is on. Check that the virtual
      disk limit is **≥ 80 GB** (the build needs room for the installer,
      the full install and the intermediate layers).
- [ ] Choose a fixed, locally administered MAC for the container, e.g.
      `02:42:ac:15:e3:01`. Every ISE container uses this MAC.
- [x] FT4232H Mini Module (Rev 1.1): power jumper CN3-1↔CN3-3 and
      V3V3→VIO wire fitted. The module works from macOS with
      `openFPGALoader -c ft4232`, no `sudo` (2026-09-26). The JTAG wiring to
      the Basys-2 is next; see
      [docs/jtag-ft4232h-basys2.md](docs/jtag-ft4232h-basys2.md).

**Exit:** part number known, Docker settings confirmed, JTAG adapter
identified and seen by openFPGALoader.

### Phase 1: Get ISE and the license (1–2 h, mostly downloading)
- [ ] Download `Xilinx_ISE_DS_Lin_14.7_1015_1.tar` and verify its checksum.
      Keep it outside the repo (e.g. `~/Downloads/xilinx/`). Add `*.tar` and
      `*.lic` to `.gitignore`.
- [ ] Get a WebPACK license from the AMD licensing site, node-locked to the
      MAC chosen in Phase 0. Store it in `~/.config/xilinx/Xilinx.lic`.

**Exit:** verified tarball and a `.lic` file on disk.

### Phase 2: Build the full image `ise:14.7-full` (2–4 h, mostly unattended)
- Dockerfile outline:
  - `FROM --platform=linux/amd64 <base>@sha256:<digest>`. Pin the digest.
    Start with the base the prior art found to work (Ubuntu 14.04 or 16.04),
    because ISE's bundled libraries clash with newer distributions.
  - Install the handful of runtime libraries the CLI tools need (libncurses5,
    libxext/libxrender stubs where tools still link against them, etc.). Keep
    the list minimal and document why each one is there.
  - Run the ISE **batch installer** (`batchxsetup` with a config file, as in
    the prior-art Dockerfiles) for the **WebPACK** edition only. Deselect
    EDK/SDK, cable drivers and WebTalk wherever the installer allows.
  - Feed the tarball in through a **BuildKit bind mount**
    (`RUN --mount=type=bind,source=…`) so the 6 GB tarball never becomes an
    image layer.
  - Entrypoint script: `source /opt/Xilinx/14.7/ISE_DS/settings64.sh`, then
    `exec "$@"`.
- Build with `docker build --platform linux/amd64 -t ise:14.7-full .`
- Disk budget: tarball ~6 GB + full install ~15–20 GB + build cache. The 100
  GiB free is enough, but prune build cache afterwards.

**Exit:** `docker run --rm --platform linux/amd64 ise:14.7-full map -h`
prints help. The same holds for `ngdbuild`, `par`, `trce`, `bitgen` and `xst`.

### Phase 3: Known-good reference flow with XST (1–2 h)
Before bringing yosys in, prove that ISE works end to end with its own
synthesiser. That separates "the container is broken" from "the yosys EDIF is
wrong".
- [ ] Minimal design: a blinky (clock divider driving LD0) plus switches mapped
      to LEDs, using the Basys-2 UCF (50 MHz clock on pin B8).
- [ ] Run the flow inside the container:
      `xst` → `ngdbuild -p <part> -uc basys2.ucf` → `map` → `par -w` →
      `trce -v 10` → `bitgen -w -g StartUpClk:JtagClk`.
- [ ] Record the time per step under Rosetta. Also time one run with Rosetta
      off (QEMU) so we know the fallback's cost.
- [ ] Run every container with `--network none`. That confirms nothing needs
      to phone home, and WebTalk just fails quietly.

**Exit:** `blinky_xst.bit` produced, with timing met in the `trce` report.

### Phase 4: Host wrapper `bin/ise` (about 1 h)
A small POSIX shell script. No new dependencies.

```sh
#!/bin/sh
# Usage: bin/ise <tool> [args...]   e.g. bin/ise map -p xc3s100e-cp132-4 ...
exec docker run --rm \
  --platform linux/amd64 \
  --network none \
  --mac-address "${ISE_MAC:-02:42:ac:15:e3:01}" \
  -v "$PWD":/work -w /work \
  -v "$HOME/.config/xilinx/Xilinx.lic":/lic/Xilinx.lic:ro \
  -e XILINXD_LICENSE_FILE=/lic/Xilinx.lic \
  "${ISE_IMAGE:-ise:14.7-s3e}" "$@"
```

- Optional speed-up if container start-up proves slow: keep one long-running
  container and use `docker exec`. Measure first, then decide.
- Check file ownership and timestamps on the bind mount, because `make`
  depends on correct mtimes.

**Exit:** the Phase 3 flow runs from macOS via `bin/ise …` and produces the
same bitstream.

### Phase 5: Yosys front end (1–3 h, depending on how experimental xc3se turns out to be)
- Synthesis on the host:
  ```
  yosys -p "read_verilog top.v; synth_xilinx -family xc3se -ise -top top; write_edif -pvector bra top.edf"
  ```
- `bin/ise ngdbuild -p <part> -uc basys2.ucf top.edf top.ngd`, then the same
  back end as in Phase 3.
- Compare with the XST result: resource use in the map report, timing, and
  behaviour on the board.
- If ngdbuild rejects the EDIF or the design misbehaves:
  1. Check the flag choices against the yosys docs for the installed version.
  2. Check whether the problem is limited to specific primitives (e.g. block
     RAM or multipliers) and avoid inferring those.
  3. Otherwise, keep XST as the synthesiser for now. The container and
     Makefile work either way.

**Exit:** `top.bit` from the yosys path works on the board, or a documented
decision to use XST.

### Phase 6: Trim to `ise:14.7-s3e` (half a day, optional but satisfying)
Goal: a few hundred MB, containing only what the Spartan-3E CLI flow touches.
- **Record which files are used** during a full regression (XST and yosys
  paths; ngdbuild/map/par/trce/bitgen; both StartUpClk variants; an error
  case such as a bad UCF, so error-message files are included too):
  - First choice: `strace -f -e trace=file`. Rosetta's ptrace support is
    limited, so **run the trace with Rosetta off (QEMU)**.
  - Alternative: mount with `strictatime`, drop a timestamp marker, run the
    flow, then `find -anewer marker`.
- Build a **fresh multi-stage image**: `COPY --from=ise:14.7-full` only the
  listed files, plus the entrypoint and settings. Deleting files in a later
  layer doesn't shrink an image, which is why we copy into a fresh stage.
- Expect to keep things like `ISE/spartan3e/`, the shared `ISE/data/` files,
  `ISE/lib/lin64/`, and the parts of `common/` the tools load.
- Regression gate: the slim image has to produce **bit-identical `.bit`
  files** to the full image for every test design. Keep the full image (or at
  least its Dockerfile and the tarball) as the rebuild source.

**Exit:** the slim image passes the regression and `bin/ise` uses it by
default.

### Phase 7: Makefile and project template (1–2 h)
```make
PART  ?= xc3s100e-cp132-4
TOP   ?= top
ISE   := bin/ise

$(TOP).edf: $(wildcard rtl/*.v)
	yosys -q -p "read_verilog $^; synth_xilinx -family xc3se -ise -top $(TOP); write_edif -pvector bra $@"

$(TOP).ngd: $(TOP).edf basys2.ucf
	$(ISE) ngdbuild -quiet -p $(PART) -uc basys2.ucf $< $@

$(TOP)_map.ncd $(TOP).pcf: $(TOP).ngd
	$(ISE) map -w -p $(PART) -o $(TOP)_map.ncd $< $(TOP).pcf

$(TOP).ncd: $(TOP)_map.ncd $(TOP).pcf
	$(ISE) par -w $< $@ $(TOP).pcf

$(TOP).twr: $(TOP).ncd
	$(ISE) trce -v 10 -o $@ $< $(TOP).pcf

$(TOP).bit: $(TOP).ncd $(TOP).twr
	$(ISE) bitgen -w -g StartUpClk:JtagClk $< $@ $(TOP).pcf

sim:  ; iverilog -o sim.vvp tb/*.v rtl/*.v && vvp sim.vvp
OFL   ?= openFPGALoader                          # patched build for xc3s100e, see §8
prog: $(TOP).bit ; $(OFL) -c ft4232 $<
.PHONY: sim prog
```
Add a `make xst` target for the reference path and a `make flash` target for
the PROM (§8).

**Exit:** a fresh clone plus `make && make prog` gives a working board.

### Phase 8: Programming (runs alongside Phases 2–7; see §8)

---

## 6. Proposed repo layout

```
basys2-ise-container/
├── REPORT.md              ← this document
├── README.md              overview and doc index (quick start after Phase 7)
├── docs/
│   └── jtag-ft4232h-basys2.md   FT4232H → Basys-2 JTAG wiring and bring-up
├── .gitignore             *.tar, *.lic, build outputs (*.ngd, *.ncd, *.bit, …)
├── docker/
│   ├── Dockerfile.full    Phase 2
│   ├── Dockerfile.s3e     Phase 6 (multi-stage from full)
│   ├── install.cfg        batch-installer config
│   ├── entrypoint.sh
│   └── keep-list.txt      files the slim image keeps (generated, then committed)
├── bin/
│   └── ise                host wrapper
├── boards/basys2/
│   └── basys2.ucf
├── examples/blinky/
│   ├── rtl/top.v
│   ├── tb/top_tb.v
│   └── Makefile
└── tests/
    └── regress.sh         full vs slim bit-identical check
```

---

## 7. Risks and mitigations

| # | Risk | Likelihood | Mitigation |
|---|---|---|---|
| R1 | No macOS-native way to use the on-board USB | **High** (confirmed for xc3sprog and openFPGALoader) | FTDI JTAG adapter: the FT4232H mini module on hand, or buy one (§8, option A) |
| R2 | openFPGALoader lacks the **xc3s100e** IDCODE | **Applies**: the board is a 100E, and upstream `main` still lacks it (2026-09) | Add the one-line part-table entry and build locally (§8, "XC3S100E patch"), then send it upstream. Fallback: xc3sprog. |
| R3 | An ISE tool crashes under Rosetta | Medium | Turn Rosetta off → QEMU. Slower but more compatible. |
| R4 | Yosys `xc3se` EDIF isn't accepted or misbehaves | Medium (EXPERIMENTAL) | XST reference path from Phase 3 |
| R5 | License check fails in the container | Low–medium | Fixed `--mac-address`. Check the host ID from inside the container. Mount the license read-only. |
| R6 | Old base image vs Docker Desktop kernel/Rosetta (e.g. old glibc) | Low–medium | Try a newer base (16.04/18.04). ISE ships most of its own libraries. |
| R7 | Disk fills up during the build | Low | Bind-mount the tarball, prune build cache, raise the Docker disk limit in Phase 0 |
| R8 | macOS 28+ changes x86 translation | Future | Docs say macOS 27 integrates it. QEMU remains as a fallback. |
| R9 | Trimming breaks a rarely used code path | Medium | Bit-identical regression plus an error-path test. Keep the full image recipe. |
| R10 | Getting the ISE download (AMD account, export form) | Low | One-time step. Keep the verified tarball backed up. |

---

## 8. Programming the board from macOS

The container can't do this (no USB passthrough), so it happens natively.
Options, best first:

### Option A: FTDI JTAG adapter on the Basys-2 JTAG header (recommended)
Isabekov has written up the wiring and the xc3sprog/OpenOCD usage for
exactly this board.

#### A1: FTDI FT4232H Mini Module, already on hand (first choice)
The module on hand is FTDI's own **FT4232H Mini Module, PCB Rev 1.1
(©2010 FTDI Ltd)**, with a USB mini-B connector. That's exactly the board
drawn in FTDI's datasheet
[FT_000115, v1.8](https://web.archive.org/web/2016id_/http://www.ftdichip.com/Support/Documents/DataSheets/Modules/DS_FT4232H_Mini_Module.pdf)
(FTDI's own copy is
[here](https://ftdichip.com/wp-content/uploads/2020/07/DS_FT4232H_Mini_Module.pdf)).
All pin numbers below come from that datasheet, tables 3.1 and 3.2 and §3.

> **Step-by-step instructions** (wiring, checks, troubleshooting, progress):
> [docs/jtag-ft4232h-basys2.md](docs/jtag-ft4232h-basys2.md).

- **Nothing needs to be bought.** A 2.54 mm jumper shunt and a few
  **female–female** jumper wires are enough. Both the module and the Basys-2
  have male header pins.
- USB ID is 0403:6011 (it shows up in macOS as `FT4232H MiniModule`), which openFPGALoader
  already knows as cable **`-c ft4232`** (checked against the installed
  v1.1.1). Only channels A and B can do JTAG (via FTDI's MPSSE engine).
  **Use channel A.**
- **Headers:** CN2 and CN3 are 2×13 headers, 2.54 mm pitch, with pins
  pointing **down** from the underside. Pin 1 has the square pad. Odd pins
  (1, 3, 5, …) run along one row and even pins along the other.

**Step 1: power jumpers (USB bus-powered, 3.3 V I/O).** Without these the
FT4232H has no supply and its I/O pins are dead.

| Link | From | To | Why |
|---|---|---|---|
| J1 | CN3-1 (VBUS) | CN3-3 (VCC) | Feeds USB 5 V to the module's 3.3 V regulator. These pins sit next to each other in the same row, so a **jumper shunt** fits. |
| J2 | CN2-1/3/5 (V3V3) | **CN2-11, CN2-21, CN3-12, CN3-22** (VIO) | Powers the chip's I/O at 3.3 V. The VIO pins aren't next to V3V3, so this needs **wires**. The datasheet says to link all four VIO pins. |

If the module is plugged into a carrier or dev board, check first whether
that board already makes these links.

**Step 2: JTAG wiring to the Basys-2** (use the labels printed on the
Basys-2 next to its 6-pin JTAG header, not an assumed pin order):

| FT4232H Mini Module | Signal | Basys-2 JTAG |
|---|---|---|
| CN2-7  (AD0) | TCK | TCK |
| CN2-10 (AD1) | TDI | TDI |
| CN2-9  (AD2) | TDO | TDO |
| CN2-12 (AD3) | TMS | TMS |
| CN2-2  (GND) | GND | GND |
| (leave unconnected) | | VDD. Both boards are USB-powered, so don't tie their supplies together. |

Note that AD1 and AD2 are **not** in pin order: AD2 is on CN2-9 and AD1 is
on CN2-10.

**Step 3: bring-up checks, in order**
1. ✅ *(2026-09-26)* With both power links fitted and nothing on the JTAG
   pins, the module appears as `FT4232H MiniModule` (0403:6011, with a
   serial number). `openFPGALoader -c ft4232 --detect` exits with 0 and
   finds no devices, as expected. **No `sudo` needed.**
2. With the module unplugged, wire it to the Basys-2. Power the Basys-2 from
   its own USB, then plug in the module. `--detect` should now show the
   **XC3S100E** (IDCODE 0x?1C10093, "unknown" until the §8 patch) and the
   **XCF02S**.

**Lessons from bring-up (2026-09-26):**
- **Without the CN3-1↔CN3-3 jumper** the module doesn't appear on USB at all.
- **Without the V3V3→VIO link** it does appear on USB, but as
  `Quad RS232-HS` with no serial number (the settings EEPROM runs from VIO),
  and openFPGALoader fails with `usb bulk write failed`, **even with
  `sudo`**. So the VIO link is needed before anything else works, not just
  for driving the JTAG pins.
- macOS's built-in `com.apple.DriverKit-AppleUSBFTDI` attaches to all four
  channels and creates `/dev/cu.usbserial-*` ports, but it **doesn't** stop
  openFPGALoader from using channel A. No EEPROM PID change or driver
  unloading is needed.

#### A2: Buy an adapter (fallback if the FT4232H module doesn't work out)
- **Adafruit FT232H Breakout, USB-C (Adafruit #2264).** 229 SEK at
  [Electrokit](https://www.electrokit.com/en/adafruit-ft232h-breakout)
  (2026-09). Genuine FTDI chip, 3.3 V I/O, openFPGALoader cable `-c ft232`.
  Same wiring as above with D0–D3 in place of AD0–AD3. The header strip needs
  soldering.
- **Digilent JTAG-HS2 (410-249).** No wiring: it plugs straight into the
  Basys-2 6-pin header. 1.8–5 V targets, openFPGALoader cable
  `-c digilent_hs2`. About $53+ ([Trenz](https://www.trenz-electronic.de/en/24624-JTAG-HS2-Programming-Cable)).
- Avoid no-name FT232H clones, since counterfeit FTDI chips are common.
- Last resort: a 3.3 V FTDI TTL-serial cable (FT232R) can bit-bang JTAG over
  its serial lines. It's slow and fiddly, so only for emergencies.

#### Software (all Option A variants)
- **openFPGALoader** (already installed; uses libftdi on macOS). Replace
  `ft4232` below with `ft232` or `digilent_hs2` for the A2 adapters.
  - **This board is an XC3S100E, which openFPGALoader doesn't know yet**
    (it isn't in v1.1.1 or upstream `main` as of 2026-09). See the patch
    below.
  - Once patched: `openFPGALoader -c ft4232 --detect`, then
    `openFPGALoader -c ft4232 top.bit`.
  - Fallback: **xc3sprog**, which knows the 100E (`xc3sprog -c <cable> -j`,
    then `-p 0 top.bit`). It has no Homebrew formula, so it would be a source
    build against libftdi/libusb and an extra dependency. That's why patching
    openFPGALoader is the preferred route.
  - PROM (XCF02S, chain position 1): openFPGALoader knows `xcf02s`. Build a
    separate bitstream with `StartUpClk:CClk` for this.

#### XC3S100E patch for openFPGALoader
- openFPGALoader's `src/part.hpp` lists Spartan-3E parts next to each other:
  ```cpp
  /* Xilinx Spartan3 */
  {0x01414093, {"xilinx", "spartan3",  "xc3s200",  6}},
  {0x11c1a093, {"xilinx", "spartan3e", "xc3s250e", 6}},
  {0x01c22093, {"xilinx", "spartan3e", "xc3s500e", 6}},
  ```
  Add one entry, with IR length 6 like its siblings:
  ```cpp
  {0x01c10093, {"xilinx", "spartan3e", "xc3s100e", 6}},
  ```
- `0x01C10093` is the XC3S100E IDCODE from the Spartan-3E datasheet (DS312).
  openFPGALoader also retries a lookup with the version nibble masked off
  (`src/jtag.cpp`), so any silicon revision matches. **Check it against the
  real chip first:** before patching, `openFPGALoader -c ft4232 --detect`
  reports the unknown IDCODE it read.
- Build it locally with CMake. It uses the same libftdi/libusb that the
  Homebrew install already pulled in, so no new dependencies. Keep it out of
  `/opt/homebrew`, e.g. in `~/.local/bin`, or use it straight from the build
  directory. Point the Makefile's `prog` target at it with `OFL ?=`.
- Send the patch upstream as a PR. Once it's released, go back to the
  Homebrew build.
- The Spartan-3E family is already supported (xc3s250e and xc3s500e, and
  Papilio One is listed as working), so the new entry shouldn't need any
  other code changes. Verify by loading a blinky over JTAG.
- **Why first:** deterministic, fully native, no closed firmware, fast. The
  same setup also works for other boards later.

### Option B: on-board USB with open FX2 firmware (stretch goal)
- The Basys-2's USB chip is a Cypress FX2. You can load open **ixo-usb-jtag**
  firmware into its RAM (e.g. with `cycfx2prog` or `fxload` over libusb) so it
  shows up as an Altera **USB-Blaster**, which openFPGALoader supports as
  `-c usb-blaster`.
- The firmware only lives in RAM and **goes away on power-cycle**, so it
  can't brick the board.
- Catch: ixo-usb-jtag has variants for the Nexys 1/2 and Atlys, **but not the
  Basys-2**. You'd need the Basys-2's FX2-to-JTAG pin mapping and a custom
  build of the firmware. That's fun, but it's a project in itself.

### Option C: Digilent Adept `djtgcfg` in a small Linux VM (fallback)
- Digilent publishes Adept Runtime and Utilities for **Linux arm64**, and
  `djtgcfg` supports the Basys-2's on-board USB. An arm64 Linux VM (UTM or
  similar) with USB passthrough runs this natively, without x86 emulation.
- Whether Digilent offers a native macOS/Apple Silicon build of the Utilities
  is **unverified**. Their site blocked automated fetching, so check by hand.
- Cost: a VM to maintain just for programming. Only worth it if A and B are
  both off the table.

**Recommendation:** use the FT4232H mini module you already have
(Option A1). Only buy an adapter (A2) if that doesn't work out. Keep Option B
as a weekend experiment.

---

## 9. Open questions for Ben

1. ~~XC3S100E or XC3S250E?~~ **XC3S100E.** openFPGALoader needs the one-line
   patch from §8. Still open: the speed grade (`-4` assumed).
2. ~~Is there an FTDI adapter around already?~~ Yes: an **FTDI FT4232H Mini
   Module, Rev 1.1** is on hand (Option A1, pinout from the datasheet). Only
   a jumper shunt and female–female jumper wires are needed.
3. Should the flow ever include the ISE GUI or iMPACT? The plan assumes **no**
   (CLI only, no XQuartz).
4. Is XST acceptable as the permanent synthesiser if yosys `xc3se` turns out
   to be flaky, or is a fully FOSS front end a hard requirement?

---

## 10. Sources

- Container prior art:
  [nospam2000/xilinx-ise-docker-mac](https://github.com/nospam2000/xilinx-ise-docker-mac),
  [pmnmalo/xilinx-ise-in-docker-on-mac](https://gitlab.com/pmnmalo/xilinx-ise-in-docker-on-mac),
  [I-A-S/Docked-ISE-147](https://github.com/I-A-S/Docked-ISE-147),
  [codepainters/ise14](https://github.com/codepainters/ise14),
  [vmunoz82/ise14](https://github.com/vmunoz82/ise14),
  [chriz2600/xilinx-ise](https://github.com/chriz2600/xilinx-ise),
  [andreamerello/ise-docker](https://github.com/andreamerello/ise-docker),
  [bowfinger.de blog](https://bowfinger.de/blog/2022/07/running-xilinx-ise-14-7-in-docker/)
- Yosys Xilinx techlib (xc3se EXPERIMENTAL, `-ise`, EDIF):
  [Yosys docs](https://yosyshq.readthedocs.io/projects/yosys/en/stable/cmd/index_techlibs_xilinx.html),
  [Hackaday: Yosys fronts for Xilinx ISE](https://hackaday.com/2019/12/13/yosys-fronts-for-xilinx-ise/)
- Rosetta / amd64 containers:
  [apple/container discussion #1679](https://github.com/apple/container/discussions/1679),
  [apple/container issue #76](https://github.com/apple/container/issues/76),
  [docker/for-mac#7137](https://github.com/docker/for-mac/issues/7137)
- Programming:
  [openFPGALoader cables](https://trabucayre.github.io/openFPGALoader/compatibility/cable.html),
  [openFPGALoader boards](https://trabucayre.github.io/openFPGALoader/compatibility/board.html),
  [Isabekov: Basys2 + xc3sprog + FTDI](https://www.isabekov.pro/programming-basys2-using-xc3sprog-ftdi-based-jtag-adapter/),
  [Isabekov: FTDI adapter wiring for Basys2](https://www.isabekov.pro/connecting-external-ftdi-based-jtag-adapter-basys2-fpga-board/),
  [Isabekov: Basys2 + OpenOCD](https://www.isabekov.pro/programming-basys2-using-openocd-ftdi-based-jtag-adapter/),
  [FTDI FT4232H Mini Module datasheet FT_000115 v1.8](https://ftdichip.com/wp-content/uploads/2020/07/DS_FT4232H_Mini_Module.pdf) ([archived copy](https://web.archive.org/web/2016id_/http://www.ftdichip.com/Support/Documents/DataSheets/Modules/DS_FT4232H_Mini_Module.pdf)),
  [mithro/ixo-usb-jtag](https://github.com/mithro/ixo-usb-jtag),
  [embed-dsp/ed_digilent_adept](https://github.com/embed-dsp/ed_digilent_adept),
  [Digilent Basys 2 reference manual](https://digilent.com/reference/programmable-logic/basys-2/reference-manual)
