// =============================================================================
// char_rom: the character map (often called a "font ROM" or "character
// generator"). It holds the picture of each character.
//
// 64 characters, from space (ASCII 0x20) to underscore (0x5F): space,
// punctuation, digits and the uppercase letters. Each character is a grid of
// 8 x 8 pixels, stored as 8 bytes, one per row, with the leftmost pixel in
// the most significant bit. The letter A:
//
//     row 0   0x30   ..##....
//     row 1   0x78   .####...
//     row 2   0xCC   ##..##..
//     row 3   0xCC   ##..##..
//     row 4   0xFC   ######..
//     row 5   0xCC   ##..##..
//     row 6   0xCC   ##..##..
//     row 7   0x00   ........
//
// Address = glyph number (0..63) x 8 + row (0..7), which in binary is simply
// the glyph number followed by the 3 row bits: {glyph, row}. 64 x 8 = 512
// bytes = 4 kbit, a quarter of one block RAM.
//
// The contents come from mem/font.hex (made by tools/make_font.py from the
// public domain font8x8), read with $readmemh when the design is built.
// Like the Hack ROM, the read is synchronous: the byte appears after the
// next clock edge with ce = 1.
// =============================================================================
`timescale 1ns / 1ps

module char_rom #(
    parameter INIT_FILE = "font.hex"
) (
    input  wire       clk,
    input  wire       ce,
    input  wire [5:0] glyph,   // which character, 0 = space ... 63 = '_'
    input  wire [2:0] row,     // which pixel row of it, 0 = top
    output reg  [7:0] bits = 8'h00
);
    reg [7:0] memory [0:511];

    initial $readmemh(INIT_FILE, memory);

    always @(posedge clk)
        if (ce)
            bits <= memory[{glyph, row}];
endmodule
