# Bits, numbers and logic

A computer is made of switches that are either on or off. Everything it
does, from arithmetic to video, is built on that. This chapter covers the
three foundations: how to represent numbers with on/off values, how to
compute with them using logic gates, and how a circuit can remember.

## Bits and binary numbers

A **bit** (binary digit) has one of two values, written 0 and 1. In a chip,
0 is a low voltage (0 V) and 1 a high voltage, for example 3.3 V on the pins
of the Basys-2's FPGA.

With one bit you can count to 1. With more bits you count the way you count
in decimal, except that each position is worth twice the one to its right
instead of ten times:

| Position value | 8 | 4 | 2 | 1 | |
|---|---|---|---|---|---|
| `0b0101` | 0 | 1 | 0 | 1 | = 4 + 1 = 5 |
| `0b1010` | 1 | 0 | 1 | 0 | = 8 + 2 = 10 |
| `0b1111` | 1 | 1 | 1 | 1 | = 8 + 4 + 2 + 1 = 15 |

With *n* bits you can write 2^n different values. Hack works with **words**
of 16 bits, so a word can hold 2^16 = 65 536 different values.

### Hexadecimal

Long rows of 0s and 1s are hard to read, so programmers group them in fours.
Four bits have 16 values, written with the digits `0`-`9` and the letters
`A`-`F` (A = 10, B = 11, ..., F = 15). This is **hexadecimal**, base 16:

```
binary        0000 0000 0010 1010
hexadecimal      0    0    2    A      ->  0x002A = 2*16 + 10 = 42
```

A 16-bit word is always exactly four hex digits. That is why the Basys-2's
four-digit display is perfect for showing a Hack word.

> **Try it.** Write 255, 256 and 1000 in binary and in hexadecimal.
> (Answers: `0x00FF`, `0x0100`, `0x03E8`.)

## Negative numbers: two's complement

How do you store -5 when all you have are bits? Almost every computer,
including Hack, uses a system called **two's complement**. In a 16-bit word:

- the numbers 0 to 32 767 are written normally (the top bit is 0);
- the negative numbers -1 to -32 768 use the patterns whose top bit is 1.

The rule is: to negate a number, **invert every bit and add 1**. For 5:

```
 5              0000 0000 0000 0101   0x0005
 invert bits    1111 1111 1111 1010   0xFFFA
 add 1          1111 1111 1111 1011   0xFFFB   = -5
```

Check it by adding 5 and -5. The result has a carry out of the top bit,
which simply falls off the end of the 16-bit word, and what remains is 0:

```
     0000 0000 0000 0101      5
   + 1111 1111 1111 1011     -5
   ---------------------
   1 0000 0000 0000 0000      0 (the 1 on the left doesn't fit in 16 bits)
```

This is the beauty of two's complement: the *same* adder circuit works for
positive and negative numbers, and subtraction is just adding the negation.
The top bit tells you the sign: 1 means negative.

> **On the board.** The test program described in chapter 5 stores -5 in
> RAM address 1. Set switch SW0 up and the display shows `FFFB`.

## Logic gates

A **logic gate** is a tiny circuit that computes a function of one or two
bits. The behaviour of a gate is completely described by its **truth
table**: the output for every possible combination of inputs.

| a | b | NOT a | a AND b | a OR b | a XOR b | a NAND b |
|---|---|---|---|---|---|---|
| 0 | 0 | 1 | 0 | 0 | 0 | 1 |
| 0 | 1 | 1 | 0 | 1 | 1 | 1 |
| 1 | 0 | 0 | 0 | 1 | 1 | 1 |
| 1 | 1 | 0 | 1 | 1 | 0 | 0 |

In words: AND is 1 only if both inputs are 1; OR is 1 if at least one is;
XOR ("exclusive or") is 1 if exactly one is; NOT inverts; and **NAND** ("not
and") is the inverse of AND.

### Everything from NAND

NAND has a remarkable property: *every* other logic function can be built
from NAND gates alone. For example:

```
NOT a     =  a NAND a
a AND b   =  NOT (a NAND b)            =  (a NAND b) NAND (a NAND b)
a OR b    =  (NOT a) NAND (NOT b)      =  (a NAND a) NAND (b NAND b)
```

The last line uses **De Morgan's law**: "a or b" is the same as "not (not a
and not b)". Check any of these with the truth table above.

