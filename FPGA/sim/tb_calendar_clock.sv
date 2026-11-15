`timescale 1ns/1ps
module tb_calendar_clock;
    reg clk=0,rst=1; wire [13:0] year;wire [3:0] month;wire [5:0] day;
    wire [2:0] weekday;wire [4:0] hour;wire [5:0] minute,second;
    always #5 clk=~clk;
    calendar_clock #(.CLOCK_HZ(4)) dut(.*);
    task automatic set_boundary;
        input integer y,m,d,wd;
        begin dut.year=y;dut.month=m;dut.day=d;dut.weekday=wd;dut.hour=23;dut.minute=59;dut.second=59;dut.sec_count=3; end
    endtask
    task automatic check_next;
        input integer y,m,d,wd;
        begin @(posedge clk);#1;if(year!=y||month!=m||day!=d||weekday!=wd||hour!=0||minute!=0||second!=0)
            $fatal(1,"FAIL CALENDAR got %0d-%0d-%0d D%0d %0d:%0d:%0d",year,month,day,weekday,hour,minute,second);end
    endtask
    initial begin
        $dumpfile("project_evidence/fpga/W2/pre/clock/tb_calendar_clock.vcd");$dumpvars(0,tb_calendar_clock);
        repeat(3)@(posedge clk);rst=0;
        repeat(4)@(posedge clk);#1;if(second!=1)$fatal(1,"FAIL CALENDAR one second");
        set_boundary(2026,4,30,4);check_next(2026,5,1,5);
        set_boundary(2026,1,31,6);check_next(2026,2,1,0);
        set_boundary(2023,2,28,2);check_next(2023,3,1,3);
        set_boundary(2024,2,28,3);check_next(2024,2,29,4);
        set_boundary(2024,2,29,4);check_next(2024,3,1,5);
        set_boundary(2099,12,31,4);check_next(2100,1,1,5);
        set_boundary(2100,2,28,0);check_next(2100,3,1,1);
        set_boundary(2400,2,28,0);check_next(2400,2,29,1);
        $display("PASS CALENDAR_CLOCK: seven fields, month/year/leap-century/weekday boundaries");$finish;
    end
endmodule
