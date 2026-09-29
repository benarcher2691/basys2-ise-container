// =============================================================================
// hack_ram: data memory, 2**ADDR_WIDTH words of 16 bits, with two ports.
//
//   Port A  read and write: used by the CPU (the "M" of Hack instructions).
//   Port B  read only: used by the display to show any word while the CPU
//           keeps running.
//
// FPGA block RAMs have two independent ports built in, so this costs nothing
// extra. Synthesis recognizes the pattern below (one array, two always blocks
// on the same clock, one of them writing) and maps it onto block RAM.
//
// Timing: like hack_rom, reads are synchronous; dout_a and dout_b show the
// word at their address after the next rising clock edge. A write happens at
// the rising clock edge when we = 1. On that same edge dout_a shows the
// OLD word ("read first"); the new word appears one edge later.
//
// The initial contents come from INIT_FILE (one 16-bit binary word per line,
// like a .hack file); words the file doesn't cover start at 0.
//
// Parameters
//   ADDR_WIDTH  number of address bits (11 = 2048 words = 2 block RAMs)
//   INIT_FILE   initial contents, looked up in the directory where synthesis
//               or simulation runs
// =============================================================================
`timescale 1ns / 1ps

module hack_ram #(
    parameter ADDR_WIDTH = 11,
    parameter INIT_FILE  = "ram.hack"
) (
    input  wire                  clk,

    // Port A: CPU
    input  wire                  we_a,
    input  wire [ADDR_WIDTH-1:0] addr_a,
    input  wire [15:0]           din_a,
    output reg  [15:0]           dout_a = 16'h0000,

    // Port B: display (read only)
    input  wire [ADDR_WIDTH-1:0] addr_b,
    output reg  [15:0]           dout_b = 16'h0000
);
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [15:0] memory [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            memory[i] = 16'h0000;
        $readmemb(INIT_FILE, memory);
    end

    // Port A: write when we_a, and always read (the old word, see above).
    always @(posedge clk) begin
        if (we_a)
            memory[addr_a] <= din_a;
        dout_a <= memory[addr_a];
    end

    // Port B: read only.
    always @(posedge clk)
        dout_b <= memory[addr_b];
endmodule
