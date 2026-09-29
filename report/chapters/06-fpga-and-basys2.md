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
