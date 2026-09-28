# basys2-ise-container

Developing for a **Digilent Basys-2 (Spartan-3E XC3S100E)** from an
**Apple Silicon Mac**, with no Windows machine:

- Native macOS: yosys and iverilog for synthesis and simulation,
  openFPGALoader for programming.
- **Xilinx ISE 14.7** back end (ngdbuild/map/par/bitgen) in a `linux/amd64`
  Docker container, run through Rosetta.

## Documents

| Doc | What |
|---|---|
| [REPORT.md](REPORT.md) | The plan: architecture, phases, risks, programming options |
| [docs/jtag-ft4232h-basys2.md](docs/jtag-ft4232h-basys2.md) | Step by step: FT4232H Mini Module as a JTAG adapter for the Basys-2 (wiring, checks, troubleshooting) |
| [docs/basys2-board.md](docs/basys2-board.md) | Ben's Basys-2 (Rev D): photos, jumpers, power and voltage checks, and the missing FPGA JTAG header |
| [docs/programming-options.md](docs/programming-options.md) | Decision input: how to program the Rev D board from macOS (adepttool, djtgcfg in a VM, soldered JTAG, new USB firmware) |
| [docs/data-inventory.md](docs/data-inventory.md) | What's in the gitignored `data/`: old 2013–2015 Basys-2 VHDL projects, bitfiles, reference PDFs |

## Status

- Plan written. The ISE container isn't built yet.
- JTAG adapter: the module is powered and works from macOS. Wiring to the
  Basys-2 is next.

The ISE installer and license files are AMD's and are never committed (see
`.gitignore`).
