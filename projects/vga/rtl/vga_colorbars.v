// =============================================================================
// vga_colorbars: three vertical colour bars (red, green, blue) on a VGA
// monitor, 640 x 480 at 60 Hz.
//
//   +----------+----------+----------+
//   |          |          |          |
//   |   red    |  green   |   blue   |    each bar 213 pixels wide
//   |          |          |          |    (640 / 3, the last pixel column
//   |          |          |          |     stays black)
//   +----------+----------+----------+
//
// Colour on the Basys-2
// ---------------------
// A VGA monitor takes three analogue voltages, one per colour, between 0 V
// (dark) and 0.7 V (full brightness). The Basys-2 makes them from digital
// outputs with a simple digital-to-analogue converter: each colour bit
// drives the colour wire through its own resistor, and the more significant
// bits use smaller resistors (510 ohm, 1 kohm, 2 kohm), so they add more
// voltage. The board has 3 bits of red, 3 of green and 2 of blue: 8 bits in
// all, 256 colours.
//
// Outside the visible area the colour outputs must be black (0): monitors
// use the dark border to measure what "black" is.
//
// Structure
//   mclk 50 MHz -> pixel enable (every 2nd cycle = 25 MHz) -> vga_timing
//   vga_timing's x position -> which bar -> colour outputs
// =============================================================================
`timescale 1ns / 1ps

module vga_colorbars (
    input  wire       mclk,          // 50 MHz board clock
    output reg  [2:0] vga_red   = 3'd0,
    output reg  [2:0] vga_green = 3'd0,
    output reg  [1:0] vga_blue  = 2'd0,
    output wire       vga_hsync,
    output wire       vga_vsync
);
    // ------------------------------------------------------------------
    // Pixel enable: 1 on every second clock cycle -> 25 million pixels
    // per second.
    // ------------------------------------------------------------------
    reg pix_ce = 1'b0;

    always @(posedge mclk)
        pix_ce <= ~pix_ce;

    // ------------------------------------------------------------------
    // Where on the screen are we?
    // ------------------------------------------------------------------
    wire [9:0] x, y;
    wire       visible;
    wire       hsync, vsync;

    vga_timing timing (
        .clk     (mclk),
        .pix_ce  (pix_ce),
        .x       (x),
        .y       (y),
        .visible (visible),
        .hsync   (hsync),
        .vsync   (vsync)
    );

    // ------------------------------------------------------------------
    // The picture: choose the colour from the x position. The colour is
    // registered on the next pixel step, so the sync signals are delayed by
    // one pixel too (below) to stay lined up with it.
    // ------------------------------------------------------------------
    localparam BAR = 213;   // bar width in pixels

    reg hsync_d = 1'b1, vsync_d = 1'b1;

    always @(posedge mclk) begin
        if (pix_ce) begin
            hsync_d <= hsync;
            vsync_d <= vsync;

            if (!visible) begin
                {vga_red, vga_green, vga_blue} <= 8'b000_000_00;   // black
            end else if (x < BAR) begin
                {vga_red, vga_green, vga_blue} <= 8'b111_000_00;   // red
            end else if (x < 2 * BAR) begin
                {vga_red, vga_green, vga_blue} <= 8'b000_111_00;   // green
            end else if (x < 3 * BAR) begin
                {vga_red, vga_green, vga_blue} <= 8'b000_000_11;   // blue
            end else begin
                {vga_red, vga_green, vga_blue} <= 8'b000_000_00;   // black
            end
        end
    end

    assign vga_hsync = hsync_d;
    assign vga_vsync = vsync_d;
endmodule
