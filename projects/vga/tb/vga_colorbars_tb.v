// =============================================================================
// vga_colorbars_tb: checks the VGA timing and picture (run with `make sim`).
//
// Runs two full frames at the real clock speed (50 MHz, 1.68 million clock
// cycles) and measures, in pixels (one pixel = two 50 MHz cycles):
//   - the line length (800) and the hsync pulse (96, active low)
//   - the frame length (525 lines) and the vsync pulse (2 lines)
//   - the back porch: 48 pixels from the end of hsync to the first pixel
//   - one visible line: 213 red, 213 green, 213 blue pixels in that order
//   - the whole frame: exactly 480 lines x 639 coloured pixels, the rest black
// =============================================================================
`timescale 1ns / 1ps

module vga_colorbars_tb;
    reg        mclk = 1'b0;
    wire [2:0] r, g;
    wire [1:0] b;
    wire       hs, vs;

    vga_colorbars dut (
        .mclk (mclk), .vga_red (r), .vga_green (g), .vga_blue (b),
        .vga_hsync (hs), .vga_vsync (vs)
    );

    always #10 mclk = ~mclk;   // 50 MHz

    integer errors = 0;

    task check(input [8*40:1] what, input integer got, input integer want);
        begin
            if (got !== want) begin
                $display("FAIL %0s: %0d, expected %0d", what, got, want);
                errors = errors + 1;
            end else
                $display("ok   %0s: %0d", what, got);
        end
    endtask

    // Everything is counted in pixel steps: clock edges with pix_ce = 1.
    integer pixel = 0;             // pixel steps since the start
    integer hs_fall = -1, hs_prev_fall = -1, hs_rise = -1;
    integer vs_fall = -1, vs_prev_fall = -1, vs_rise = -1;
    integer line_period = 0, hs_width = 0, frame_period = 0, vs_width = 0;
    integer back_porch = -1, coloured = 0, frames = 0, frame_coloured = -1;
    reg     hs_q = 1'b1, vs_q = 1'b1;

    // One visible line: record the colour runs.
    integer n_red = 0, n_green = 0, n_blue = 0, order_ok = 1, line_done = 0;
    integer in_line = 0;
    reg [1:0] last_bar = 0;         // 0 none yet, 1 red, 2 green, 3 blue

    always @(posedge mclk) if (dut.pix_ce) begin
        pixel = pixel + 1;

        // hsync edges
        if (hs_q && !hs) begin
            if (hs_fall >= 0) line_period = pixel - hs_fall;
            hs_fall = pixel;
        end
        if (!hs_q && hs) begin
            hs_width = pixel - hs_fall;
            hs_rise  = pixel;
        end
        // vsync edges
        if (vs_q && !vs) begin
            if (vs_fall >= 0) begin frame_period = pixel - vs_fall; frames = frames + 1; end
            vs_fall = pixel;
            frame_coloured = coloured;   // the frame that just ended
            coloured = 0;
        end
        if (!vs_q && vs) vs_width = pixel - vs_fall;
        hs_q = hs; vs_q = vs;

        // colour
        if ({r, g, b} != 8'd0) begin
            coloured = coloured + 1;
            if (back_porch < 0 && hs_rise >= 0) back_porch = pixel - hs_rise;
        end

        // examine the first visible line after the first vsync
        if (vs_fall >= 0 && !line_done) begin
            if ({r, g, b} != 8'd0) in_line = 1;
            if (in_line) begin
                if      ({r, g, b} == 8'b111_000_00) begin n_red   = n_red + 1;   if (last_bar > 1) order_ok = 0; last_bar = 1; end
                else if ({r, g, b} == 8'b000_111_00) begin n_green = n_green + 1; if (last_bar > 2 || last_bar < 1) order_ok = 0; last_bar = 2; end
                else if ({r, g, b} == 8'b000_000_11) begin n_blue  = n_blue + 1;  if (last_bar < 2) order_ok = 0; last_bar = 3; end
                else if ({r, g, b} == 8'd0) line_done = 1;
                else order_ok = 0;
            end
        end
    end

    initial begin
        // Wait for two complete frames after the first vsync pulse.
        wait (frames == 2);
        check("line length, pixels",   line_period / 1, 800);
        check("hsync pulse, pixels",   hs_width, 96);
        check("frame length, lines",   frame_period / 800, 525);
        check("frame length, pixels",  frame_period, 800 * 525);
        check("vsync pulse, lines",    vs_width / 800, 2);
        check("back porch, pixels",    back_porch, 48);
        check("red pixels in a line",   n_red, 213);
        check("green pixels in a line", n_green, 213);
        check("blue pixels in a line",  n_blue, 213);
        check("bars in order red-green-blue", order_ok, 1);
        check("coloured pixels per frame", frame_coloured, 480 * 639);

        if (errors == 0) $display("PASS: vga_colorbars");
        else             $display("FAIL: vga_colorbars, %0d errors", errors);
        $finish;
    end
endmodule
