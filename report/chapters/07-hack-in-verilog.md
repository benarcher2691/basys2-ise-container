# The Hack computer in Verilog

To turn the Hack computer into an FPGA configuration, we first describe it
in a **hardware description language** (HDL). This project uses **Verilog**,
one of the two most widely used HDLs (the other is VHDL). This chapter
introduces the parts of Verilog we need and then walks through the real
source code in `projects/hack/rtl/`.

## Verilog is not a programming language

Verilog looks like a programming language, with `if`, `+` and `=`, but it
means something different. A program is a list of steps executed one after
another. A Verilog description is a list of **pieces of hardware that all
exist, and work, at the same time**. Every line describes wires, gates or
flip-flops, and they all operate in parallel, all the time.

Keep that in mind and Verilog becomes much easier to read: always ask "what
circuit does this describe?", not "what does this do next?".

## The essentials

### Modules and ports

A circuit is a **module** with input and output **ports**. Modules are
like components on a circuit board: you describe them once and can use
(instantiate) them many times.

```verilog
module hack_alu (
    input  wire [15:0] x,
    input  wire [15:0] y,
    input  wire        zx, nx, zy, ny, f, no,
    output wire [15:0] out,
    output wire        zr,
    output wire        ng
);
    ...
endmodule
```

`[15:0]` means a 16-bit bus, with bit 15 on the left (most significant) and
bit 0 on the right.

### Combinational logic: `assign`

`assign` connects a wire to an expression. It describes gates, not an
action: the wire *always* equals the expression, and changes whenever an
input changes. Here is the complete ALU from chapter 4, written in Verilog:

```verilog
    // Pre-process the inputs: optionally zero, then optionally negate.
    wire [15:0] x_zeroed = zx ? 16'h0000 : x;
    wire [15:0] x_final  = nx ? ~x_zeroed : x_zeroed;

    wire [15:0] y_zeroed = zy ? 16'h0000 : y;
    wire [15:0] y_final  = ny ? ~y_zeroed : y_zeroed;

    // The function: 16-bit addition or bitwise AND.
    wire [15:0] result = f ? (x_final + y_final) : (x_final & y_final);

    // Post-process the output: optionally negate.
    assign out = no ? ~result : result;

    // Status flags.
    assign zr = (out == 16'h0000);
    assign ng = out[15];
```

Each `? :` is a multiplexer, `~` is bitwise NOT, `&` bitwise AND, and `+` is
a 16-bit adder. The synthesis tool turns all of this into LUTs and the
FPGA's fast carry logic. `16'h0000` is Verilog's way to write a constant:
16 bits wide, hexadecimal value 0000.

### Sequential logic: `always @(posedge clk)`

Registers are described with an `always` block that is triggered by the
rising edge of the clock. Here is how the CPU updates its registers, one
instruction per clock edge (`ce` is explained below):

```verilog
    always @(posedge clk) begin
        if (reset) begin
            pc_reg <= 15'h0000;
        end else if (ce) begin
            if (load_a) a_reg <= a_next;
            if (load_d) d_reg <= alu_out;
            pc_reg <= jump ? a_reg[14:0] : pc_reg + 15'h0001;
        end
    end
```

The arrow `<=` is a **non-blocking assignment**. All the `<=` in a block
take effect *together*, at the clock edge, using the values from *before*
the edge. That is exactly the "everything updates at once" behaviour
described in chapter 4. For example, the jump uses the old value of `a_reg`
even if the same instruction also loads a new value into A.

> **Rule of thumb.** Use `assign` (or `always @(*)`) with `=` for
> combinational logic, and `always @(posedge clk)` with `<=` for registers.
> Mixing them up is the most common beginner's mistake in Verilog.

### Instantiation

A module is used by *instantiating* it, which is like placing a chip on a
board and wiring its pins. The CPU contains one ALU:

```verilog
    hack_alu alu (
        .x   (d_reg),
        .y   (alu_y),
        .zx  (comp[5]), .nx (comp[4]),
        .zy  (comp[3]), .ny (comp[2]),
        .f   (comp[1]), .no (comp[0]),
        .out (alu_out),
        .zr  (zr),
        .ng  (ng)
    );
```

`.x (d_reg)` means "connect the ALU's port `x` to the wire `d_reg`".

### Parameters

A **parameter** is a constant that can be set differently for each
instance, like the depth of a memory or the frequency of the clock. It is
how the same module can be used on the board (50 MHz) and in a fast
simulation (a pretend clock of 4 Hz).

## The design, module by module

```
hack_computer                  top level: board I/O, clock enable
 ├── synchronizer              makes buttons and switches safe to use
 ├── hack_cpu                  the CPU
 │    └── hack_alu             the ALU
 ├── hack_rom                  program memory (1K words, block RAM)
 ├── hack_ram                  data memory (2K words, block RAM)
 └── seven_seg_display         drives the 4-digit display
      └── seven_seg_decoder    hex digit to segment pattern
