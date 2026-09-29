# Introduction

Every day you use computers: phones, laptops, the chip in a washing machine.
You probably know how to *program* one. But how does the machine itself
work? What actually happens inside when a program runs, when a number is
added, when a loop repeats?

This report answers that question by building a complete, working computer
and explaining every part of it. The computer is called **Hack**. It is
small enough to understand completely, yet it is a real stored-program
computer: it fetches instructions from memory, computes with numbers, makes
decisions and loops, just like the processor in your phone. The difference
is mainly one of size and speed.

We will not stop at theory. The Hack computer described here runs on a real
chip: a *Field-Programmable Gate Array* (FPGA) on a small circuit board
called the **Digilent Basys-2**. An FPGA is a chip whose internal wiring can
be reconfigured, so instead of soldering together thousands of logic gates,
we describe the computer in a hardware description language (Verilog) and
let software turn that description into a configuration for the chip.

## What you will learn

- How computers represent numbers and text with nothing but 0s and 1s,
  including negative numbers.
- How simple logic gates, and in fact a single kind of gate called NAND, are
  enough to build every other part of a computer.
- The difference between circuits that *compute* (combinational logic) and
  circuits that *remember* (sequential logic), and why a computer needs a
  clock.
- The architecture of the Hack computer: its CPU, its memories and its
  instruction set.
- How to program Hack in assembly language, and how an assembler turns that
  into the binary machine code the hardware executes.
- Later chapters: what an FPGA is, how the Hack computer is described in
  Verilog, and how the tools turn that description into a working chip.

## How the report is organised

| Chapter | Topic |
|---|---|
| 2 | Where the Hack computer comes from: the *Nand to Tetris* course |
| 3 | Bits, numbers and logic: the building blocks |
| 4 | Inside the Hack computer: architecture and instruction set |
| 5 | Programming the Hack computer in assembly language |
| later | FPGAs and the Basys-2 board; Hack in Verilog; from source code to a running chip |

Chapters 2 to 5 are about the computer itself and need no special
equipment. The later chapters are about building it on real hardware.

## How to read it

You don't need to know any electronics. It helps if you have written a few
programs in any language (Python, Java, JavaScript...), because the report
often compares hardware ideas with programming ideas you already know.

Throughout the text you will find boxes like this one:

> **Try it.** Short exercises and experiments. Most can be done with pen and
> paper; some use the simulator or the real board that come with this
> project.

Numbers are written in three bases. The prefix or suffix tells which one is
meant:

| Written as | Base | Example |
|---|---|---|
| `42` | decimal (base 10) | forty-two |
| `0b101010` | binary (base 2) | forty-two |
| `0x002A` or `002A` on the display | hexadecimal (base 16) | forty-two |

All the source code, the programs and this report are in the project's
repository; the relevant files are named in the text so you can look at the
real thing.
