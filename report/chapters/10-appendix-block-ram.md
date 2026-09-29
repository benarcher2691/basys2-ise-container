# Appendix A: Using the block RAM {-}

Memories are where FPGA designs most often go wrong, and where the Basys-2's
small FPGA runs out first. This appendix is a practical guide to the
Spartan-3E's **block RAM**, with the patterns used in this project.

## What the chip has {-}

The XC3S100E has **4 block RAMs**. Each holds **18 kbit**: 16 kbit of data
plus 2 kbit of extra "parity" bits (usable as a ninth bit per byte).

- **Two independent ports**, A and B, each with its own address, data,
  clock, enable and write enable.
- **A configurable shape**: 16K x 1, 8K x 2, 4K x 4, 2K x 8 (or x 9),
  1K x 16 (or x 18), or 512 x 32 (or x 36) bits. The two ports may even use
  different shapes of the same memory.
- **Synchronous**: reading and writing both happen on a clock edge.

The last point decides almost everything else.

## The golden rule: register the read {-}

A block RAM delivers the data for an address **one clock edge after** it
receives the address. So in Verilog the read must be inside a clocked
`always` block:

```verilog
always @(posedge clk)
    dout <= memory[addr];      // synchronous read: becomes block RAM
```

If you write the read as combinational logic instead,

```verilog
assign dout = memory[addr];    // asynchronous read: NOT block RAM
```

you ask for the data *immediately*, which a block RAM cannot do. The
synthesis tool then builds the memory out of look-up tables ("distributed
RAM"). A 4-input LUT holds only 16 bits, so a few kilobits of memory can
use up a large part of the chip. **This is the most common reason a design
runs out of room.**

## Three templates {-}

The synthesis tools recognise these patterns and map them onto block RAM.

**A ROM with contents from a file**, like the character map in
`char_rom.v` of the text mode:

```verilog
reg [7:0] rom [0:511];
initial $readmemh("font.hex", rom);       // plain hex, one word per line

always @(posedge clk)
    data <= rom[addr];
```

**A single-port RAM**, reading and writing through one port:

```verilog
reg [15:0] ram [0:1023];

always @(posedge clk) begin
    if (we)
        ram[addr] <= din;
    dout <= ram[addr];         // "read first": during a write you see the old value
end
```

**A dual-port RAM** in which one port writes and the other reads, like the
text screen and the Hack computer's RAM:

```verilog
reg [7:0] ram [0:2047];

always @(posedge clk)          // port A: the CPU writes
    if (we_a)
        ram[addr_a] <= din_a;

always @(posedge clk)          // port B: the display reads
    if (en_b)
        dout_b <= ram[addr_b];
```

A block RAM has two ports, no more. A third reader forces the tools to make
a copy of the memory, which costs another block RAM.

## Living with the delay {-}

Because the data arrives one clock edge later, everything that belongs
with that data must be **delayed by the same amount**.

In the text mode, each pixel passes through two block RAMs, first the text
screen, then the character map, so its colour is known two steps after its
position. The sync signals and the pixel's position within the character
therefore travel through two extra registers, a small **pipeline**, so they
arrive at the monitor together with the colour.

In the Hack computer, the CPU executes an instruction only on every 50th
clock edge (the clock enable). In between, the memories have plenty of edges
to deliver the next instruction and data word.

## Initial contents {-}

- `$readmemh` reads hexadecimal and `$readmemb` binary, one word per line.
  A Hack `.hack` file is already in the right format for `$readmemb`.
- The file is read when the design is built, and its contents become part
  of the bitstream.
- The Xilinx tool XST does not accept comments in these files, although
  simulators do. That is why the character map exists twice: `font.hex`
  for the tools and `font.txt`, with pictures, for people.
- XST looks for the file in the directory where it runs. The project's
  Makefiles copy the files into the build directory.
- Words that the file does not cover start as 0.

## From a screen to an address {-}

A memory is one long row of words, numbered from 0. A screen is
two-dimensional. The usual way to store a two-dimensional table in a
one-dimensional memory is **row by row**, the same way a 2-D array is
stored in most programming languages:

```
address = row x (number of columns) + column
```

The text screen has 40 columns and 30 rows, so the cell in column 5 of row 2
is at address 2 x 40 + 5 = 85. The last cell, column 39 of row 29, is at
29 x 40 + 39 = 1199: 1200 cells, which need 11 address bits (2^11 = 2048).

Hardware can do this multiplication cheaply, because 40 = 32 + 8 and
multiplying by a power of two only shifts the bits:

```verilog
cell_addr = {row, 5'd0} + {row, 3'd0} + column;   // row*32 + row*8 + column
```

With a power of two it is even simpler. The character map stores 8 rows per
character, so the row of a character is at

```
address = character x 8 + row  =  {character, row}   (the bits side by side)
```

with no adder at all. The same trick turns a pixel position into a
character cell: a cell is 16 x 16 pixels, and dividing by 16 just drops the
lowest 4 bits, so the column is `x[9:4]` and the row `y[8:4]`.

> **Design choice.** The text screen could also use 64 "columns" per row in
> memory, of which only 40 are shown. Then `address = {row, column}`, again
> with no adder. 30 rows x 64 = 1920 cells still fit in one block RAM
> (2048). This project uses row x 40 to show the general formula, but both
> are correct: choosing memory layouts that make the hardware simple is a
> normal part of design.

Note that a memory's addresses have nothing to do with *where* on the chip
the block RAM sits: every memory starts at address 0, and the place-and-route
tool decides which of the four physical block RAMs it uses.

## Checking that it worked {-}

The synthesis and map reports (`build/*.syr`, `build/*_map.mrp`) say what
the tools did with each memory:

```
INFO:Xst:3225 - The RAM <Mram_memory> will be implemented as BLOCK RAM
Number of RAMB16s:                      2 out of       4   50%
```

If a memory ends up as "distributed RAM" instead, or the number of slices
jumps, check the golden rule first.

## Common pitfalls {-}

- **An asynchronous read** (see the golden rule).
- **Logic between the memory and its output register**, such as
  `dout <= ram[addr] + 1;`. Do the arithmetic in the next stage.
- **More than two ports** on one memory: the tools make copies.
- **Sizes**: memories come in the shapes listed at the top, so round up.
  1200 x 8 fits one block RAM (2K x 8), 2400 x 8 needs two.
- **Odd clocking**: clocking a memory on the falling edge, or from a
  divided clock, works but is fragile. Use the one board clock with an
  enable (`if (en) ...`), which the block RAM supports directly.
