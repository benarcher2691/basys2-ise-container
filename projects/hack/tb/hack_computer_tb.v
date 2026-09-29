// =============================================================================
// hack_computer_tb: runs programs/test001 on the whole computer.
//
// test001 exercises every conditional jump by comparing a = 5 and b = -5:
//
//   RAM[0] = 5, RAM[1] = -5
//   RAM[2]  "a <  b" ?  -1 : 1   ->  1      RAM[5]  "a >= b" ?  1 : -1  ->  1
//   RAM[3]  "a <= b" ?  -1 : 1   ->  1      RAM[6]  "a == b" ? -1 :  1  ->  1
//   RAM[4]  "a >  b" ?   1 : -1  ->  1      RAM[7]  "a != b" ?  1 : -1  ->  1
//   RAM[9] = 42 when the program reaches its end, then it loops forever at
//   address 108 (FINAL: @FINAL, 0;JMP).
//   RAM[8] isn't written and keeps its initial value 8 (mem/ram_init.hack).
//
// The clock is scaled down (CLK_HZ = 4, CPU_HZ = 1): one instruction every
// 4 cycles, the fastest the design allows is every 2.
// =============================================================================
`timescale 1ns / 1ps

module hack_computer_tb;
    reg        mclk = 1'b0;
    reg  [3:0] btn  = 4'b0001;   // start with reset held
    reg  [7:0] sw   = 8'h00;
    wire [7:0] led;
    wire [3:0] an;
    wire [6:0] seg;
    wire       dp;

    hack_computer #(
        .CLK_HZ   (4),
        .CPU_HZ   (1),
        .SLOW_HZ  (1),
        .DIGIT_HZ (1)
    ) dut (
        .mclk (mclk), .btn (btn), .sw (sw),
        .led (led), .an (an), .seg (seg), .dp (dp)
    );

    always #5 mclk = ~mclk;

    integer errors = 0;

    task expect_ram(input integer addr, input [15:0] want);
        begin
            if (dut.ram.memory[addr] !== want) begin
                $display("FAIL: RAM[%0d] = %h, expected %h", addr, dut.ram.memory[addr], want);
                errors = errors + 1;
            end else
                $display("ok   RAM[%0d] = %h", addr, want);
        end
    endtask

    integer instructions = 0;
    always @(posedge mclk)
        if (dut.cpu_ce && !dut.reset) instructions = instructions + 1;

    initial begin
        // Hold reset for a while, then let the program run.
        repeat (20) @(posedge mclk);
        if (dut.pc !== 0) begin
            $display("FAIL: PC is %0d during reset, expected 0", dut.pc);
            errors = errors + 1;
        end
        btn[0] = 1'b0;

        // Run until the program sits in its final loop (or give up).
        while (!(dut.pc == 108 && dut.ram.memory[9] == 16'd42) && instructions < 5000)
            @(posedge mclk);
        repeat (40) @(posedge mclk);   // a few more rounds of the final loop
        $display("program finished after %0d instructions, PC = %0d", instructions, dut.pc);

        expect_ram(0, 16'd5);
        expect_ram(1, -16'sd5);
        expect_ram(2, 16'd1);
        expect_ram(3, 16'd1);
        expect_ram(4, 16'd1);
        expect_ram(5, 16'd1);
        expect_ram(6, 16'd1);
        expect_ram(7, 16'd1);
        expect_ram(8, 16'd8);
        expect_ram(9, 16'd42);

        if (dut.pc != 108 && dut.pc != 109) begin
            $display("FAIL: PC = %0d, expected the final loop at 108/109", dut.pc);
            errors = errors + 1;
        end

        // The display port: SW = 1 shows RAM[1] = FFFB.
        sw = 8'h01;
        repeat (10) @(posedge mclk);
        if (dut.shown_word !== 16'hFFFB) begin
            $display("FAIL: display shows %h for SW=1, expected FFFB", dut.shown_word);
            errors = errors + 1;
        end else
            $display("ok   display word for SW=1 is FFFB");

        // The LEDs show the low 8 bits of PC.
        if (led !== dut.pc[7:0]) begin
            $display("FAIL: LEDs %b don't match PC %0d", led, dut.pc);
            errors = errors + 1;
        end

        if (errors == 0) $display("PASS: hack_computer running test001");
        else             $display("FAIL: hack_computer, %0d errors", errors);
        $finish;
    end
endmodule
