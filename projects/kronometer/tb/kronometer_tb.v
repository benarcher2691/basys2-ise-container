// =============================================================================
// kronometer_tb: simulation test of the stopwatch (run with `make sim`).
//
// The clock is scaled down so the simulation is quick: CLK_HZ = 1000 and
// TICK_HZ = 10 give one tenth of a second every 100 clock cycles. The test
// presses buttons, waits, and compares the four digits with the expected
// time. It prints PASS or FAIL at the end.
// =============================================================================
`timescale 1ns / 1ps

module kronometer_tb;
    localparam CYCLES_PER_TICK = 100;   // CLK_HZ / TICK_HZ below

    reg        mclk = 1'b0;
    reg  [3:0] btn  = 4'b0000;
    wire [3:0] an;
    wire [6:0] seg;
    wire       dp;

    kronometer #(
        .CLK_HZ   (1000),
        .TICK_HZ  (10),
        .DIGIT_HZ (250)       // 4 cycles per digit
    ) dut (
        .mclk (mclk), .btn (btn), .an (an), .seg (seg), .dp (dp)
    );

    always #5 mclk = ~mclk;   // clock period 10 ns (the value doesn't matter)

    integer errors = 0;

    // Wait a number of clock cycles.
    task cycles(input integer n);
        repeat (n) @(posedge mclk);
    endtask

    // Hold a button for a few cycles, like a short press.
    task press(input integer b);
        begin
            btn[b] = 1'b1;
            cycles(5);
            btn[b] = 1'b0;
        end
    endtask

    // Compare the time with M.SS.t = m, s1 s0, t.
    task expect_time(input [3:0] m, input [3:0] s1, input [3:0] s0, input [3:0] t);
        begin
            if ({dut.minutes, dut.tens, dut.seconds, dut.tenths} !== {m, s1, s0, t}) begin
                $display("FAIL at %0t: time is %h.%h%h.%h, expected %h.%h%h.%h", $time,
                         dut.minutes, dut.tens, dut.seconds, dut.tenths, m, s1, s0, t);
                errors = errors + 1;
            end else
                $display("ok   time %h.%h%h.%h", m, s1, s0, t);
        end
    endtask

    // Seven-segment patterns (active low) for checking the display.
    function [6:0] pattern(input [3:0] v);
        case (v)
            4'd0: pattern = 7'b1000000;  4'd1: pattern = 7'b1111001;
            4'd2: pattern = 7'b0100100;  4'd5: pattern = 7'b0010010;
            default: pattern = 7'bxxxxxxx;
        endcase
    endfunction

    // Wait until the display lights the digit selected by anode pattern a,
    // then check its segments and decimal point.
    task expect_digit(input [3:0] a, input [3:0] v, input point);
        begin
            while (an !== a) @(negedge mclk);
            if (seg !== pattern(v) || dp !== ~point) begin
                $display("FAIL: an=%b shows seg=%b dp=%b, expected %b dp=%b",
                         an, seg, dp, pattern(v), ~point);
                errors = errors + 1;
            end else
                $display("ok   display an=%b shows %0d%s", a, v, point ? "." : "");
            @(negedge mclk);
        end
    endtask

    initial begin
        // After configuration: stopped at 0.00.0.
        cycles(1000);
        expect_time(0, 0, 0, 0);

        // Start, run 12.5 s (125 tenths), stop. Stopping half a tenth after
        // a whole number of tenths keeps us clear of the tick edges.
        press(3);
        cycles(125 * CYCLES_PER_TICK + CYCLES_PER_TICK / 2);
        press(2);
        expect_time(0, 1, 2, 5);

        // The display shows 0.12.5: check all four digits and both points.
        expect_digit(4'b0111, 0, 1);   // leftmost: minutes, with point
        expect_digit(4'b1011, 1, 0);   // tens of seconds
        expect_digit(4'b1101, 2, 1);   // seconds, with point
        expect_digit(4'b1110, 5, 0);   // tenths

        // Stopped: the time stays frozen.
        cycles(50 * CYCLES_PER_TICK);
        expect_time(0, 1, 2, 5);

        // Continue for another 60 s: 1.12.5.
        press(3);
        cycles(600 * CYCLES_PER_TICK);
        expect_time(1, 1, 2, 5);

        // Reset: back to 0.00.0 and stopped.
        press(0);
        cycles(20 * CYCLES_PER_TICK);
        expect_time(0, 0, 0, 0);

        // Run to 9.59.9 (5999 tenths), then one more tenth wraps to 0.00.0.
        press(3);
        cycles(5999 * CYCLES_PER_TICK);
        expect_time(9, 5, 9, 9);
        cycles(CYCLES_PER_TICK);
        expect_time(0, 0, 0, 0);

        if (errors == 0) $display("PASS: kronometer");
        else             $display("FAIL: kronometer, %0d errors", errors);
        $finish;
    end
endmodule
