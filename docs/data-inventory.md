# `data/`: old Basys-2 VHDL archives (not in git)

`data/` holds Ben's Basys-2 work from 2013–2015 plus reference material. It
is gitignored: it's about 284 MB, and much of it is third-party (Xilinx and
Digilent docs, book code, magazine articles). This page records what's there
so it can be found and pulled out later, when real Basys-2 work starts.

Surveyed 2026-09-27. Nothing has been built or simulated from it yet.

## The archives

The archives are the originals. The extracted folders next to them can be
recreated at any time:

```sh
cd data
mkdir -p nand2tetris vhdl-2013-rar vhdl-zip
bsdtar -xf nand2tetris_001zip.zip -C nand2tetris
bsdtar -xf "vhdl archive 2013 apr 16.rar" -C vhdl-2013-rar   # macOS bsdtar reads rar
bsdtar -xf vhdl-20260927T165102Z-1-001.zip -C vhdl-zip
```

| Archive | Size | Extracted to |
|---|---|---|
| `nand2tetris_001zip.zip` | 2.0 MB | `nand2tetris/` |
| `vhdl archive 2013 apr 16.rar` | 7.7 MB | `vhdl-2013-rar/` |
| `vhdl-20260927T165102Z-1-001.zip` (Google Drive export) | 90 MB | `vhdl-zip/` |

SHA-256 (`shasum -a 256 data/*.zip data/*.rar`):

```
01a2037185dfe14de4031cb520c19db59daefd6d16fbea6ca67f374a5b34e339  nand2tetris_001zip.zip
7420839d1171b04f9aaf3ced1b107e0ee57f379d78402d9158e7bcfc48885f6e  vhdl-20260927T165102Z-1-001.zip
7d2afcc9eac42dd804d5e7f74d3316c43ae015a74c0523b564f6f9eb138dccd6  vhdl archive 2013 apr 16.rar
```

## Key facts

- **Same chip as this repo.** Every one of Ben's projects targets
  `xc3s100e-cp132` and was made with ISE 14.4, so the `.xise` files should
  open in ISE 14.7.
- **Everything is VHDL.** The yosys/iverilog flow in REPORT.md handles only
  Verilog. VHDL needs XST (inside the ISE container) or GHDL plus
  ghdl-yosys-plugin. About 235 files use `std_logic_unsigned`/`std_logic_arith`,
  so GHDL needs `-fsynopsys`.
- **File dates in the Drive zip are all 2015-03-16.** Those are copy dates,
  not when the files were written. The rar keeps the real 2013 dates.
- **Most of the volume is clutter:** ISE build outputs (`_xmsgs/`, `xst/`,
  `_ngo/`, `*.ngc`, `*.ncd`), ISim folders, generated IP-core simulation
  files, and an old `.svn/` folder.

## Ready-made bitfiles (JTAG first-light candidates)

These can be loaded with openFPGALoader before the ISE container exists:

| File | What |
|---|---|
| `vhdl-zip/vhdl/basys2/src/Basys2UserDemo/Basys2UserDemo/BitFilesBasys2UserDemo/basys2_100userdemoJtagClk.bit` | Digilent's factory demo, **JTAG startup clock**: the right one for loading over JTAG |
| `…/BitFilesBasys2UserDemo/basys2_100userdemoCClk.bit` | Same demo, CCLK startup (for the PROM) |
| `vhdl-zip/vhdl/Switches_LEDS/switches_leds.bit` (also `_Module_3`, `_Module_4`) | Switches drive LEDs |
| `vhdl-zip/vhdl/Xilinx/vga/MyVGA/myvga.bit` | VGA output (`OwnVGA.vhd`) |

The source for the Digilent demo is in `…/UncompiledBasys2UserDemo/`, with its
UCF `Basys2Bist.ucf`, which is a good reference for pin locations.

## nand2tetris (Hack computer on the Basys-2)

There are seven copies. From oldest to newest:

| Copy | Newest `.vhd` | Notes |
|---|---|---|
| `nand2tetris/` (the 001 zip) | 2013-03-26 | 58 `.vhd`, gate-level chips (nand, mux, adders, …) |
| `vhdl-2013-rar/vhdl archive 2013 apr 16/nand2tetris/` | 2013-04-01 | Almost the same; `b_cpu.vhd` differs |
| `vhdl-2013-rar/vhdl archive 2013 apr 16/nand2tetris_02/` | 2013-04-12 | Adds the 7-segment `screen` |
| `vhdl-2013-rar/nand2tetris_03/` | 2013-04-15 | 42 `.vhd` |
| **`vhdl-zip/vhdl/projects/nand2tetris/src/nand2tetris/`** | latest | **Use this one.** 21 `.vhd`, behavioral |
| `vhdl-zip/vhdl/projects2014/nand2tetris/` | latest | Same source as above, plus build outputs |
| `vhdl-zip/vhdl/projects/nand2tetris/src/nand2tetris_VGA/` | latest | Same design with comments removed; **no VGA code** |

