// =============================================================================
// vga_text: 40 x 30 characters of uppercase text on a VGA monitor
// (640 x 480 at 60 Hz), white on blue, with a blinking cursor.
//
// From pixel position to pixel colour
// -----------------------------------
// The screen is divided into character cells of 16 x 16 pixels: 640 / 16 =
// 40 columns and 480 / 16 = 30 rows. Each character is an 8 x 8 picture
// drawn twice as large, so every picture pixel covers 2 x 2 screen pixels.
//
// For the pixel at screen position (x, y), in binary:
//
//     x = cccccc ppp s      c = column (x / 16), p = pixel column in the
//     y =  rrrrr qqq t          character (0..7), s = which half of the
//                               doubled pixel (ignored)
//                           r = row (y / 16), q = pixel row in the
//                               character, t = ignored
//
// so no division is needed, only picking bits. Then, for every pixel:
//
//   1. text RAM:  which character is in cell (column, row)?
//   2. char ROM:  what does row q of that character look like? (8 bits)
//   3. pick bit p of those 8 bits: 1 = text colour, 0 = background
//
// A pipeline
// ----------
// Steps 1 and 2 are block RAM reads, and each takes one clock edge. So the
// colour for a pixel is only known two pixel steps after its position. The
// design works like an assembly line: at every pixel step, each stage works
// on a different pixel and passes its result to the next stage:
//
//   pixel step:    n        n+1          n+2          n+3
//   stage 1        read     -
//                  text RAM
//   stage 2                 read
//                           char ROM
//   stage 3                              choose
//                                        colour
//   output                                            colour on the wire
//
// The sync signals and the "visible" flag must arrive at the monitor at the
// same moment as the colour of their pixel, so they travel through the same
// number of stages, delayed in registers.
//
// Characters
// ----------
// The text RAM holds ASCII codes. The character map has 64 glyphs for codes
// 0x20..0x5F (space to underscore). Lowercase letters 0x60..0x7F are shown
// as their uppercase versions (code - 0x40); anything else as a space.
// =============================================================================
`timescale 1ns / 1ps

module vga_text #(
    parameter FONT_FILE   = "font.hex",
    parameter SCREEN_FILE = "screen.hex",
    parameter CURSOR_COL  = 0,          // where the blinking cursor sits
    parameter CURSOR_ROW  = 28
) (
    input  wire       mclk,             // 50 MHz board clock
    output reg  [2:0] vga_red   = 3'd0,
    output reg  [2:0] vga_green = 3'd0,
    output reg  [1:0] vga_blue  = 2'd0,
    output reg        vga_hsync = 1'b1,
    output reg        vga_vsync = 1'b1
);
    localparam [7:0] TEXT_COLOUR       = 8'b111_111_11;   // white
    localparam [7:0] BACKGROUND_COLOUR = 8'b000_000_10;   // dark blue

    // ------------------------------------------------------------------
    // Pixel enable (25 MHz) and screen position.
    // ------------------------------------------------------------------
    reg pix_ce = 1'b0;

    always @(posedge mclk)
        pix_ce <= ~pix_ce;

    wire [9:0] x, y;
    wire       visible, hsync, vsync;

    vga_timing timing (
        .clk (mclk), .pix_ce (pix_ce),
        .x (x), .y (y), .visible (visible), .hsync (hsync), .vsync (vsync)
    );

    // ------------------------------------------------------------------
    // Cursor blink: a free-running counter; its top bit changes about
    // every 0.34 s (2^24 cycles at 50 MHz).
    // ------------------------------------------------------------------
    reg [24:0] blink_count = 25'd0;

    always @(posedge mclk)
        blink_count <= blink_count + 25'd1;

    wire blink = blink_count[24];

    // ------------------------------------------------------------------
    // Stage 1: look up the character in the cell under (x, y).
    // Cell address = row * 40 + column = row * 32 + row * 8 + column.
    // ------------------------------------------------------------------
    wire [5:0]  column = x[9:4];
    wire [4:0]  row    = y[8:4];
    wire [10:0] cell_addr = {row, 5'd0} + {row, 3'd0} + column;

    wire [7:0] ascii;

    text_ram #(.INIT_FILE (SCREEN_FILE)) text (
        .clk (mclk),
        .we_a (1'b0), .addr_a (11'd0), .din_a (8'd0),   // nothing writes yet
        .ce_b (pix_ce), .addr_b (cell_addr), .dout_b (ascii)
    );

    // What travels along with the pixel through stage 1.
    reg [2:0] glyph_row_1 = 3'd0, glyph_col_1 = 3'd0;
    reg       visible_1 = 1'b0, hsync_1 = 1'b1, vsync_1 = 1'b1, cursor_1 = 1'b0;

    always @(posedge mclk)
        if (pix_ce) begin
            glyph_row_1 <= y[3:1];
            glyph_col_1 <= x[3:1];
            visible_1   <= visible;
            hsync_1     <= hsync;
            vsync_1     <= vsync;
            cursor_1    <= (column == CURSOR_COL) && (row == CURSOR_ROW);
        end

    // ------------------------------------------------------------------
    // Stage 2: ASCII code -> glyph number, then read that glyph's row.
    // ------------------------------------------------------------------
    reg [5:0] glyph;

    always @(*) begin
        if (ascii >= 8'h20 && ascii < 8'h60)
            glyph = ascii - 8'h20;          // space .. underscore
        else if (ascii >= 8'h60 && ascii < 8'h80)
            glyph = ascii - 8'h40;          // lowercase -> uppercase
        else
            glyph = 6'd0;                   // anything else: space
    end

    wire [7:0] glyph_bits;

    char_rom #(.INIT_FILE (FONT_FILE)) font (
        .clk (mclk), .ce (pix_ce),
        .glyph (glyph), .row (glyph_row_1),
        .bits (glyph_bits)
    );

    reg [2:0] glyph_col_2 = 3'd0;
    reg       visible_2 = 1'b0, hsync_2 = 1'b1, vsync_2 = 1'b1, cursor_2 = 1'b0;

    always @(posedge mclk)
        if (pix_ce) begin
            glyph_col_2 <= glyph_col_1;
            visible_2   <= visible_1;
            hsync_2     <= hsync_1;
            vsync_2     <= vsync_1;
            cursor_2    <= cursor_1;
        end

    // ------------------------------------------------------------------
    // Stage 3: pick this pixel's bit (bit 7 = leftmost), invert it in the
    // cursor cell while the cursor is on, and choose the colour. Outside
    // the visible picture the colour must be black.
    // ------------------------------------------------------------------
    wire lit = glyph_bits[7 - glyph_col_2] ^ (cursor_2 && blink);

    always @(posedge mclk)
        if (pix_ce) begin
            vga_hsync <= hsync_2;
            vga_vsync <= vsync_2;
            if (!visible_2)
                {vga_red, vga_green, vga_blue} <= 8'd0;
            else
                {vga_red, vga_green, vga_blue} <= lit ? TEXT_COLOUR : BACKGROUND_COLOUR;
        end
endmodule
