// add.asm: RAM[0] = 2 + 3
// On the board: all switches down, the display shows 0005.

    @2          // A = 2
    D=A         // D = 2
    @3          // A = 3
    D=D+A       // D = 2 + 3
    @0          // A = 0: the address to write to
    M=D         // RAM[0] = D
(END)
    @END        // stop here: jump to END forever
    0;JMP