```

### The CPU: decoding and jumping

The CPU (`hack_cpu.v`) first gives the instruction bits names, so the rest
of the code reads like the specification in chapter 4:

```verilog
    wire       is_c_instr = instruction[15];     // 1 = C-instruction
    wire       use_m      = instruction[12];     // ALU y: 0 = A, 1 = M
    wire [5:0] comp       = instruction[11:6];   // zx nx zy ny f no
    wire       dest_a     = instruction[5];
    wire       dest_d     = instruction[4];
    wire       dest_m     = instruction[3];
    wire       jump_lt    = instruction[2];      // jump if out < 0
    wire       jump_eq    = instruction[1];      // jump if out = 0
    wire       jump_gt    = instruction[0];      // jump if out > 0
```

The jump decision is a direct translation of the jump table:

```verilog
    wire        positive = !zr && !ng;
    wire        jump     = is_c_instr && ((jump_lt && ng) ||
                                          (jump_eq && zr) ||
                                          (jump_gt && positive));
```

### The memories

The ROM (`hack_rom.v`) is an array of 1024 16-bit words, filled from the
program file when the design is built:

```verilog
    reg [15:0] memory [0:DEPTH-1];

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 16'h0000;
        $readmemb(INIT_FILE, memory);
    end

    always @(posedge clk)
        data <= memory[addr];
```

`$readmemb` reads a text file of binary numbers, one per line, which is
exactly the `.hack` format the assembler writes. The synthesis tool
recognises this pattern and places the array in a block RAM, with the
program as its initial contents. The program therefore becomes part of the
bitstream.

Note that the read is inside `always @(posedge clk)`: the block RAMs of the
FPGA are **synchronous**, and deliver the data for an address one clock edge
after they receive it. The RAM (`hack_ram.v`) works the same way and has a
second, read-only port, so the display can show a RAM word while the CPU is
running.

### Slowing the CPU down: the clock enable

The board's clock runs at 50 MHz. Because the memories need a clock edge to
deliver their data, the CPU must not execute an instruction on every edge.
The obvious solution would be a second, slower clock. But in FPGA design,
extra clocks made from logic cause subtle timing problems, so the rule is:
**use one clock, and tell circuits *when* to act with an enable signal.**

`hack_computer.v` counts clock cycles and produces `cpu_ce`, a pulse that is
1 for one cycle out of every 50:

```verilog
    reg  [25:0] ce_count = 26'd0;
    wire [25:0] ce_limit = slow_mode ? SLOW_DIV - 1 : CPU_DIV - 1;
    wire        cpu_ce   = (ce_count >= ce_limit);

    always @(posedge mclk)
        ce_count <= cpu_ce ? 26'd0 : ce_count + 26'd1;
```

```
mclk     _|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_|‾|_
cpu_ce   ___|‾‾‾|___________________|‾‾‾|__________________
                ^ instruction n done    ^ instruction n+1 done
```

The CPU registers only change on edges where `cpu_ce` is 1. In between, the
ROM has time to fetch the next instruction and the RAM to read the next
data word. With `CPU_DIV` = 50 the computer executes 1 million instructions
per second; with switch SW7 up, `SLOW_DIV` gives 2 per second.

### Talking to the outside world

Two more modules connect the computer to the board.

**The synchronizer.** Buttons and switches can change at any moment, not
in step with the clock. If a flip-flop samples a signal exactly while it
changes, the flip-flop can become *metastable*: its output hovers between 0
and 1 for a short while. The cure is to pass every such signal through two
flip-flops in a row; the first may go metastable, but it has a whole clock
cycle to settle before the second samples it.

**The display driver.** `seven_seg_display.v` implements the multiplexing
from chapter 6: a counter selects each digit in turn for 1 ms, a
multiplexer picks that digit's 4 bits from the 16-bit word, and the decoder
turns them into the segment pattern. As with the CPU, a single 50 MHz clock
and an enable pulse do all the timing.

## Testing in simulation

Hardware is hard to debug: you cannot print a variable from inside a chip.
So every module is first tested in **simulation**, using a **testbench**:
another piece of Verilog that is never built into hardware. It creates a
clock, drives the inputs and checks the outputs, and it may use
programming-style features such as loops, `$display` and `$random`.

The ALU testbench (`tb/hack_alu_tb.v`) sets the control bits for each of the
18 functions, feeds in special values (0, 1, -1, 32 767, -32 768) and 200
random pairs of numbers, and compares the ALU's output with the result
computed directly in the testbench: 4 050 checks in total.

The computer testbench (`tb/hack_computer_tb.v`) loads `test001` into the
ROM, lets the whole computer run, and checks the RAM contents, the final
program counter and the display port. The simulator used is **Icarus
Verilog**, and `make sim` runs both testbenches:

```
== hack_alu_tb
PASS: hack_alu, 4050 checks
== hack_computer_tb
PASS: hack_computer running test001
```

Only when the simulation passes is the design built for the FPGA. That
order, simulate first and build second, saves a lot of time: a simulation
takes a second, a build takes minutes, and finding a bug on the board is
much harder than in a simulation.
