// Blinky for the Basys-2: LD7..LD4 count slowly in binary, LD3..LD0 follow
// SW3..SW0, and the 7-segment display is off.
module top (
    input  wire       mclk,   // 50 MHz
    input  wire [3:0] sw,
    output wire [7:0] led,
    output wire [3:0] an,     // active low: all high = display off
    output wire [6:0] seg,
    output wire       dp
);
    // 50 MHz / 2^26: bit 25 toggles about every 0.67 s.
    reg [28:0] count = 29'd0;

    always @(posedge mclk)
        count <= count + 1'b1;

    assign led = {count[28:25], sw};
    assign an  = 4'b1111;
    assign seg = 7'b1111111;
    assign dp  = 1'b1;
endmodule
