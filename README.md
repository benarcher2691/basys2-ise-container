# basys2-ise-container

Developing for a **Digilent Basys-2 (Spartan-3E XC3S100E)** from an
**Apple Silicon Mac**, with no Windows machine:

- Native macOS: yosys and iverilog for synthesis and simulation, and
  `bin/basys2` (open-source adepttool) for programming through the board's
  own USB.
- **Xilinx ISE 14.7** back end (ngdbuild/map/par/bitgen) in a `linux/amd64`
  Docker container, run through Rosetta.

## Documents

| Doc | What |
|---|---|
| [REPORT.md](REPORT.md) | The plan: architecture, phases, risks, programming options |
| [docs/jtag-ft4232h-basys2.md](docs/jtag-ft4232h-basys2.md) | Step by step: FT4232H Mini Module as a JTAG adapter for the Basys-2 (wiring, checks, troubleshooting) |
| [docs/basys2-board.md](docs/basys2-board.md) | Ben's Basys-2 (Rev D): photos, jumpers, power and voltage checks, and the missing FPGA JTAG header |
| [docs/ise-container.md](docs/ise-container.md) | Building the ISE 14.7 container: download, build, smoke test, licence |
| [docs/programming-options.md](docs/programming-options.md) | Decision input: how to program the Rev D board from macOS (adepttool, djtgcfg in a VM, soldered JTAG, new USB firmware) |
| [docs/data-inventory.md](docs/data-inventory.md) | What's in the gitignored `data/`: old 2013–2015 Basys-2 VHDL projects, bitfiles, reference PDFs |

## Report

[`report/`](report/) is an educational report for senior high school
students: the Hack computer, its origin and principles, and (to come) how it
is built on the FPGA. One Markdown file per chapter in `report/chapters/`;
`report/build.sh` makes `report/out/report.html` (a single web page) and
`report/out/report.pdf` (needs `brew install pandoc tectonic`).

## Everyday use

```sh
make -C examples/blinky              # build with ISE in the container (~4 min)
make -C examples/blinky prog         # load into the FPGA over USB (lost at power-off)
make -C examples/blinky flash        # write to the flash: survives power-off (JP3 on ROM)
make -C examples/blinky SYNTH=yosys  # yosys instead of XST (Verilog only)
make -C boards/basys2 factory        # put the factory demo back in the flash
make -C boards/basys2 verify-factory # check the flash holds the factory demo (read-only)
bin/basys2 detect | reload           # show the JTAG chain / reload the FPGA from flash
```

New projects: a Makefile with `TOP`, `SRCS` (and optionally `UCF`, `CORES`,
`TB` for `make sim`) that includes `mk/ise.mk`.

**[`projects/`](projects/README.md)** has the Verilog designs, written for
learning and heavily commented: `kronometer` (stopwatch), `hack` (the
nand2tetris Hack computer: CPU, ROM, RAM), `vga` (colour bars on a VGA
monitor) and `textmode` (40 x 30 characters of text on VGA), each with
testbenches
(`make sim`). `legacy/` keeps the original 2013–15 VHDL.

## Status

- ISE container `ise:14.7-full` is built (from AMD's ISE 14.7 VM download)
  and runs through `bin/ise`, with the WebPACK licence mounted from
  `~/.config/xilinx/`. **End to end works (2026-09-28):**
  `make -C examples/blinky` (about 4 min) then `make -C examples/blinky prog`.
- `make flash` writes a design to the board's flash so it survives
  power-off; `make -C boards/basys2 factory` puts the factory demo back
  (see [docs/programming-options.md](docs/programming-options.md#writing-the-flash-xcf02s-added-2026-09-28)).
- Ben's 2013–15 VHDL builds unchanged: `legacy/kronometer5` (stopwatch) and
  `legacy/nand2tetris` (Hack computer, with block-RAM cores).
- yosys front end works for Verilog (`SYNTH=yosys`, REPORT.md Phase 5).
- Slim image `ise:14.7-s3e`: **651 MB** on disk (158 MB compressed) instead of
  17.3 GB, with bit-identical
  results (REPORT.md Phase 6). `bin/ise` uses it by default.
- Programming works (2026-09-28): `bin/basys2 prog file.bit` loads the
  Basys-2 FPGA from macOS over its own USB. No adapter or VM is needed.
  `bin/basys2 detect` lists the board and its JTAG chain.

The ISE installer and license files are AMD's and are never committed (see
`.gitignore`).
