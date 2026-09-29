// =============================================================================
// text_ram: what is on the screen, one byte per character cell.
//
// The screen is 40 columns x 30 rows = 1200 cells. Cell (column, row) is at
// address row x 40 + column, and holds the ASCII code of the character
// shown there. 2048 x 8 bits fits in one block RAM (16 kbit).
//
// This is the idea behind the text screens of classic home computers (and
// the PC's text mode): the program only writes character codes into this
// memory, and the display hardware turns them into pixels, 60 times a
// second, on its own.
//
// Two ports:
//   write port  for whoever changes the text; in this project nothing does
//               yet (we_a is tied to 0), so the text stays as loaded. A CPU
//               such as the Hack computer could write here.
//   read port   for the display, synchronous: the code appears after the
//               next clock edge with ce_b = 1.
//
// The initial text comes from INIT_FILE (one hex byte per line, made from
// mem/screen.txt by tools/make_screen.py).
// =============================================================================
`timescale 1ns / 1ps

module text_ram #(
    parameter INIT_FILE = "screen.hex"
) (
    input  wire        clk,

    // Write port
    input  wire        we_a,
    input  wire [10:0] addr_a,
    input  wire [7:0]  din_a,

    // Read port (display)
    input  wire        ce_b,
    input  wire [10:0] addr_b,
    output reg  [7:0]  dout_b = 8'h20
);
    reg [7:0] memory [0:2047];

    integer i;
    initial begin
        for (i = 0; i < 2048; i = i + 1)
            memory[i] = 8'h20;              // space
        $readmemh(INIT_FILE, memory);
    end

    always @(posedge clk)
        if (we_a)
            memory[addr_a] <= din_a;

    always @(posedge clk)
        if (ce_b)
            dout_b <= memory[addr_b];
endmodule
