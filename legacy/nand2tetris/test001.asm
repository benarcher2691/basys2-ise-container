 //a := 5
 //b := -5

 //M[0...100] := 0
 
 //if a < b then M[2] = -1 else M[2] = 1
 //if a <= b then M[3] = -1 else M[3] = 1
 //if a > b then M[4] = 1 else M[4] = -1
 //if a >= b then M[5] = 1 else M[5] = -1
 //if a == b then M[6] = -1 else M[6] = 1
 //if a != b then M[7] = 1 else M[7] = -1
 
 // THIS IS A TEST OF ALL JUMP INSTRUCTUIONS
 // AFTER SUCCESSFUL TEST M[0..8] MUST CONTAIN
 // 5, -5, 1, 1, 1, 1, 1, 1, 1
 
 
// M[0] <- 5
@5
D=A
@0
M=D
 
// M[1] <- -5
@5
D=-A
@1
M=D
 
// test JLT
@0
D=M
@1
D=D-M // D = 10
@JLT_TRUE
D;JLT
@1
D=A
@2
M=D
@JLT_END
0;JMP
(JLT_TRUE)
@1
D=-A
@2
M=D
(JLT_END)

// test JLE
@0
D=M
@1
D=D-M // D = 10
@JLE_TRUE
D;JLE
@1
D=A
@3
M=D
@JLE_END
0;JMP
(JLE_TRUE)
@1
D=-A
@3
M=D
(JLE_END)

// test JGT
@0
D=M
@1
D=D-M // D = 10
@JGT_TRUE
D;JGT
@1
D=-A
@4
M=D
@JGT_END
0;JMP
(JGT_TRUE)
@1
D=A
@4
M=D
(JGT_END)

// test JGE
@0
D=M
@1
D=D-M // D = 10
@JGE_TRUE
D;JGE
@1
D=-A
@5
M=D
@JGE_END
0;JMP
(JGE_TRUE)
@1
D=A
@5
M=D
(JGE_END)

// test JEQ
@0
D=M
@1
D=D-M // D = 10
@JEQ_TRUE
D;JEQ
@1
D=A
@6
M=D
@JEQ_END
0;JMP
(JEQ_TRUE)
@1
D=-A
@6
M=D
(JEQ_END)

// test JNE
@0
D=M
@1
D=D-M // D = 10
@JNE_TRUE
D;JNE
@1
D=-A
@7
M=D
@JNE_END
0;JMP
(JNE_TRUE)
@1
D=A
@7
M=D
(JNE_END)

// test JMP
(THE_END)
@42
D=A
@9
M=D
(FINAL)
@FINAL
0;JMP
