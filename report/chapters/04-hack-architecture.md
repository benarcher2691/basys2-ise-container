# Inside the Hack computer

This chapter describes the Hack computer as a programmer and as a hardware
designer see it: its parts, its registers, its instructions, and what
happens during each clock cycle.

## The big picture

The Hack computer has three main parts:

```
                  +-----------------+
                  |       ROM       |   the program: one instruction per word
                  | (instructions)  |
                  +-----------------+
                     ^          |
                  PC |          | instruction
                     |          v
                  +-----------------+
                  |       CPU       |   A, D and PC registers, ALU, control
                  +-----------------+
                     |   ^      |
            addressM |   | inM  | outM, writeM
                     v   |      v
                  +-----------------+
                  |       RAM       |   data: variables, results
                  +-----------------+
```

- The **ROM** (read-only memory) holds the **program**, one 16-bit
  instruction per address. The CPU tells the ROM which instruction it wants
  with the **program counter** (PC), and the ROM answers with that
  instruction.
- The **RAM** (random-access memory) holds **data**. The CPU gives an
  address (`addressM`), reads the word stored there (`inM`), and can write a
  new value (`outM`, when `writeM` is 1).
- The **CPU** (central processing unit) executes instructions: it computes,
  moves data between its registers and RAM, and decides which instruction
  comes next.

Programs and data live in separate memories, reached over separate paths.
This is called a **Harvard architecture** (after an early computer at
Harvard University). Most PCs instead use a **von Neumann architecture**,
where programs and data share one memory. Harvard is simpler to build:
the CPU can read an instruction and a data word at the same time.

## Registers

The Hack CPU has only three registers, each 16 bits wide (the PC 15):

| Register | Name | Used for |
|---|---|---|
| **A** | address register | holding constants, and choosing the RAM address |
| **D** | data register | holding a value to compute with |
| **PC** | program counter | the address of the current instruction in ROM |

There is also **M**, which is not a real register but a name for "the RAM
word at the address in A", in other words `RAM[A]`. Reading `M` reads that
RAM word; writing `M` writes it.

So A has two jobs. It is a general-purpose register, and it is also the
pointer that selects which RAM word `M` is and where a jump goes. You will
see this in every Hack program: first set A, then use M.

## Instructions

Every Hack instruction is one 16-bit word. There are only two kinds, and the
top bit tells them apart.

### The A-instruction: `@value`

```
0 v v v v v v v v v v v v v v v
^ ---------------------------
|  a 15-bit number (0 .. 32767)
+-- 0 = A-instruction
```

An A-instruction loads a constant into the A register. In assembly it is
written with an `@`: `@5` sets A to 5, and its machine code is simply 5 in
binary, `0000000000000101`.

A-instructions are how a program gets constants, chooses a RAM address
(`@100` followed by an instruction that uses M), or prepares a jump target.

### The C-instruction: `dest = comp ; jump`

```
1 1 1 a c c c c c c d d d j j j
^     ^ -----------  ----- -----
|     |   comp        dest  jump
|     +-- a: ALU's second input is A (0) or M (1)
+-- 1 = C-instruction   (the next two bits are unused and set to 1)
```

A C-instruction ("compute") does three things at once:

1. **comp**: the ALU computes something from D and A, or from D and M.
2. **dest**: the result is stored in any combination of A, D and M.
3. **jump**: depending on the result, the program may jump to the address
   in A.

Each part is optional except comp. Examples:

| Assembly | Meaning |
|---|---|
| `D=A` | D = A |
| `D=D+M` | D = D + RAM[A] |
| `M=D` | RAM[A] = D |
| `AM=M+1` | RAM[A] = RAM[A] + 1, and A gets the same value |
| `D;JGT` | if D > 0, jump to the address in A |
| `0;JMP` | jump to the address in A, always |

#### The comp field

The `a` bit and the six `c` bits select the computation. These are all
the computations Hack supports:

| comp (a=0) | comp (a=1) | c bits |
|---|---|---|
| `0` | | 101010 |
| `1` | | 111111 |
| `-1` | | 111010 |
| `D` | | 001100 |
| `A` | `M` | 110000 |
| `!D` | | 001101 |
| `!A` | `!M` | 110001 |
| `-D` | | 001111 |
| `-A` | `-M` | 110011 |
| `D+1` | | 011111 |
| `A+1` | `M+1` | 110111 |
| `D-1` | | 001110 |
| `A-1` | `M-1` | 110010 |
| `D+A` | `D+M` | 000010 |
| `D-A` | `D-M` | 010011 |
| `A-D` | `M-D` | 000111 |
| `D&A` | `D&M` | 000000 |
| `D|A` | `D|M` | 010101 |

(`!` is bitwise NOT, `&` bitwise AND, `|` bitwise OR.)

Notice what is missing: there is no multiplication, no division, and no
shift. A program that needs them builds them from addition and loops, which
is exactly what the Nand to Tetris operating system does.

#### The dest field

Three bits, one for each place the result can go:

| d bits | Mnemonic | Stores the result in |
|---|---|---|
| 000 | (none) | nowhere: the value is only used for a jump |
| 001 | `M` | RAM[A] |
| 010 | `D` | D |
| 011 | `MD` | RAM[A] and D |
| 100 | `A` | A |
| 101 | `AM` | A and RAM[A] |
| 110 | `AD` | A and D |
| 111 | `AMD` | A, D and RAM[A] |

