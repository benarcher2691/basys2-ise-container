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

## Status

- ISE container `ise:14.7-full` is built (from AMD's ISE 14.7 VM download)
  and runs through `bin/ise`. `examples/blinky` synthesises; `map` onwards
  needs the free WebPACK licence for host ID `0242AC15E301`. Steps are in
  [docs/ise-container.md](docs/ise-container.md#4-licence-needed-for-map-par-bitgen).
- Programming works (2026-09-28): `bin/basys2 prog file.bit` loads the
  Basys-2 FPGA from macOS over its own USB. No adapter or VM is needed.
  `bin/basys2 detect` lists the board and its JTAG chain.

The ISE installer and license files are AMD's and are never committed (see
`.gitignore`).
