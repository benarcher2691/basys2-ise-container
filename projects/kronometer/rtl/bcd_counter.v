// =============================================================================
// bcd_counter: one decimal digit that counts 0, 1, ... MAX, 0, 1, ...
//
// "BCD" (binary-coded decimal) means each decimal digit is kept in its own
// 4-bit group, instead of storing the whole number in binary. That makes the
// display trivial: every 4-bit group goes straight to one 7-segment digit.
//
// Chaining digits
// ---------------
// Counters are chained through "enable" and "carry": a digit only advances
// when its enable is high, and it raises carry exactly when it is enabled
// AND about to wrap from MAX back to 0. Feeding one digit's carry into the
// next digit's enable gives a multi-digit counter, just like the wheels of a
// mechanical odometer:
//
//     tick -> [tenths 0..9] -carry-> [seconds 0..9] -carry-> [tens 0..5] -> ...
//
// Everything runs on the same clock; "enable" only says whether this clock
// edge should count. This is the recommended style on FPGAs, instead of
// clocking the next digit from the previous digit's output.
//
// Parameters
//   MAX   the highest value before wrapping (9 for a normal digit, 5 for the
//         tens-of-seconds digit of a clock)
// =============================================================================
`timescale 1ns / 1ps

module bcd_counter #(
    parameter [3:0] MAX = 4'd9
) (
    input  wire       clk,
    input  wire       clear,    // synchronous: back to 0 on the next edge
    input  wire       enable,   // count on this clock edge
    output reg  [3:0] value = 4'd0,
    output wire       carry     // this edge wraps MAX -> 0: enable the next digit
);
    assign carry = enable && (value == MAX);

    always @(posedge clk) begin
        if (clear)
            value <= 4'd0;
        else if (enable)
            value <= (value == MAX) ? 4'd0 : value + 4'd1;
    end
endmodule
