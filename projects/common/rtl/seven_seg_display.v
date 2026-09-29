// =============================================================================
// seven_seg_display: drive the Basys-2's 4-digit 7-segment display.
//
// How the display is wired
// ------------------------
// The four digits share the same eight segment lines (a..g and the decimal
// point). Each digit additionally has its own "anode" line that switches the
// whole digit on or off (AN3 = leftmost digit, AN0 = rightmost). Anodes and
// segments are all active low on this board.
//
// So only one digit can show its own pattern at a time. The trick is
// MULTIPLEXING: light digit 0 with its pattern, then digit 1 with its
// pattern, and so on, fast enough that the eye sees all four at once
// (anything above roughly 60 full rounds per second looks steady).
//
// This module shows each digit for 1 / DIGIT_HZ seconds. With the default
// 1 kHz that is 1 ms per digit and 250 complete rounds per second.
//
// Parameters
//   CLK_HZ    frequency of clk
//   DIGIT_HZ  how many times per second the display moves to the next digit
//
// Inputs
//   value     four hex digits, value[15:12] on the leftmost digit
//   dp_on     decimal points to light, dp_on[3] = leftmost (active high here;
//             the module converts to the board's active-low level)
// =============================================================================
`timescale 1ns / 1ps

module seven_seg_display #(
    parameter CLK_HZ   = 50_000_000,
    parameter DIGIT_HZ = 1_000
) (
    input  wire        clk,
    input  wire [15:0] value,
    input  wire [3:0]  dp_on,
    output wire [3:0]  an,    // digit enables, active low
    output wire [6:0]  seg,   // segments g..a, active low
    output wire        dp     // decimal point, active low
);
    // ------------------------------------------------------------------
    // Refresh timer: a counter that wraps every CLK_HZ / DIGIT_HZ clock
    // cycles and produces a one-cycle "next digit" pulse when it wraps.
    // 24 bits covers dividers up to 16.7 million (e.g. 50 MHz / 3 Hz).
    // ------------------------------------------------------------------
    localparam integer DIVIDE = (CLK_HZ / DIGIT_HZ > 0) ? CLK_HZ / DIGIT_HZ : 1;

    reg [23:0] timer = 24'd0;
    wire       next_digit = (timer == DIVIDE - 1);

    always @(posedge clk)
        timer <= next_digit ? 24'd0 : timer + 24'd1;

    // ------------------------------------------------------------------
    // Digit selector: which of the four digits is lit right now (0..3,
    // 3 = leftmost). It advances on every "next digit" pulse.
    // ------------------------------------------------------------------
    reg [1:0] digit = 2'd0;

    always @(posedge clk)
        if (next_digit)
            digit <= digit + 2'd1;   // 3 + 1 wraps to 0 in two bits

    // ------------------------------------------------------------------
    // Pick the 4-bit value and decimal point of the current digit and
    // decode the value into segments.
    // ------------------------------------------------------------------
    reg  [3:0] nibble;

    always @(*) begin
        case (digit)
            2'd3:    nibble = value[15:12];
            2'd2:    nibble = value[11:8];
            2'd1:    nibble = value[7:4];
            default: nibble = value[3:0];
        endcase
    end

    seven_seg_decoder decoder (
        .value (nibble),
        .seg   (seg)
    );

    // ------------------------------------------------------------------
    // Anode and decimal point of the current digit. Like seg, they are
    // derived from the digit register alone, so all three change together
    // right after each "next digit" clock edge. an has exactly one 0.
    // ------------------------------------------------------------------
    assign an = ~(4'b0001 << digit);   // digit 2 -> 4'b1011, lights AN2
    assign dp = ~dp_on[digit];         // light the point if requested
endmodule