#### The jump field

Three bits that say for which results to jump. The left bit means "jump if
the result is negative", the middle bit "if it is zero", the right bit "if
it is positive". Any combination is allowed:

| j bits | Mnemonic | Jump if the ALU result is |
|---|---|---|
| 000 | (none) | never |
| 001 | `JGT` | greater than 0 |
| 010 | `JEQ` | equal to 0 |
| 011 | `JGE` | greater than or equal to 0 |
| 100 | `JLT` | less than 0 |
| 101 | `JNE` | not equal to 0 |
| 110 | `JLE` | less than or equal to 0 |
| 111 | `JMP` | always |

### Decoding an instruction by hand

Take the word `1110001100001000`:

```
1 11 0 001100 001 000
|    |   |     |   +-- jump 000: no jump
|    |   |     +------ dest 001: M
|    |   +------------ comp 001100 with a=0: D
|    +---------------- a = 0
+--------------------- C-instruction
```

It is `M=D`: store D in RAM[A].

> **Try it.** Decode `1110110000010000` and `1110101010000111`.
> (Answers: `D=A` and `0;JMP`.)

## The ALU

The ALU (arithmetic logic unit) is the combinational circuit that does the
calculations. It has two 16-bit inputs: **x** is always D, and **y** is
either A or M, chosen by the `a` bit. The six comp bits are its control
inputs, with these names and meanings, applied in this order:

| Bit | Name | Effect |
|---|---|---|
| 1st | `zx` | set x to 0 |
| 2nd | `nx` | invert all bits of x |
| 3rd | `zy` | set y to 0 |
| 4th | `ny` | invert all bits of y |
| 5th | `f` | if 1, out = x + y; if 0, out = x AND y |
| 6th | `no` | invert all bits of out |

It also produces two **flags** about its result: `zr` is 1 if the result is
zero, and `ng` is 1 if it is negative (its top bit is 1). The CPU uses
them to decide jumps.

It is surprising that these six simple steps give all 18 functions in the
table above. Take `D-A`, with control bits `010011`: `nx` = 1, `f` = 1, `no`
= 1, and the rest 0. The ALU computes

```
out = NOT( (NOT x) + y )
```

In two's complement, NOT v = -v - 1 for any v. So:

```
NOT( (NOT x) + y ) = -( (-x - 1) + y ) - 1 = x + 1 - y - 1 = x - y
```

The same trick explains `-D`, `D+1` and the others.

> **Try it.** Show that the control bits `011111` (`D+1`) really compute
> x + 1. Hint: y becomes all 1s, which is -1.

## One instruction per clock cycle

The Hack CPU is a **single-cycle** processor: every instruction is completed
in exactly one clock cycle. During a cycle, all of this happens at once, as
combinational logic:

1. The ROM delivers the instruction at address PC.
2. The instruction bits are decoded into control signals.
3. The ALU computes its result from D and A (or M).
4. The jump logic decides, from the jump bits and the flags, whether to jump.

Then, at the rising clock edge that ends the cycle, everything is stored
**simultaneously**:

- A, D and RAM[A] get the result, as selected by dest (or A gets the constant,
  for an A-instruction);
- PC becomes the address in A if the CPU jumps, and PC + 1 otherwise.

Because everything updates on the same edge, the *old* value of A is used
during the whole instruction. `AM=M+1` reads M at the old address, and writes
it at the old address too, even though A changes at the same moment.

### A worked example

Here is the program `add.asm`, which computes 2 + 3 and stores it in
RAM[0]. The table shows the registers *after* each instruction:

| PC | Instruction | Machine code | A | D | RAM[0] |
|---|---|---|---|---|---|
| 0 | `@2` | `0000000000000010` | 2 | 0 | 0 |
| 1 | `D=A` | `1110110000010000` | 2 | 2 | 0 |
| 2 | `@3` | `0000000000000011` | 3 | 2 | 0 |
| 3 | `D=D+A` | `1110000010010000` | 3 | 5 | 0 |
| 4 | `@0` | `0000000000000000` | 0 | 5 | 0 |
| 5 | `M=D` | `1110001100001000` | 0 | 5 | **5** |
| 6 | `@6` | `0000000000000110` | 6 | 5 | 5 |
| 7 | `0;JMP` | `1110101010000111` | 6 | 5 | 5 |

After instruction 7 the PC jumps back to 6, and the program loops between 6
and 7 forever. A Hack program never "ends": when it is done, it waits in a
loop like this.

## Memory map

In the book's Hack computer, the RAM address space is shared with the
input and output devices. This technique is called **memory-mapped I/O**:
the program reads and writes devices exactly as if they were memory.

| Addresses | Book's Hack | Hack on the Basys-2 |
|---|---|---|
| 0 - 15 | RAM, also called R0-R15 | RAM; **the display can show these 16 words** |
| 16 - 2047 | RAM (variables start at 16) | RAM |
| 2048 - 16383 | RAM | not present (addresses wrap around) |
| 16384 - 24575 | **screen**: 8192 words = 512 x 256 pixels | not present |
| 24576 | **keyboard**: the code of the key being pressed | not present |

On the Basys-2 the "screen" is the four-digit display: switches SW3 to SW0
choose one of the addresses 0 to 15, and the display shows the word stored
there, in hexadecimal. The LEDs show the lowest 8 bits of the program
counter, so you can watch the program run when the computer is slowed down
to 2 instructions per second (switch SW7 up).
