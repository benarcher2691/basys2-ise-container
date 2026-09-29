// =============================================================================
// vga_timing: the sync signals and pixel position for a VGA monitor,
// 640 x 480 pixels at 60 frames per second.
//
// How a VGA picture is drawn
// --------------------------
// A VGA monitor draws the picture like a book is read: pixel by pixel from
// left to right along a line, then line by line from top to bottom. The
// computer sends the colour of the current pixel on three analogue wires
// (red, green, blue), and two sync signals tell the monitor where it is:
//
//   hsync  a short pulse after every line   ("go back to the left edge")
//   vsync  a short pulse after every frame  ("go back to the top")
//
// Around the visible picture there is an invisible border, left over from
// cathode-ray tube monitors, which needed time to move the electron beam back.
// Each line and each frame is therefore split into four parts:
//
//   one line (in pixels):
//   |<------- visible 640 ------->|<-FP 16->|<-sync 96->|<-BP 48->|
//   hsync ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾|___________|‾‾‾‾‾‾‾‾‾
//   total 800 pixels per line
//
//   one frame (in lines):
//   visible 480 | front porch 10 | sync 2 | back porch 33  = 525 lines
//
// ("front porch" and "back porch" are the blank parts before and after the
// sync pulse.) For this mode both sync pulses are ACTIVE LOW.
//
// The pixel rate is 800 x 525 x 60 = 25.2 million pixels per second; the
// standard says 25.175 MHz. Here the board's 50 MHz clock with a pixel
// enable on every second cycle gives 25 MHz, which is 0.7 % slow: 59.5
// frames per second instead of 60, well within what monitors accept.
//
// What this module does
// ---------------------
// Two counters walk through all 800 x 525 positions, one step per pixel
// (every clock cycle with pix_ce = 1). From them it derives:
//   x, y      the current pixel position (0..799, 0..524); x < 640 and
//             y < 480 is the visible picture
//   visible   1 while the position is inside the visible picture
//   hsync, vsync
//
// All outputs are registered (they change on the same clock edge), so the
// sync pulses are clean and line up exactly with the pixel position.
// =============================================================================
`timescale 1ns / 1ps

module vga_timing (
    input  wire       clk,
    input  wire       pix_ce,      // advance one pixel on this clock edge
    output reg  [9:0] x       = 10'd0,
    output reg  [9:0] y       = 10'd0,
    output reg        visible = 1'b0,
    output reg        hsync   = 1'b1,
    output reg        vsync   = 1'b1
);
    // Horizontal timing, in pixels.
    localparam H_VISIBLE = 640;
    localparam H_FRONT   = 16;
    localparam H_SYNC    = 96;
    localparam H_BACK    = 48;
    localparam H_TOTAL   = H_VISIBLE + H_FRONT + H_SYNC + H_BACK;   // 800

    // Vertical timing, in lines.
    localparam V_VISIBLE = 480;
    localparam V_FRONT   = 10;
    localparam V_SYNC    = 2;
    localparam V_BACK    = 33;
    localparam V_TOTAL   = V_VISIBLE + V_FRONT + V_SYNC + V_BACK;   // 525

    // ------------------------------------------------------------------
    // Position counters: x counts pixels in a line; at the end of a line it
    // wraps to 0 and y moves to the next line.
    // ------------------------------------------------------------------
    reg [9:0] h_count = 10'd0;
    reg [9:0] v_count = 10'd0;

    wire end_of_line  = (h_count == H_TOTAL - 1);
    wire end_of_frame = (v_count == V_TOTAL - 1);

    always @(posedge clk) begin
        if (pix_ce) begin
            if (end_of_line) begin
                h_count <= 10'd0;
                v_count <= end_of_frame ? 10'd0 : v_count + 10'd1;
            end else begin
                h_count <= h_count + 10'd1;
            end
        end
    end

    // ------------------------------------------------------------------
    // Outputs, registered on the same pixel step. The sync pulses sit
    // between the front and back porch; they are active low.
    // ------------------------------------------------------------------
    always @(posedge clk) begin
        if (pix_ce) begin
            x       <= h_count;
            y       <= v_count;
            visible <= (h_count < H_VISIBLE) && (v_count < V_VISIBLE);
            hsync   <= !((h_count >= H_VISIBLE + H_FRONT) &&
                         (h_count <  H_VISIBLE + H_FRONT + H_SYNC));
            vsync   <= !((v_count >= V_VISIBLE + V_FRONT) &&
                         (v_count <  V_VISIBLE + V_FRONT + V_SYNC));
        end
    end
endmodule
