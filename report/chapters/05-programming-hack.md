# Programming the Hack computer

The CPU only understands **machine code**: 16-bit words like
`1110001100001000`. Nobody wants to write programs like that. Instead we
write **assembly language**, where each instruction has a readable name like
`M=D`, and a program called an **assembler** translates it into machine
code, one instruction per line.

## Assembly language

A Hack assembly program is a text file (`.asm`) with one instruction per
line. It can also contain:

- **comments**, starting with `//`, which the assembler ignores;
- **labels** in parentheses, like `(LOOP)`, which name the address of the
  next instruction, so you can jump there with `@LOOP`;
- **symbols** in A-instructions, like `@i` or `@sum`, which name RAM
  addresses.

Symbols come in three kinds:

| Kind | Example | Address |
|---|---|---|
| Label | `(LOOP)` ... `@LOOP` | the ROM address of the instruction after the label |
| Predefined | `@R1`, `@SCREEN`, `@KBD` | fixed: `R0`-`R15` are 0-15, `SCREEN` is 16384, `KBD` is 24576 |
| Variable | `@i`, `@sum` | any other name: the assembler gives each new one the next free RAM address, starting at 16 |

The assembler produces a `.hack` file: one line of 16 characters `0` and
`1` for each instruction. That file is exactly what goes into the ROM.

## A first program

The program `add.asm` from the previous chapter:

```
// add.asm: RAM[0] = 2 + 3

    @2          // A = 2
    D=A         // D = 2
    @3          // A = 3
    D=D+A       // D = 2 + 3
    @0          // A = 0: the address to write to
    M=D         // RAM[0] = D
(END)
    @END        // stop here: jump to END forever
    0;JMP
```

Two patterns appear in almost every Hack program:

- **Load a constant into D**: `@value` then `D=A`. The constant has to go
  through A, because only an A-instruction can contain a constant.
- **Access a RAM word**: `@address` then use `M`. First choose the address
  with A, then read or write `M`.

## Decisions and loops

Hack has no `if` or `while`. Everything is built from **conditional jumps**.
The idea is always the same: compute a value into D, then jump depending on
whether it is negative, zero or positive.

For example, `if (x > 0) goto POSITIVE` becomes:

```
    @x
    D=M          // D = x
    @POSITIVE
    D;JGT        // jump if D > 0
```

A loop is a jump back to an earlier label. Here is `sum.asm`, which adds the
numbers from 1 to 10:

```
// sum.asm: RAM[1] = 1 + 2 + ... + 10 = 55

    @i
    M=1         // i = 1
    @sum
    M=0         // sum = 0
(LOOP)
    @i
    D=M         // D = i
    @10
    D=D-A       // D = i - 10
    @STOP
    D;JGT       // if i - 10 > 0, i.e. i > 10, the loop is done
    @i
    D=M         // D = i
    @sum
    M=D+M       // sum = sum + i
    @i
    M=M+1       // i = i + 1
    @LOOP
    0;JMP       // repeat
(STOP)
    @sum
    D=M         // D = sum
    @R1
    M=D         // RAM[1] = sum
(END)
    @END
    0;JMP
```

In a high-level language it would be:

```python
i = 1
total = 0
while not (i > 10):
    total = total + i
    i = i + 1
RAM[1] = total
```

The variables `i` and `sum` are placed by the assembler in RAM[16] and
RAM[17]. Tracing the first rounds of the loop:

| Round | i at the test | i - 10 | Jump to STOP? | sum after the round |
|---|---|---|---|---|
| 1 | 1 | -9 | no | 1 |
| 2 | 2 | -8 | no | 3 |
| 3 | 3 | -7 | no | 6 |
| ... | ... | ... | ... | ... |
| 10 | 10 | 0 | no (0 is not > 0) | 55 |
| 11 | 11 | 1 | **yes** | |

The result, 55, is `0x0037` in hexadecimal.

> **On the board.** Build the computer with this program, in
> `projects/hack`:
>
> ```
> make PROGRAM=programs/sum.hack prog
> ```
>
> Then set SW0 up to show address 1: the display shows `0037`.

> **Try it.** Change `sum.asm` to add the numbers from 1 to 100. What will
> the display show? (5050 = `0x13BA`.)

## The test program

The computer on the board comes with a test program, `test001.asm`,
written to check that every kind of jump works. It stores a = 5 in RAM[0]
and b = -5 in RAM[1], and then tests six comparisons between them. Each
test computes D = a - b and jumps on the condition. Here is the first one,
"is a < b?":

```
    @0
    D=M          // D = a
    @1
    D=D-M        // D = a - b = 10
    @JLT_TRUE
    D;JLT        // jump if a - b < 0, i.e. if a < b
    @1
    D=A          // not less: D = 1
    @2
    M=D          // RAM[2] = 1
    @JLT_END
    0;JMP
(JLT_TRUE)
    @1
    D=-A         // less: D = -1
    @2
    M=D          // RAM[2] = -1
(JLT_END)
```

The program writes the *correct* answer as 1, so if every jump instruction
works, all six results are 1. At the very end it stores 42 in RAM[9] to show
that it finished:

| Switches SW3..SW0 | Address | Display | Meaning |
|---|---|---|---|
| 0000 | 0 | `0005` | a = 5 |
| 0001 | 1 | `FFFB` | b = -5 |
| 0010 | 2 | `0001` | a < b is false: correct |
| 0011 | 3 | `0001` | a <= b is false: correct |
| 0100 | 4 | `0001` | a > b is true: correct |
| 0101 | 5 | `0001` | a >= b is true: correct |
| 0110 | 6 | `0001` | a == b is false: correct |
| 0111 | 7 | `0001` | a != b is true: correct |
| 1000 | 8 | `0008` | not used by the program: its initial value |
| 1001 | 9 | `002A` | 42: the program reached its end |

## How the assembler works

The assembler (`projects/hack/tools/assembler.py`) reads the program twice:

1. **First pass**: it counts instructions and records the address of every
   label. `(LOOP)` gets the address of the instruction that follows it.
   Labels can be used before they are defined, which is why a first pass is
   needed.
2. **Second pass**: it translates each instruction. An A-instruction
   becomes a 0 followed by the 15-bit value. If the value is a symbol, it
   is looked up; an unknown symbol is a new variable and gets the next free
   RAM address, starting at 16. A C-instruction is split into dest, comp
   and jump, and each part is looked up in the tables of chapter 4.

That is all: an assembler is little more than table lookups. It is a good
first project if you want to write a translator yourself.

## Running your own programs

You can run a Hack program without any hardware, in a simulation of the
exact circuit that goes onto the chip:

```sh
cd projects/hack
make run PROGRAM=programs/sum.hack
```

This assembles `sum.asm` if needed, runs the program for 1000
instructions, and prints the program counter and RAM[0] to RAM[15]:

```
after 1000 instructions: PC = 23
addr   hex    decimal
RAM[0]  0000  0
RAM[1]  0037  55
...
```

To run it on the board instead, `make PROGRAM=programs/sum.hack prog`
builds the chip configuration with the program in its ROM (this takes a few
minutes) and loads it.

> **Try it.** Write a program that computes 6 x 7 using repeated addition
> and stores the result in RAM[0]. Check it with `make run`.

## Summary

- Assembly language gives names to machine instructions; the assembler
  translates it to machine code in two passes.
- Labels name ROM addresses (jump targets); variables name RAM addresses,
  from 16 up.
- To use a constant, load it through A. To use memory, set A and use M.
- Decisions and loops are built from conditional jumps on the value in D.