This is why Nand to Tetris starts from NAND: it proves that one simple
building block is enough for a whole computer. (Real chips, and FPGAs,
use a richer set of building blocks for efficiency, but the principle is
the same.)

> **Try it.** Build XOR from NAND gates. Hint: a XOR b = (a OR b) AND NOT (a
> AND b). It can be done with four NAND gates.

### From gates to arithmetic

Gates can be combined to do arithmetic. Adding two bits gives a sum bit and
a carry bit:

| a | b | carry | sum |
|---|---|---|---|
| 0 | 0 | 0 | 0 |
| 0 | 1 | 0 | 1 |
| 1 | 0 | 0 | 1 |
| 1 | 1 | 1 | 0 |

Look closely: *sum* is exactly `a XOR b`, and *carry* is exactly `a AND b`.
This circuit is a **half adder**. A **full adder** also takes the carry
coming in from the position to its right, and 16 full adders in a row make
a 16-bit adder: the carry ripples from bit 0 up to bit 15, exactly like
carrying digits in written addition.

Another essential circuit is the **multiplexer** ("mux"): it has two data
inputs and a *select* input, and passes one of the two data inputs to its
output:

```
out = if sel then b else a
```

A multiplexer is how hardware makes choices. The Hack CPU uses them, for
example, to choose whether the ALU works on a register or on a value from
memory.

## Circuits that remember

Everything so far is **combinational logic**: the output depends only on the
current inputs. Change the inputs and, a few nanoseconds later, the output
changes. There is no memory.

But a computer must remember things: the current instruction, the values
of variables, where it is in the program. For that we need **sequential
logic**, built around a **clock**.

### The clock

The clock is a signal that switches between 0 and 1 at a steady rate. On
the Basys-2 it runs at 50 MHz: 50 million times per second, so one clock
cycle lasts 20 nanoseconds.

```
clock   _|‾‾|__|‾‾|__|‾‾|__|‾‾|__|‾‾|__
          ^     ^     ^     ^     ^      rising edges
```

The moment the clock goes from 0 to 1 is called the **rising edge**. It is
the heartbeat of the whole computer: things happen on rising edges, and
between two edges the combinational logic has time to calculate the next
values.

### Flip-flops and registers

A **flip-flop** (more precisely a D flip-flop) stores one bit. It has a data
input `d`, a clock input and an output `q`. On each rising edge of the clock
it copies `d` to `q`, and then holds that value, no matter how `d` changes,
until the next rising edge.

A **register** is a row of flip-flops that store a whole word together, for
example 16 flip-flops for a 16-bit register. Usually a register also has a
*load* input: it only takes the new value on a clock edge where load is 1,
and otherwise keeps its old value.

A **memory** (RAM) is a large collection of registers with an address that
selects which one to read or write.

### Why the clock matters

Imagine a counter: a register whose input is its own output plus 1. Without
a clock, the output would feed back to the input and change continuously
and chaotically. With a clock, the register takes the new value exactly
once per rising edge: 0, 1, 2, 3... one step per cycle.

This pattern, combinational logic between registers with a clock that
decides when the registers update, is how every processor works:

```
     +----------+      +-----------------------+      +----------+
 --->| register |----->| combinational logic   |----->| register |--->
     +----------+      | (adders, muxes, ...)  |      +----------+
          ^            +-----------------------+           ^
          |                                                |
       clock -----------------------------------------------
```

The clock period must be long enough for the slowest path through the
combinational logic to settle. That is what limits the maximum clock speed
of a chip.

## Summary

- Everything is bits. A Hack word is 16 bits: four hexadecimal digits.
- Negative numbers use two's complement: invert all bits and add 1. The top
  bit is the sign.
- Logic gates compute functions of bits. NAND alone can build all of them.
- Gates combine into adders and multiplexers: **combinational logic**.
- Flip-flops and registers remember values between clock edges:
  **sequential logic**.
- A processor is registers plus the combinational logic between them, driven
  by a clock.
