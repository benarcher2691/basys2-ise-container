// =============================================================================
// hack_rom: instruction memory, 2**ADDR_WIDTH words of 16 bits.
//
// The contents come from a text file with one 16-bit binary word per line,
// which is exactly the ".hack" format the nand2tetris assembler produces.
// $readmemb reads it when the design is loaded: in simulation at time 0, and
// in synthesis XST/yosys put the values into the FPGA's block RAM
// initialization, so they are part of the bitstream. Words the file doesn't
// cover stay 0 (in Hack, 0 is "@0", which does nothing harmful).
//
// Timing: the read is SYNCHRONOUS. The data for address `addr` appears on
// `data` after the next rising clock edge. That is how the FPGA's block RAMs
// work, and it is why reading is described inside `always @(posedge clk)`.
// The computer (hack_computer.v) runs the CPU slowly enough that the new
// instruction is always ready before the CPU needs it.
//
// A Spartan-3E block RAM holds 16 Kbit, so a 1K x 16 ROM fits in one.
//
// Parameters
//   ADDR_WIDTH  number of address bits (10 = 1024 words)
//   INIT_FILE   the program, a .hack file (looked up in the directory where
//               synthesis or simulation runs)
// =============================================================================
`timescale 1ns / 1ps

module hack_rom #(
    parameter ADDR_WIDTH = 10,
    parameter INIT_FILE  = "rom.hack"
) (
    input  wire                  clk,
    input  wire [ADDR_WIDTH-1:0] addr,
    output reg  [15:0]           data = 16'h0000
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [15:0] memory [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 16'h0000;
        $readmemb(INIT_FILE, memory);
    end

    always @(posedge clk)
        data <= memory[addr];
endmodule
