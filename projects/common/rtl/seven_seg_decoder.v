// =============================================================================
// seven_seg_decoder: turn a 4-bit value (0..F) into the segment pattern that
// shows it as a hexadecimal digit on a 7-segment display.
//
// Segment naming (the standard a..g, as printed on the Basys-2):
//
//          a
//        -----
//     f |     | b
//       |  g  |
//        -----
//     e |     | c
//       |     |
//        -----
//          d
//
// Output bit order: seg[0] = a, seg[1] = b, ... seg[6] = g.
//
// On the Basys-2 the segments are ACTIVE LOW: driving a segment line to 0
// turns that segment on. So "8" (all segments on) is 7'b000_0000, and a
// blank digit is 7'b111_1111.
//
// This is pure combinational logic: a lookup table with 16 entries. XST
// turns it into seven 4-input LUTs, one per segment.
// =============================================================================
`timescale 1ns / 1ps

module seven_seg_decoder (
    input  wire [3:0] value,   // the digit to show, 0..15
    output reg  [6:0] seg      // segments g..a, active low
);
    always @(*) begin
        case (value)
            //                        gfedcba
            4'h0:    seg = 7'b1000000;   // 0: all but g
            4'h1:    seg = 7'b1111001;   // 1: b, c
            4'h2:    seg = 7'b0100100;   // 2: a, b, g, e, d
            4'h3:    seg = 7'b0110000;   // 3: a, b, g, c, d
            4'h4:    seg = 7'b0011001;   // 4: f, g, b, c
            4'h5:    seg = 7'b0010010;   // 5: a, f, g, c, d
            4'h6:    seg = 7'b0000010;   // 6: all but b
            4'h7:    seg = 7'b1111000;   // 7: a, b, c
            4'h8:    seg = 7'b0000000;   // 8: all segments
            4'h9:    seg = 7'b0010000;   // 9: all but e
            4'hA:    seg = 7'b0001000;   // A: all but d
            4'hB:    seg = 7'b0000011;   // b: lower-case, all but a and b
            4'hC:    seg = 7'b1000110;   // C: a, f, e, d
            4'hD:    seg = 7'b0100001;   // d: lower-case, all but a and f
            4'hE:    seg = 7'b0000110;   // E: all but b and c
            default: seg = 7'b0001110;   // F: a, f, g, e   (value 4'hF)
        endcase
    end
endmodule
