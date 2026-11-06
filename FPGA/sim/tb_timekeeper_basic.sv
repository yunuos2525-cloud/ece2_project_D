`timescale 1ns/1ps

module tb_timekeeper_basic;
    reg clk=0,rst=1,sw_start=0,sw_stop=0,sw_reset=0;
    wire [4:0] rtc_hour;
    wire [5:0] rtc_minute,rtc_second,sw_second,sw_minute;
    wire [6:0] sw_centisecond;
    wire sw_running;
    integer i;
    always #5 clk=~clk;

    timekeeper_basic #(.CLOCK_HZ(100),.SW_HZ(10)) dut(.*);

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_timekeeper_basic.vcd");
        $dumpvars(0,tb_timekeeper_basic);
        repeat(3) @(posedge clk); rst=0;
        repeat(100) @(posedge clk); #1;
        if(rtc_second!==1) $fatal(1,"FAIL TIMEKEEPER rtc_second=%0d",rtc_second);
        sw_start=1; @(posedge clk); #1; sw_start=0;
        repeat(100) @(posedge clk); #1;
        if(sw_second!==1 || sw_centisecond!==0) $fatal(1,"FAIL TIMEKEEPER stopwatch=%0d.%0d",sw_second,sw_centisecond);
        sw_stop=1; @(posedge clk); #1; sw_stop=0;
        i=sw_centisecond; repeat(30) @(posedge clk); #1;
        if(sw_centisecond!==i[6:0]) $fatal(1,"FAIL TIMEKEEPER stop changed count");
        sw_reset=1; @(posedge clk); #1; sw_reset=0;
        if(sw_second!==0 || sw_centisecond!==0) $fatal(1,"FAIL TIMEKEEPER reset");

        // Force the W1 time counters near 23:59:59 to verify rollover without a long run.
        dut.rtc_hour=23; dut.rtc_minute=59; dut.rtc_second=59; dut.sec_count=99;
        @(posedge clk); #1;
        if(rtc_hour!==0 || rtc_minute!==0 || rtc_second!==0)
            $fatal(1,"FAIL TIMEKEEPER day rollover %0d:%0d:%0d",rtc_hour,rtc_minute,rtc_second);
        $display("PASS TIMEKEEPER_BASIC: RTC rollover and stopwatch start/stop/reset");
        $finish;
    end
endmodule
