`timescale 1ns/1ps
module tb_stopwatch;
    reg clk=0,rst=1,button=0,stop_pulse=0,clear_pulse=0;
    wire level,start_pulse,release_pulse,running;
    wire [6:0] hours,centiseconds; wire [5:0] minutes,seconds;
    integer pulses=0,held;
    always #5 clk=~clk;
    input_conditioner #(.STABLE_CYCLES(3)) cond(.clk(clk),.rst(rst),.async_in(button),
        .stable_level(level),.press_pulse(start_pulse),.release_pulse(release_pulse));
    stopwatch #(.CLOCK_HZ(100),.TICK_HZ(10)) dut(.clk(clk),.rst(rst),.start_pulse(start_pulse),
        .stop_pulse(stop_pulse),.clear_pulse(clear_pulse),.running(running),.hours(hours),
        .minutes(minutes),.seconds(seconds),.centiseconds(centiseconds));
    always @(posedge clk) if(start_pulse) pulses=pulses+1;
    initial begin
        $dumpfile("project_evidence/fpga/W2/pre/stopwatch/tb_stopwatch.vcd");$dumpvars(0,tb_stopwatch);
        repeat(3)@(posedge clk);rst=0;
        // Bounce, then hold: exactly one debounced press.
        @(negedge clk);button=1;@(negedge clk);button=0;@(negedge clk);button=1;
        repeat(8)@(posedge clk);#1;
        if(pulses!=1||!running)$fatal(1,"FAIL STOPWATCH debounce pulses=%0d running=%b",pulses,running);
        repeat(100)@(posedge clk);#1;
        if(seconds!=1)$fatal(1,"FAIL STOPWATCH start seconds=%0d cs=%0d",seconds,centiseconds);
        stop_pulse=1;@(posedge clk);#1;stop_pulse=0;held=centiseconds;
        repeat(30)@(posedge clk);#1;if(centiseconds!=held)$fatal(1,"FAIL STOPWATCH hold");
        // Release/repress resumes accumulated value.
        button=0;repeat(5)@(posedge clk);button=1;repeat(5)@(posedge clk);#1;
        if(pulses!=2||!running)$fatal(1,"FAIL STOPWATCH resume pulses=%0d",pulses);
        repeat(100)@(posedge clk);#1;if(seconds!=2)$fatal(1,"FAIL STOPWATCH accumulated seconds=%0d",seconds);
        dut.minutes=0;dut.seconds=59;dut.centiseconds=9;dut.div_count=9;
        @(posedge clk);#1;if(minutes!=1||seconds!=0||centiseconds!=0)$fatal(1,"FAIL STOPWATCH 59 rollover");
        clear_pulse=1;@(posedge clk);#1;clear_pulse=0;
        if(hours!=0||minutes!=0||seconds!=0||centiseconds!=0)$fatal(1,"FAIL STOPWATCH clear");
        $display("PASS STOPWATCH: debounce, start/stop/resume/reset, 59-second rollover");$finish;
    end
endmodule
