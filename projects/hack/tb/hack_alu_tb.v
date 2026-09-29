// =============================================================================
// hack_alu_tb: checks the ALU against the 18 functions of the Hack spec.
//
// For every function the test uses a few hand-picked inputs (0, 1, -1, the
// largest and smallest 16-bit numbers) plus random ones, and compares out,
// zr and ng with values computed directly in the testbench.
// =============================================================================
`timescale 1ns / 1ps

module hack_alu_tb;
    reg  [15:0] x, y;
    reg  [5:0]  ctrl;                 // zx nx zy ny f no
    wire [15:0] out;
    wire        zr, ng;

    hack_alu dut (
        .x (x), .y (y),
        .zx (ctrl[5]), .nx (ctrl[4]), .zy (ctrl[3]),
        .ny (ctrl[2]), .f  (ctrl[1]), .no (ctrl[0]),
        .out (out), .zr (zr), .ng (ng)
    );

    // The 18 official functions: control bits and a name.
    reg [5:0]   codes [0:17];
    reg [8*4:1] names [0:17];

    // Expected result of function number k for the current x and y.
    function [15:0] expected(input integer k, input [15:0] a, input [15:0] b);
        case (k)
            0:  expected = 16'd0;       1:  expected = 16'd1;
            2:  expected = 16'hFFFF;    3:  expected = a;
            4:  expected = b;           5:  expected = ~a;
            6:  expected = ~b;          7:  expected = -a;
            8:  expected = -b;          9:  expected = a + 1;
            10: expected = b + 1;       11: expected = a - 1;
            12: expected = b - 1;       13: expected = a + b;
            14: expected = a - b;       15: expected = b - a;
            16: expected = a & b;       default: expected = a | b;
        endcase
    endfunction

    integer k, n, errors = 0, checks = 0;
    reg [15:0] want;

    task check;
        begin
            #1;   // let the combinational logic settle
            want = expected(k, x, y);
            checks = checks + 1;
            if (out !== want || zr !== (want == 0) || ng !== want[15]) begin
                $display("FAIL %s x=%h y=%h: out=%h zr=%b ng=%b, expected %h",
                         names[k], x, y, out, zr, ng, want);
                errors = errors + 1;
            end
        end
    endtask

    // Hand-picked interesting values.
    reg [15:0] special [0:4];

    integer i, j;
    initial begin
        codes[0]  = 6'b101010; names[0]  = "0";
        codes[1]  = 6'b111111; names[1]  = "1";
        codes[2]  = 6'b111010; names[2]  = "-1";
        codes[3]  = 6'b001100; names[3]  = "x";
        codes[4]  = 6'b110000; names[4]  = "y";
        codes[5]  = 6'b001101; names[5]  = "!x";
        codes[6]  = 6'b110001; names[6]  = "!y";
        codes[7]  = 6'b001111; names[7]  = "-x";
        codes[8]  = 6'b110011; names[8]  = "-y";
        codes[9]  = 6'b011111; names[9]  = "x+1";
        codes[10] = 6'b110111; names[10] = "y+1";
        codes[11] = 6'b001110; names[11] = "x-1";
        codes[12] = 6'b110010; names[12] = "y-1";
        codes[13] = 6'b000010; names[13] = "x+y";
        codes[14] = 6'b010011; names[14] = "x-y";
        codes[15] = 6'b000111; names[15] = "y-x";
        codes[16] = 6'b000000; names[16] = "x&y";
        codes[17] = 6'b010101; names[17] = "x|y";

        special[0] = 16'h0000; special[1] = 16'h0001; special[2] = 16'hFFFF;
        special[3] = 16'h7FFF; special[4] = 16'h8000;

        for (k = 0; k < 18; k = k + 1) begin
            ctrl = codes[k];
            for (i = 0; i < 5; i = i + 1)
                for (j = 0; j < 5; j = j + 1) begin
                    x = special[i]; y = special[j]; check;
                end
            for (n = 0; n < 200; n = n + 1) begin
                x = $random; y = $random; check;
            end
        end

        if (errors == 0) $display("PASS: hack_alu, %0d checks", checks);
        else             $display("FAIL: hack_alu, %0d of %0d checks failed", errors, checks);
        $finish;
    end
endmodule
