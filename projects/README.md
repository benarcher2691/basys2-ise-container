# Verilog projects for the Basys-2

Two designs, written for learning: every module has a header comment
explaining what it does and why, and the code comments explain the
details.

| Project | What it is | Size (XST) |
|---|---|---|
| [`kronometer/`](kronometer/) | Stopwatch on the 7-segment display | 64 slices |
| [`hack/`](hack/) | The Hack computer from nand2tetris: CPU, program ROM, data RAM | 144 slices, 3 block RAMs |
| [`vga/`](vga/) | Three colour bars on a VGA monitor, 640 x 480 at 60 Hz | 35 slices |
| [`textmode/`](textmode/) | 40 x 30 characters of uppercase text on VGA, white on blue, blinking cursor | 63 slices, 2 block RAMs |
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

## vga

Red, green and blue bars on a VGA monitor (connect one to the board's VGA
connector), 640 x 480 at 60 Hz. The Verilog version of Ben's 2010 `MyVGA`
(the original is in `legacy/myvga/`).

Files:
- `rtl/vga_timing.v`: the reusable part, counting pixels and lines and making
  the hsync and vsync pulses; the starting point for any VGA picture,
  including a screen for the Hack computer
- `rtl/vga_colorbars.v`: the top level: 25 MHz pixel enable, and the colour
  chosen from the x position
- `tb/vga_colorbars_tb.v`: simulates two full frames at 50 MHz and checks the
  line and frame lengths, sync pulses, back porch, bar widths and order, and
  that everything outside the picture is black

## textmode

40 columns x 30 rows of text on a VGA monitor: each character is an 8 x 8
glyph from a character map, drawn at 16 x 16 pixels. The text comes from
`mem/screen.txt` (edit it and run `make prog`; lowercase is shown as
uppercase). The idea Ben planned in 2010 but never finished.

Files:
- `rtl/vga_text.v`: the top level: from pixel position to character cell,
  character to glyph row, glyph row to pixel, as a 3-stage pipeline; the
  blinking cursor
- `rtl/text_ram.v`: the screen, one ASCII code per cell (1200 cells, one
  block RAM), with a write port ready for a CPU
- `rtl/char_rom.v`: the character map, 64 glyphs (space to `_`)
- `../vga/rtl/vga_timing.v`: the VGA timing, shared with `vga/`
- `mem/screen.txt`: the text; `tools/make_screen.py` turns it into
  `build/screen.hex`
- `mem/font.hex`, `mem/font.txt`: the character map, as plain hex and with a
  picture of each glyph; made by `tools/make_font.py` from
  `fonts/font8x8_basic.h` (font8x8 by Daniel Hepper, public domain, based on
  the public domain IBM VGA fonts, https://github.com/dhepper/font8x8)
- `tb/vga_text_tb.v`: reads the picture from the VGA outputs like a monitor,
  checks all 307,200 pixels of two frames (cursor off and on) against its
  own reference model, and saves the second frame as `build/frame.ppm`

Characters outside space..`_` (0x20..0x5F) are folded: 0x60..0x7F show as
0x40..0x5F (so `a` shows `A`, but also `|` shows `<`), anything else as a space.
