// =============================================================================
// hack_run_tb: run any Hack program in simulation and print the result.
//
//   make run PROGRAM=programs/sum.hack [STEPS=1000]
//
// Loads the program into the ROM (like the real build), resets the computer,
// executes STEPS instructions (default 1000) and prints the program counter
// and RAM[0..15], the words you can show on the board with SW3..SW0.
// =============================================================================
`timescale 1ns / 1ps

module hack_run_tb;
    reg        mclk = 1'b0;
    reg  [3:0] btn  = 4'b0001;   // start with reset held
    wire [7:0] led;
    wire [3:0] an;
    wire [6:0] seg;
    wire       dp;

    hack_computer #(
        .CLK_HZ (4), .CPU_HZ (1), .SLOW_HZ (1), .DIGIT_HZ (1)
    ) dut (
        .mclk (mclk), .btn (btn), .sw (8'h00),
        .led (led), .an (an), .seg (seg), .dp (dp)
    );

    always #5 mclk = ~mclk;

    integer steps = 1000, done = 0, i;
    reg [15:0] w;

    always @(posedge mclk)
        if (dut.cpu_ce && !dut.reset) done = done + 1;

    initial begin
        if (!$value$plusargs("steps=%d", steps)) steps = 1000;
        repeat (20) @(posedge mclk);
        btn[0] = 1'b0;                     // release reset: the program starts
        while (done < steps) @(posedge mclk);

        $display("after %0d instructions: PC = %0d", done, dut.pc);
        $display("addr   hex    decimal");
        for (i = 0; i < 16; i = i + 1) begin
            w = dut.ram.memory[i];
            $display("RAM[%0d]%s %h  %0d", i, i < 10 ? " " : "", w, $signed(w));
        end
        $finish;
    end
endmodule
