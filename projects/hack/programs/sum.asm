// sum.asm: RAM[1] = 1 + 2 + ... + 10 = 55
// On the board: SW0 up (address 1), the display shows 0037 (55 in hex).
//
// Variables: i and sum are symbols the assembler places in RAM from
// address 16 on (i = RAM[16], sum = RAM[17]).

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
