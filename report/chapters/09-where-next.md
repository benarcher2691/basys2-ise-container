# Where to go next

You now know how the Hack computer works, from the logic gates to the
programs, and how it becomes a real circuit on an FPGA. The best way to
make that knowledge your own is to change things. Here are some ideas,
roughly from easiest to hardest.

## Programs

Write these in Hack assembly, test them with `make run`, and then try them
on the board.

1. **Maximum.** Store the larger of RAM[0] and RAM[1] in RAM[2]. (The RAM
   starts with RAM[i] = i, so change the initial values in the program first.)
2. **Multiply.** Compute RAM[0] x RAM[1] into RAM[2] by repeated addition.
   How many instructions does 100 x 100 take?
3. **Fibonacci.** Fill RAM[0] to RAM[15] with the Fibonacci numbers 0, 1, 1,
   2, 3, 5, ... and look through them with the switches. Which is the
   largest Fibonacci number that fits in a 16-bit two's complement word?
4. **Watch it run.** With SW7 up the computer executes 2 instructions per
   second and the LEDs show the program counter. Write a program that counts
   down from 9 to 0 in RAM[0], and watch the display and the LEDs together.

## Hardware

These change the Verilog in `projects/hack/rtl/`. Test every change with
`make sim` before building.

1. **Faster.** The CPU runs at 1 MHz, but the timing report says the logic
   could run at 66 MHz. The design needs at least two clock cycles per
   instruction. Change `CPU_HZ` in `hack_computer.v` to run at 25 MHz and
   check that `test001` still works.
2. **An output port.** Make the LEDs show a RAM word instead of the program
   counter, for example whatever the program writes to address 2047. This is
   memory-mapped I/O, like the Hack screen.
3. **An input port.** Let the program read the switches: when it reads
   address 2046, it gets the switch positions instead of RAM. Then write a
   program that adds two 4-bit numbers set on the switches.
4. **Single step.** Add a mode in which each press of BTN1 executes exactly
   one instruction. (You'll need to detect the *moment* the button is
   pressed, and deal with bouncing contacts.)
5. **The Pmod headers.** Drive LEDs on a breadboard through the JA header,
   again memory-mapped.
6. **A screen.** The Basys-2 has a VGA connector. A text or low-resolution
   graphics display, fed from RAM, would bring the computer much closer to
   the book's Hack. This is a real project: VGA needs exact timing, and the
   FPGA has only 4 block RAMs.

## Beyond this project

- **The second half of Nand to Tetris** builds the software: a virtual
  machine, a compiler for the Java-like language Jack, and an operating
  system. The book and `nand2tetris.org` guide you through it.
- **A fully open-source toolchain.** Lattice iCE40 FPGAs, such as the
  iCEstick board, can be programmed entirely with open-source tools (yosys,
  nextpnr, IceStorm). Porting the Hack computer to one would be a good test
  of how portable the Verilog is.
- **Real processors.** RISC-V is a modern, open instruction set. Many
  student projects build small RISC-V CPUs on FPGAs; with what you know
  about Hack, the ideas will look familiar: registers, an ALU, instruction
  decoding, a program counter.
