# FPGAs and the Basys-2 board

So far the Hack computer has been an idea on paper. To make it real, we need
hardware. We could buy thousands of logic gates and wire them together by
hand, as the first computer builders did. Instead we use a chip that can
*become* any digital circuit: an FPGA.

## Three ways to build a digital circuit

| | Processor (CPU) | Custom chip (ASIC) | FPGA |
|---|---|---|---|
| What is fixed | the hardware | the hardware | nothing yet: it is configured |
| What you change | the program (software) | nothing after manufacturing | the circuit itself |
| Example | the chip in your laptop | the chip in a USB charger | the Spartan-3E on the Basys-2 |

A normal processor has fixed hardware and runs different *programs*. A
custom chip (ASIC, *application-specific integrated circuit*) is designed for
one job and manufactured in a factory; changing it means making new chips.
An **FPGA**, a *field-programmable gate array*, sits in between: it is a
chip full of small, general-purpose logic blocks and wires whose
connections are set by a configuration file. Load a different file and it
becomes a different circuit, "in the field", without a factory.

This makes FPGAs perfect for learning about hardware: we can build a
computer, test it, find a mistake, fix it, and try again within minutes.

## What is inside an FPGA

An FPGA is a grid of a few kinds of building blocks, connected by a large
network of programmable wires.

### Look-up tables: logic as a tiny memory

The key trick of an FPGA is the **look-up table** (LUT). A 4-input LUT is a
tiny memory with 16 one-bit cells, one for each combination of its four
inputs. The four inputs form an address, and the LUT outputs the bit stored
at that address.

Remember that any logic function of four inputs is completely described by
its truth table, which has 16 rows. So if we store the truth table in the
LUT, the LUT *behaves like* that function:

```
 inputs  a b c d  ->  address  ->  stored bit = the function's output
         0 0 0 0      0            0
         0 0 0 1      1            1
         ...          ...          ...
         1 1 1 1      15           0
```

One LUT can be an AND gate, an XOR, a multiplexer, or any other of the
65 536 possible functions of four inputs. Configuring the FPGA mostly means
filling its LUTs with the right truth tables.

### Flip-flops, slices and the rest

Next to each LUT sits a **flip-flop**, so the LUT's output can either be
used directly (combinational logic) or stored on the clock edge (sequential
logic). On the Spartan-3E, two LUTs and two flip-flops, plus some extra logic
for fast addition, form a **slice**.

Besides slices, the chip has:

- **Block RAMs**: larger memories of 18 kilobits each (16 kbit of data plus
  2 kbit of "parity" bits), each with two independent ports. The Hack
  computer's ROM and RAM live here.
- **I/O blocks**: the connections to the chip's pins, which lead to the
  switches, buttons, LEDs and display on the board.
- **Clock buffers**: special, very fast wiring that delivers the clock to
  every flip-flop at almost exactly the same moment.
- **Programmable routing**: a mesh of wires and switches that connects all
  of the above. It takes up most of the chip's area.

### The FPGA on the Basys-2

The Basys-2 carries a **Xilinx Spartan-3E XC3S100E**, a chip family
introduced in 2005. By today's standards it is small, but it is more than
enough for the Hack computer:

| Resource | XC3S100E | Used by Hack |
|---|---|---|
| Slices (2 LUTs + 2 flip-flops each) | 960 | 144 (15 %) |
| 4-input LUTs | 1 920 | |
| Block RAMs of 18 kbit | 4 | 3 (75 %) |
| 18 x 18-bit multipliers | 4 | 0 |
| User I/O pins in this package | 83 | 33 |

## Where the memory lives, and why there is no memory map

If you have programmed a PC at a low level, you know that you must always
know *where* things are: screen memory starts at some address, the keyboard
at another. This information is the computer's **memory map**. On an FPGA
it works differently, and it is worth understanding why.

### In a PC: one bus, one numbering

A PC has one CPU with one set of address wires, the **bus**, and every
memory and device is connected to it. The CPU can only reach anything by
putting an address on those shared wires. So everything needs its own,
unique range of numbers, and the memory map is the agreement about which
numbers reach which chip. The address is the *only* way in.

### In an FPGA: no bus, just wires

An FPGA has no CPU and no shared bus, unless you build them. A block RAM is
a separate little memory chip *inside* the FPGA, with its **own** address
pins, data pins, clock and enable. The programmable routing wires those
pins **directly** to the logic that uses the memory, as if you had soldered
a memory chip onto a circuit board with wires to just one circuit.

In the text mode of this project, for example, the display logic's address
wires go straight to the text memory. When the logic puts the number 85 on
those wires, only that one block RAM sees it; nothing else is connected to
them. So the addresses 0 to 1199 are **local** to that memory, like the
numbered compartments of one drawer. Nothing needs a chip-wide number.

Think of a PC as an office building where everything is reached through
the reception desk by room number: you need the directory. An FPGA design is
a workshop you build yourself: you put each drawer next to the bench that
uses it, and while a drawer's compartments are numbered, nobody needs a
building-wide number for them.

### Where the block RAMs are on the chip

Most of the FPGA is a grid of logic blocks (each made of slices of LUTs and
flip-flops). Between them, the manufacturer placed columns of fixed-function
blocks, because some jobs are done far better by dedicated silicon than by
LUTs. The XC3S100E has one column of four block RAMs, each with an 18 x 18
multiplier beside it:

```
    I/O blocks around the edge (the pins)
   +----------------------------------------------+
   |  CLB CLB CLB CLB   |RAM| |MUL|   CLB CLB CLB  |
   |  CLB CLB CLB CLB   |   | |   |   CLB CLB CLB  |   RAMB16_X0Y3
   |  CLB CLB CLB CLB   |RAM| |MUL|   CLB CLB CLB  |
   |  CLB CLB CLB CLB   |   | |   |   CLB CLB CLB  |   RAMB16_X0Y2
   |  CLB CLB CLB CLB   |RAM| |MUL|   CLB CLB CLB  |
   |  CLB CLB CLB CLB   |   | |   |   CLB CLB CLB  |   RAMB16_X0Y1
   |  CLB CLB CLB CLB   |RAM| |MUL|   CLB CLB CLB  |
   |  CLB CLB CLB CLB   |   | |   |   CLB CLB CLB  |   RAMB16_X0Y0
   +----------------------------------------------+
    plus clock managers, global clock wiring and the routing mesh everywhere
    (schematic: the real chip has many more CLBs than drawn)
```

All of these blocks hang on the same programmable routing, so a block RAM's
pins can be connected to any LUT or flip-flop. The place-and-route tool
decides which physical block holds which memory, choosing positions that
keep the wires short. For two designs in this project it chose:

| Design | Memory | Physical block |
|---|---|---|
| text mode | character map | `RAMB16_X0Y2` |
| text mode | text screen | `RAMB16_X0Y3` |
| Hack computer | program ROM | `RAMB16_X0Y1` |
| Hack computer | RAM, low byte | `RAMB16_X0Y2` |
| Hack computer | RAM, high byte | `RAMB16_X0Y3` |

The same piece of silicon, `X0Y2`, holds the character map in one design
and half of the Hack RAM in the other. The Verilog never mentions this: it
only describes a memory and what it is connected to.

(The LUTs can also act as tiny memories of 16 bits each, called
*distributed RAM*. This is what the tools use when a memory cannot be
placed in block RAM; see Appendix A.)

### Memory maps come back with a CPU

The PC's view is not wrong: it belongs one level higher up. A CPU has a
single address output, and from its point of view there *is* a memory map.
On an FPGA, **you design that map yourself**. The Hack CPU's `addressM` is
wired only to its 2K of RAM, so its whole memory map is "0 to 2047: RAM".

To give Hack a text screen, a few lines of **address decoding** would send
some addresses to the text memory instead:

```verilog
wire to_screen = (addressM >= 1024) && (addressM < 1024 + 1200);
assign screen_we = writeM && cpu_ce &&  to_screen;   // 1024.. -> text RAM
assign ram_we    = writeM && cpu_ce && !to_screen;   // the rest -> RAM
```

From then on, Hack programs would see screen memory at address 1024, just
as a PC program sees screen memory at its address. That is where every
memory map comes from: a hardware designer wrote decoding logic like this.
On an FPGA, that designer is you.

## Configuration: loading a circuit

The FPGA's LUTs, routing switches and memories are set by the
**bitstream**, a file of about 72 kilobytes for this chip. The bitstream is
stored in small memory cells inside the FPGA that lose their contents when
the power goes off. So every time the board is switched on, the FPGA must be
configured again. There are two ways:

1. **Over USB (JTAG)**: a program on the PC sends the bitstream to the FPGA.
   This is fast and ideal while developing, but the design is gone after a
   power cycle.
2. **From the flash chip**: the board has a small non-volatile memory chip,
   the Xilinx **XCF02S**, next to the FPGA. If the jumper **JP3** is set to
   **ROM**, the FPGA reads its bitstream from this chip automatically at
   power-on. Writing a bitstream to the flash makes a design permanent, until
   you write another.

**JTAG** is a standard interface for testing and configuring chips. It uses
four signals (clock, data in, data out and a mode select) and connects
several chips in a chain. On the Basys-2 the chain is the FPGA and the flash
chip, and it is driven by a small USB microcontroller on the board, so a
single USB cable powers the board and programs it.

## A tour of the Basys-2

![The Basys-2 (Rev D) used for this report.](../docs/images/basys2-revD-top.jpg){width=48%}

The Basys-2 was designed by Digilent around 2009 for teaching digital
logic. Everything a first design needs is on the board:

| Part | What it is | How the Hack computer uses it |
|---|---|---|
| Spartan-3E XC3S100E | the FPGA | the whole computer |
| 50 MHz oscillator | the clock | the computer's clock |
| USB connector and controller | power and programming | loading the bitstream |
| XCF02S flash | stores a bitstream | optional: start Hack at power-on |
| SW0-SW7 | 8 slide switches | SW3..SW0 choose the RAM word shown; SW7 selects the speed |
| BTN0-BTN3 | 4 push buttons | BTN0 is reset |
| LD0-LD7 | 8 LEDs | the low 8 bits of the program counter |
| 4-digit 7-segment display | shows numbers | the chosen RAM word in hexadecimal |
| VGA connector | for a monitor | not used (yet) |
| PS/2 connector | for a keyboard or mouse | not used (yet) |
| JA-JD | four 6-pin expansion headers ("Pmod") | not used (yet) |
| JP3 | configuration jumper | PC or ROM (flash) |
| POWER switch | on/off | |

### The 7-segment display

Each digit of the display is made of seven LED segments, named a to g, plus
a decimal point. To keep the number of wires down, the four digits share the
same eight segment wires, and each digit has its own "anode" wire that
switches the whole digit on or off.

So only one digit can be lit at a time. The circuit therefore lights the
digits one after another, each for a millisecond, fast enough that your eyes
see all four at once. This technique is called **multiplexing**, and the
next chapter shows the circuit that does it.

> **Try it.** Wave the board gently from side to side in a dark room while
> the display is on. You can sometimes see the digits appear separately,
> because only one is lit at any moment.
