`timescale 1ns/1ps
module tb_lcd_status_display;
    reg clk=0,rst=1;reg[1:0]display_mode=0;reg[7:0]dsp_mode=8'h06,seq=8'ha5;
    reg valid=1,overflow=1,sw_running=1;reg[13:0]year=2028;reg[3:0]month=2;
    reg[5:0]day=29,minute=34,second=56,sw_minutes=4,sw_seconds=5;
    reg[2:0]weekday=2;reg[4:0]hour=12;reg[6:0]sw_hours=3,sw_cs=6;
    wire lcd_e,lcd_rs,lcd_rw;wire[7:0]lcd_data;
    reg[7:0]bytes[0:119];reg rsbits[0:119];integer count=0;
    always #5 clk=~clk;
    lcd_status_display #(.TICK_CYCLES(2),.POWER_TICKS(3),.NORMAL_WAIT_TICKS(1),.CLEAR_WAIT_TICKS(2))dut(
      .clk(clk),.rst(rst),.display_mode(display_mode),.dsp_mode(dsp_mode),.auto_coeff_valid(valid),
      .applied_coeff_seq(seq),.block_overflow(overflow),.year(year),.month(month),.day(day),
      .weekday(weekday),.hour(hour),.minute(minute),.second(second),.sw_running(sw_running),
      .sw_hours(sw_hours),.sw_minutes(sw_minutes),.sw_seconds(sw_seconds),.sw_centiseconds(sw_cs),
      .lcd_e(lcd_e),.lcd_rs(lcd_rs),.lcd_rw(lcd_rw),.lcd_data(lcd_data));
    always@(negedge lcd_e)if(!rst&&count<120)begin bytes[count]=lcd_data;rsbits[count]=lcd_rs;count=count+1;end
    initial begin
      $dumpfile("project_evidence/fpga/W2/pre/lcd/tb_lcd_status_display.vcd");$dumpvars(0,tb_lcd_status_display);
      repeat(3)@(posedge clk);rst=0;wait(count==40);#1;
      if(bytes[0]!==8'h38||bytes[5]!==8'h01||bytes[6]!==8'h80||bytes[23]!==8'hc0)
        $fatal(1,"FAIL LCD init sequence");
      if({bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]}!=="DSP: AUTO"||
         {bytes[24],bytes[25],bytes[26],bytes[27],bytes[28],bytes[29]}!=="SEQ:A5")
        $fatal(1,"FAIL LCD DSP page");
      display_mode=1;wait(count==74);#1;
      if({bytes[41],bytes[42],bytes[43],bytes[44]}!=="2028"||bytes[45]!=="-"||
         {bytes[46],bytes[47]}!=="02"||{bytes[49],bytes[50]}!=="29"||
         bytes[52]!=="D"||bytes[53]!=="2")$fatal(1,"FAIL LCD date page");
      if({bytes[58],bytes[59],bytes[60],bytes[61],bytes[62],bytes[63],bytes[64],bytes[65]}!=="12:34:56")
        $fatal(1,"FAIL LCD time page");
      display_mode=2;wait(count==108);#1;
      if({bytes[75],bytes[76],bytes[77],bytes[78],bytes[79],bytes[80],bytes[81],bytes[82],bytes[83]}!=="STOPWATCH")
        $fatal(1,"FAIL LCD stopwatch title");
      if({bytes[92],bytes[93],bytes[94],bytes[95],bytes[96],bytes[97],bytes[98],bytes[99],bytes[100],bytes[101],bytes[102]}!=="03:04:05.06")
        $fatal(1,"FAIL LCD stopwatch value");
      if(lcd_rw!==0)$fatal(1,"FAIL LCD rw");
      $display("PASS LCD_STATUS_DISPLAY: initialization, clock/date/weekday and stopwatch mode refresh");$finish;
    end
    initial begin #200000;$fatal(1,"FAIL LCD timeout count=%0d",count);end
endmodule
