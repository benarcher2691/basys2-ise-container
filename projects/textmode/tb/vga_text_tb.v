// =============================================================================
// vga_text_tb: checks every pixel of the text screen (run with `make sim`).
//
// The testbench looks at the VGA outputs only, like a monitor: it finds the
// pixel position from the sync pulses (48 pixels after the end of hsync is
// the first pixel of a line; the 33rd line after the end of vsync is the
// first visible line). For every visible pixel it computes the expected
// colour itself, from the same font and screen files, and compares.
//
//   frame 1: cursor off (the blink counter starts at 0)
//   frame 2: cursor forced on; this frame is also saved as frame.ppm, an
//            image file you can open to see the screen
// =============================================================================
`timescale 1ns / 1ps

module vga_text_tb;
    reg        mclk = 1'b0;
    wire [2:0] r, g;
    wire [1:0] b;
    wire       hs, vs;

    vga_text dut (
        .mclk (mclk), .vga_red (r), .vga_green (g), .vga_blue (b),
        .vga_hsync (hs), .vga_vsync (vs)
    );

    always #10 mclk = ~mclk;   // 50 MHz

    // The same data the design uses.
    reg [7:0] font   [0:511];
    reg [7:0] screen [0:1199];
    initial begin
        $readmemh("font.hex", font);
        $readmemh("screen.hex", screen);
    end

    // Reference model: the colour of screen pixel (px, py).
    function [7:0] expected(input integer px, input integer py, input cursor_on);
        reg [7:0] code, bits;
        reg [5:0] glyph;
        reg       lit;
        begin
            code = screen[(py / 16) * 40 + (px / 16)];
            if (code >= 8'h20 && code < 8'h60)      glyph = code - 8'h20;
            else if (code >= 8'h60 && code < 8'h80) glyph = code - 8'h40;
            else                                    glyph = 0;
            bits = font[glyph * 8 + (py % 16) / 2];
            lit  = bits[7 - (px % 16) / 2];
            if (cursor_on && px / 16 == 0 && py / 16 == 28) lit = !lit;
            expected = lit ? 8'b111_111_11 : 8'b000_000_10;
        end
    endfunction

    integer hpos = -1, lines = -1, frame = 0, px, py;
    integer errors = 0, checked = 0, lit_pixels = 0, black_errors = 0;
    integer ppm;
    reg     hs_q = 1'b1, vs_q = 1'b1;
    reg [7:0] want;

    always @(posedge mclk) if (dut.pix_ce) begin
        // Positions from the sync pulses (on the pixel just finished).
        if (!vs_q && vs) begin                    // end of vsync: new frame
            frame = frame + 1;
            lines = 0;
            if (frame == 2) begin
                force dut.blink = 1'b1;           // cursor on for frame 2
                ppm = $fopen("frame.ppm", "w");
                $fwrite(ppm, "P3\n640 480\n255\n");
            end
            if (frame == 3) begin
                $fclose(ppm);
                if (errors == 0 && black_errors == 0 && checked == 2 * 640 * 480 && lit_pixels > 0)
                    $display("PASS: vga_text, %0d pixels checked (%0d lit)", checked, lit_pixels);
                else
                    $display("FAIL: vga_text, %0d wrong pixels, %0d not black in the border, %0d checked",
                             errors, black_errors, checked);
                $finish;
            end
        end
        if (!hs_q && hs) begin                    // end of hsync
            hpos = 0;
            if (lines >= 0) lines = lines + 1;
        end else if (hpos >= 0)
            hpos = hpos + 1;
        hs_q = hs; vs_q = vs;

        px = hpos - 48;
        py = lines - 33;
        if (frame >= 1 && hpos >= 0 && lines >= 0) begin
            if (px >= 0 && px < 640 && py >= 0 && py < 480) begin
                want = expected(px, py, frame == 2);
                checked = checked + 1;
                if ({r, g, b} === 8'b111_111_11) lit_pixels = lit_pixels + 1;
                if ({r, g, b} !== want) begin
                    if (errors < 5)
                        $display("FAIL frame %0d pixel (%0d,%0d): %b, expected %b", frame, px, py, {r, g, b}, want);
                    errors = errors + 1;
                end
                if (frame == 2)
                    $fwrite(ppm, "%0d %0d %0d\n", r * 255 / 7, g * 255 / 7, b * 255 / 3);
            end else if ({r, g, b} !== 8'd0)
                black_errors = black_errors + 1;
        end
    end
endmodule
