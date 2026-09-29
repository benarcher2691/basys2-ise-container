# Where Hack comes from: Nand to Tetris

## A computer designed for learning

The Hack computer was designed by two computer science professors, **Noam
Nisan** (Hebrew University of Jerusalem) and **Shimon Schocken** (then at
the Interdisciplinary Center Herzliya, now Reichman University). They
noticed that students could write complicated programs without having any
idea how a computer actually works: the hardware, the compiler and the
operating system were all black boxes.

Their answer was a course in which students build an entire computer
system themselves, from the most basic logic gate up to a working game. They
described it in the book *The Elements of Computing Systems: Building a
Modern Computer from First Principles* (MIT Press, 2005; second edition
2021). The course is better known by its nickname **Nand to Tetris**, or
**nand2tetris**, and its website `nand2tetris.org` offers the book's
projects and free software tools. It has since been taught at many
universities and schools and as a free online course.

Hack is the computer at the centre of that course. It was designed with one
goal: to be as simple as possible while still being a *complete* computer,
one that can run any program, given enough time and memory.

## The journey: from NAND to Tetris

The name describes the path the course takes. It starts with a single,
very simple component, the NAND gate, and ends with a game of Tetris running
on the computer built from it. Every step builds only on the previous ones:

```
  Tetris, Pong, ...              programs written in a high-level language
        ^
  Operating system               memory management, screen, keyboard, maths
        ^
  Compiler                       translates Jack (a Java-like language)
        ^
  Virtual machine                a simple stack machine
        ^
  Assembler                      translates assembly into machine code
        ^
  Computer (Hack)                CPU + memory: runs machine code
        ^
  CPU, ALU, registers, RAM       arithmetic, memory, control
        ^
  Logic gates                    AND, OR, NOT, XOR, multiplexers, adders
        ^
  NAND gate                      the only thing given
```

The first half of the course (projects 1 to 6) is about **hardware**: it goes
from the NAND gate up to the Hack computer and its assembler. The second half
(projects 7 to 12) is about **software**: a virtual machine, a compiler for a
small language called Jack, and an operating system.

This report covers the hardware half, but with one important difference.
In the original course, the chips are described in a simple hardware
description language and tested in a *simulator*. Here the same computer
is built on a **real chip**, an FPGA, so it runs on an actual circuit board
you can hold in your hand.

## The idea of abstraction

The most important idea in Nand to Tetris is **abstraction**. Each layer
uses the layer below it only through a clear *interface*: what it does, not
how it does it.

When you build an adder, you use AND and XOR gates without thinking about
how those are made from NAND gates. When you build the CPU, you use the
adder without thinking about its gates. When you write a program in
assembly, you use the CPU's instructions without thinking about the adder.

Software works the same way. When you call `sort()` in Python, you don't
think about the sorting algorithm inside. The only difference is that in
hardware, the "functions" are physical circuits.

Abstraction is what makes it possible for a person to understand, and
build, something as complicated as a computer: at any moment you only
have to think about one layer.

## Hack in this project

The Hack computer in this report has an earlier history too. In 2013, the
author worked through Nand to Tetris and built the Hack CPU in VHDL (another
hardware description language) on the same Basys-2 board used here. That
original version is kept in the project's `legacy/` folder. For this report
the design was rewritten in Verilog with detailed comments, in
`projects/hack/`, and it is the version the following chapters describe.

The FPGA version differs from the book's Hack in a few practical ways,
because the Basys-2 board is small:

| | Hack in the book | Hack on the Basys-2 |
|---|---|---|
| Program memory (ROM) | 32 768 words | 1 024 words |
| Data memory (RAM) | 16 384 words | 2 048 words |
| Screen | 512 x 256 pixels, black and white | none; a 4-digit display shows one RAM word |
| Keyboard | yes | none; switches choose which RAM word to show |
| Speed | whatever the simulator on your PC manages | 1 million instructions per second, or 2 per second to watch it work |

The CPU itself, its instructions and its behaviour are exactly as the book
specifies, so every Hack program that fits in the smaller memories runs
unchanged.
