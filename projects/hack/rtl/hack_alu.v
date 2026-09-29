// =============================================================================
// hack_alu: the arithmetic logic unit of the Hack computer (nand2tetris).
//
// The ALU combines two 16-bit inputs x and y. Six control bits, applied in
// this order, select what it computes:
//
//     zx  x = 0          zero the x input
//     nx  x = !x         bitwise-negate the x input (after zx)
//     zy  y = 0          zero the y input
//     ny  y = !y         bitwise-negate the y input (after zy)
//     f   out = x + y    if f = 1, else  out = x & y
//     no  out = !out     bitwise-negate the output
//
// These few steps are enough for 18 useful functions. For example
// zx nx zy ny f no = 0 1 0 0 1 1 gives !(!x + y) = x - y, because in two's
// complement !a = -a - 1. The full table (the "comp" field of a Hack
// C-instruction, a=0 column uses y = A, a=1 column uses y = M):
//
//     zx nx zy ny f no   out        zx nx zy ny f no   out
//      1  0  1  0 1  0   0           0  0  1  1 1  0   x-1  (D-1)
//      1  1  1  1 1  1   1           1  1  0  0 1  0   y-1  (A-1)
//      1  1  1  0 1  0   -1          0  0  0  0 1  0   x+y  (D+A)
//      0  0  1  1 0  0   x   (D)     0  1  0  0 1  1   x-y  (D-A)
//      1  1  0  0 0  0   y   (A)     0  0  0  1 1  1   y-x  (A-D)
//      0  0  1  1 0  1   !x          0  0  0  0 0  0   x&y  (D&A)
//      1  1  0  0 0  1   !y          0  1  0  1 0  1   x|y  (D|A)
//      0  0  1  1 1  1   -x
//      1  1  0  0 1  1   -y
//      0  1  1  1 1  1   x+1
//      1  1  0  1 1  1   y+1
//
// Two status outputs describe the result; the CPU uses them for jumps:
//     zr = 1 if out == 0
//     ng = 1 if out < 0   (two's complement: the top bit is the sign)
//
// This is purely combinational: out, zr and ng follow x, y and the control
// bits after the logic delay, without any clock.
// =============================================================================
`timescale 1ns / 1ps

module hack_alu (
    input  wire [15:0] x,
    input  wire [15:0] y,
    input  wire        zx, nx, zy, ny, f, no,
    output wire [15:0] out,
    output wire        zr,
    output wire        ng
);
    // Pre-process the inputs: optionally zero, then optionally negate.
    wire [15:0] x_zeroed = zx ? 16'h0000 : x;
    wire [15:0] x_final  = nx ? ~x_zeroed : x_zeroed;

    wire [15:0] y_zeroed = zy ? 16'h0000 : y;
    wire [15:0] y_final  = ny ? ~y_zeroed : y_zeroed;

    // The function: 16-bit addition (the carry out of bit 15 is dropped,
    // as in the Hack design) or bitwise AND.
    wire [15:0] result = f ? (x_final + y_final) : (x_final & y_final);

    // Post-process the output: optionally negate.
    assign out = no ? ~result : result;

    // Status flags.
    assign zr = (out == 16'h0000);
    assign ng = out[15];
endmodule