The latest design (`b_computer.vhd`, top `b_computer`) is built from:

- the Hack CPU (`b_cpu`, `b_alu`, `b_decode`, `b_PC`, `b_register`)
- a 1K × 16 ROM and a 2K × 16 dual-port RAM, both Block Memory Generator 7.3
  cores (`ipcore_dir/b_rom1024`, `b_ram2048`); ROM and RAM clock on the
  falling edge
- a 7-segment display (`screen`) that shows `RAM[sw]` through the RAM's
  second port
- `pcOUT[5:0]`, `clkOUT` and `resetOUT` on the expansion pins
  (`pins.ucf`), for a logic analyzer

Gotchas:

- `f_5Mz` is **not** 5 MHz. It toggles every 27 cycles of the 50 MHz clock,
  which gives about 0.93 MHz. The UCF sets `CLOCK_DEDICATED_ROUTE = FALSE` on
  `mclk` because of this divider.
- The `.xco` files point at `C:\Users\Bengt\Dropbox\vhdl\nand2tetris_02\tests\*.coe`.
  Fix the paths before regenerating the cores. The `.coe` files are in
  `vhdl-zip/vhdl/projects2014/tests/tests/`, and `.mif` files are in
  `ipcore_dir/`.
- The ROM program is `tests/tests/test001.asm`, which exercises every jump
  instruction. When it passes, RAM[0..8] holds `5, -5, 1, 1, 1, 1, 1, 1, 1`,
  which can be checked with SW0–SW3 on the display.

Test tooling in `vhdl-zip/vhdl/projects2014/tests/`:

- `python_scripts/`: scripts that turn nand2tetris `.cmp` files into VHDL
  `wait`/`assert` code for testbenches, plus `rom1024generator.py` and a
  stimulus generator for the whole computer
- `projects/00`–`15`: the nand2tetris course projects, with Ben's Python
  tools: `06 assembler/Assembler.py`, `08 vm translator/VMtranslator.py`,
  `10/JackAnalyzer.py` and `11 compiler/JackCompiler.py`

## Smaller projects (`vhdl-2013-rar/vhdl archive 2013 apr 16/`, unless noted)

Good candidates for trying out the ISE container with XST:

| Project | Size | What |
|---|---|---|
| `Switches_LEDS`, `Switches_LEDs_Module_3`, `_Module_4` (Drive zip) | ~45 lines | Tutorial: switches to LEDs. Smallest test case |
| `switch_7seg` | 44 lines | Switches to 7-segment |
| `BidirectionalShiftRegister` | 185 lines | Shift register and clock divider |
| `Kronometer`, `2`, `3`, `4`, `kronometer5` | 290–520 lines | Stopwatch on the 7-segment display, in successive versions |
| `DigitalClock` | 700 lines | Clock with an FSM |
| `screen01`, `screen02` | 460–800 lines | 7-segment display driven from RAM |
| `experimenal20030325`, `experimental0412/0413/0415` | 60–150 lines | Clock-manager (DCM) and divider experiments |
| `Xilinx/vga/MyVGA` (Drive zip) | 132 lines | 640×480@60 VGA timing and color output (`OwnVGA.vhd`) |

## Reference documents (`vhdl-zip/vhdl/`)

| Path | What |
|---|---|
| `basys2/manual/Basys2_rm.pdf` | Basys-2 reference manual |
| `basys2/schematic/Basys2_sch.pdf` | Basys-2 schematic |
| `basys2/src/VGA RefComp/` | Digilent VGA reference component |
| `Xilinx/Spartan 3E/ds312 (data sheet).pdf` | Spartan-3E data sheet |
| `Xilinx/Spartan 3E/ug331 (user guide).pdf`, `ug332 (configuration user guide).pdf` | Spartan-3E user and configuration guides |
| `Xilinx/devref.pdf` | Command Line Tools User Guide (xst, ngdbuild, map, par, bitgen), for Phases 3–4 |
| `Xilinx/Data2MEM user Guide.pdf`, `Reprogramming of block RAM Memory.pdf` | Swapping block-RAM contents in a `.bit` without re-synthesis; useful for loading new Hack programs |
| `Xilinx/ISE In-Depth Tutorial/`, `ISim In-Depth Tutorial/`, `ISim User Guide.pdf`, `Writing Efficient Testbenches.pdf` | Tool tutorials |
| `docs/vhdl_math_tricks_mapld_2003.pdf` | VHDL arithmetic (numeric_std) |
| `docs/tutorials/All Programmable Planet/` | Max Maxfield's "Discovering FPGAs" article series (third-party) |
| `docs/Fundamentals of digital logic/VHDL_code/` | Code from Brown & Vranesic's textbook (third-party) |
