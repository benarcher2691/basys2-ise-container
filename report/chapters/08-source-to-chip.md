# From source code to a running chip

How does a folder of Verilog files become a working computer on the board?
Several programs, called the **toolchain**, work in sequence. This chapter
follows the Hack computer through each step, with the real numbers from its
build.

## The flow

```
  Verilog source (.v)          you write this
        |
        |  simulation (Icarus Verilog)    does it behave correctly?
        v
  synthesis (XST or yosys)     Verilog -> netlist of LUTs, flip-flops, RAMs
        |
        v
  translate (ngdbuild)         + constraints: which signal goes to which pin
        |
        v
  map                          netlist -> the FPGA's slices and blocks
        |
        v
  place & route (par)          where on the chip, and which wires connect them
        |
        v
  timing analysis (trce)       is it fast enough for the clock?
        |
        v
  bitgen                       -> bitstream (.bit), about 72 KB
        |
        v
  programming (bin/basys2)     over USB into the FPGA, or into the flash chip
```

In this project a single command runs everything from synthesis to the
bitstream:

```sh
cd projects/hack
make sim      # simulate first
make          # synthesis ... bitstream  (about 4 minutes)
make prog     # load it into the FPGA
```

## Synthesis: from description to netlist

**Synthesis** reads the Verilog and works out a circuit that behaves as
described, built from the kinds of blocks the FPGA has: LUTs, flip-flops,
carry logic, block RAMs. The result is a **netlist**, a list of components
and the connections ("nets") between them.

Synthesis is where descriptions become hardware. The synthesis tool
recognises common patterns: the `+` in the ALU becomes an adder using the
FPGA's carry chain, the `? :` operators become multiplexers in LUTs, and the
memory arrays with `$readmemb` become block RAMs. Its report for the Hack
computer says, among other things:

```
Found 1024x16-bit ROM for signal <...>
Found 2048x16-bit dual-port RAM <Mram_memory> for signal <memory>.
The RAM <ram/Mram_memory> will be implemented as a BLOCK RAM
```

This project can use two synthesis tools: **XST**, part of Xilinx ISE, and
**yosys**, an open-source tool. Both produce working computers; XST's result
is smaller:

| Synthesis | Slices | Block RAMs | Fastest clock |
|---|---|---|---|
| XST | 144 | 3 | 66 MHz |
| yosys | 243 | 3 | 55 MHz |

## Constraints: connecting to the board

The netlist knows the computer has an input called `mclk` and outputs called
`led[7:0]`, but not which pins of the chip these are. That information comes
from the **constraints file** (`boards/basys2/basys2.ucf`), written from the
board's schematic:

```
NET "mclk" LOC = "B8";
NET "mclk" TNM_NET = "mclk";
TIMESPEC "TS_mclk" = PERIOD "mclk" 20 ns HIGH 50%;

NET "led<0>" LOC = "M5";
NET "sw<0>"  LOC = "P11";
```

`LOC` fixes a signal to a pin. The `PERIOD` line is a **timing constraint**:
it tells the tools that the clock has a period of 20 ns (50 MHz), so they
must make every path between two flip-flops faster than that.

## Map, place and route

**Map** packs the netlist into the FPGA's actual resources, for example
two LUTs and two flip-flops per slice. Its report is the best summary of
how big the design is:

```
Number of occupied Slices:            144 out of     960   15%
Number of bonded IOBs:                 33 out of      83   39%
Number of RAMB16s:                      3 out of       4   75%
```

**Place and route** (`par`) then decides *where* on the chip each slice goes,
and *which wires* of the routing network connect them. This is a huge
puzzle, solved with clever search algorithms. It is the slowest step for
large designs, and good placement keeps related logic close together so the
wires stay short and fast.

## Timing: is it fast enough?

Signals take time to travel through LUTs and wires. The **timing
analyser** (`trce`) finds the slowest path between two flip-flops, the
*critical path*, and checks it against the clock period:

```
Timing errors: 0  Score: 0
Minimum period:  15.014ns (Maximum frequency:  66.604MHz)
```

The slowest path takes 15 ns, which is shorter than the clock period of
20 ns, so the design works at 50 MHz with 5 ns to spare. In the Hack
computer, the critical path is a whole instruction's worth of logic: it
starts at the ROM's output (the instruction), goes through the decoding, the
ALU's adder and the zero/negative flags, and ends at the jump decision that
loads the program counter. That is 10 levels of logic, one after another.

> **Think about it.** The CPU only executes an instruction every 50 clock
> cycles, but the timing analyser still checks that the ALU finishes within
> one cycle. Why is it right to be this strict? (Hint: the tools don't know
> about `cpu_ce`.)

## The bitstream

Finally, **bitgen** writes the configuration of every LUT, flip-flop,
routing switch and block RAM into the **bitstream**: `hack_computer.bit`,
72 748 bytes. The program from the ROM is inside it, as the initial contents
of a block RAM.

One option matters here: the FPGA's start-up sequence needs a clock, and the
bitstream says which one to use. For loading over USB it is the JTAG clock
(`StartUpClk:JtagClk`); for starting from the flash chip it is the
configuration clock (`CClk`). `make` builds the first kind and `make flash`
the second.

## Programming the board

The last step sends the bitstream to the FPGA over USB. The board's USB
controller runs Digilent's firmware, which turns USB messages into JTAG
signals. The project uses **adepttool**, a small open-source program, to
talk to it:

```
$ make prog
...
JSTART
STATUS: ISC_DONE, INIT_B, DONE
```

`DONE` is a pin (and a status bit) that the FPGA raises when the
configuration has been loaded and checked. From that moment the Hack
computer is running.

`make flash` instead writes the bitstream into the XCF02S flash chip, so the
computer starts by itself every time the board is switched on. Writing the
flash uses a program sequence from Xilinx (generated by the ISE tool iMPACT
as an *SVF* file, a standard text format for JTAG operations), and the
project plays it back over USB.

## The tools, and why ISE runs in a container

| Step | Tool | Open source? |
|---|---|---|
| Simulation | Icarus Verilog | yes |
| Synthesis | yosys or XST | yosys yes, XST no |
| Translate, map, place & route, timing, bitgen | Xilinx ISE 14.7 | **no** |
| Flash image and SVF | ISE promgen and iMPACT | no |
| Programming | adepttool (with our additions) | yes |
| Assembler | `tools/assembler.py` | yes |

**Xilinx ISE** is the manufacturer's toolchain for the Spartan-3E. Its last
version, 14.7, came out in 2013 and only runs on x86 Linux and Windows. This
project runs on a Mac with an Apple Silicon (ARM) processor, so ISE runs
inside a **Docker container**, a small isolated Linux system, and Apple's
**Rosetta** translates its x86 instructions to ARM on the fly. This works,
but slowly: each ISE tool needs about 35 seconds just to start, which is why
a build takes about 4 minutes even though the actual work takes seconds.

Place and route and bitstream generation are the steps no open-source tool
can do for this chip yet, because the format of the Spartan-3E's bitstream
has never been published. For some other FPGAs, for example Lattice's iCE40
family, the formats have been worked out by the open-source community, and a
fully open toolchain (yosys, nextpnr and IceStorm) exists.
