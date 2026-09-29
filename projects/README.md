# Verilog projects for the Basys-2

Two designs, written for learning: every module has a header comment
explaining what it does and why, and the code comments explain the
details.

| Project | What it is | Size (XST) |
|---|---|---|
| [`kronometer/`](kronometer/) | Stopwatch on the 7-segment display | 64 slices |
| [`hack/`](hack/) | The Hack computer from nand2tetris: CPU, program ROM, data RAM | 144 slices, 3 block RAMs |
| [`common/`](common/) | Modules both use: input synchronizer, 7-segment decoder and display driver | – |

The original 2013–15 VHDL versions are in [`../legacy/`](../legacy/).

## Commands

Run these in a project directory (`cd projects/hack`):

```sh
make sim      # simulate with Icarus Verilog; the testbenches print PASS or FAIL
make          # build the bitstream with ISE in the container (~4 min)
make prog     # load it into the FPGA (lost at power-off)
make flash    # write it to the flash so it starts at power-on (JP3 on ROM)
make SYNTH=yosys   # the same, synthesized with yosys instead of XST
```

yosys builds both: `kronometer` in 149 slices (XST: 64) and `hack` in
243 slices plus 3 block RAMs (XST: 144). XST gives smaller results;
Spartan-3E support in yosys is still marked experimental.

`make -C ../../boards/basys2 factory` puts Digilent's factory demo back in
the flash.

## kronometer

The display shows `M.SS.t` (minutes, seconds, tenths).

| Button | Action |
|---|---|
| BTN3 | start / continue |
| BTN2 | stop (pause) |
| BTN0 | reset to 0.00.0 |

Files:
- `rtl/kronometer.v`: the top level (buttons, control, 10 Hz tick, display)
- `rtl/bcd_counter.v`: one decimal digit; four of them chained make the time
- `tb/kronometer_tb.v`: runs the stopwatch on a scaled-down clock and checks
  start, pause, resume, reset, the 9.59.9 → 0.00.0 wrap and the display

## hack

A single-cycle 16-bit CPU with 1K words of program ROM and 2K words of RAM,
running a Hack program from a `.hack` file.

| Control | Action |
|---|---|
| BTN0 | reset: hold to stop at address 0, release to run the program from the start |
| SW3..SW0 | RAM address to show on the display (in hex) |
| SW7 | speed: down = 1 MHz, up = 2 instructions per second (watch the LEDs) |
| LD7..LD0 | program counter, low 8 bits |

With the default program `programs/test001` the display should show:

| SW3..SW0 | Display | Meaning |
|---|---|---|
| 0000 | `0005` | a = 5 |
| 0001 | `FFFB` | b = −5 |
| 0010 … 0111 | `0001` | the six jump tests (<, ≤, >, ≥, =, ≠) passed |
| 1000 | `0008` | not written by the program; initial value from `mem/ram_init.hack` |
| 1001 | `002A` | 42: the program reached its end |

The LEDs show `0110110x` (108/109): the program's final endless loop.

Files:
- `rtl/hack_computer.v`: the top level (board I/O, CPU clock enable, memories)
- `rtl/hack_cpu.v`: the CPU (registers, instruction decoding, jumps, PC)
- `rtl/hack_alu.v`: the ALU
- `rtl/hack_rom.v`, `rtl/hack_ram.v`: memories, initialized from files
- `programs/test001.asm`, `.hack`: the jump test program
- `mem/ram_init.hack`: initial RAM contents (0, 1, …, 9)
- `tools/assembler.py`: the Hack assembler
- `tb/hack_alu_tb.v`: checks all 18 ALU functions
- `tb/hack_computer_tb.v`: runs test001 on the whole computer and checks the RAM

### Running your own program

Write `programs/myprog.asm` in Hack assembly, then:

```sh
make PROGRAM=programs/myprog.hack prog   # assembles, builds (~4 min), loads
```

The program is part of the bitstream (block RAM contents), so a new program
means a new ISE build.
