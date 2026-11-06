`timescale 1ns/1ps

module tb_sample_tick;
    reg clk = 0, rst = 1;
    wire tick;
    integer cycles = 0, last_tick = -1, ticks = 0;
    always #10 clk = ~clk;

    sample_tick #(.CLOCK_HZ(50_000_000), .SAMPLE_HZ(16_000)) dut(
        .clk(clk), .rst(rst), .tick(tick));

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_sample_tick.vcd");
        $dumpvars(0, tb_sample_tick);
        repeat (4) @(posedge clk);
        rst = 0;
        while (ticks < 4) begin
            @(posedge clk); #1; cycles = cycles + 1;
            if (tick) begin
                if (last_tick >= 0 && cycles - last_tick != 3125)
                    $fatal(1, "FAIL SAMPLE_TICK interval=%0d", cycles-last_tick);
                last_tick = cycles;
                ticks = ticks + 1;
            end
        end
        $display("PASS SAMPLE_TICK: divisor=3125 pulse_width=1 clock ticks=%0d", ticks);
        $finish;
    end
endmodule
