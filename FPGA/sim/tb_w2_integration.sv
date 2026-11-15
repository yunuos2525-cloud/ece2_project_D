`timescale 1ns/1ps
module tb_w2_integration;
    reg clk=0,rst=1,spi_sck=0,spi_mosi=0,spi_cs_n=1;
    reg sample_valid=0;reg[7:0]sample_in=128;reg[1:0]display_mode=0;
    reg start_pulse=0;wire[7:0]dsp_mode,sample_out,update_seq,applied_seq;
    wire sample_out_valid,update,auto_valid,applied,spi_miso;
    wire signed[15:0]b0,b1,b2,a1,a2;
    wire[13:0]year;wire[3:0]month;wire[5:0]day,minute,second,sw_min,sw_sec;
    wire[2:0]weekday;wire[4:0]hour;wire sw_running;wire[6:0]sw_hour,sw_cs;
    wire lcd_e,lcd_rs,lcd_rw;wire[7:0]lcd_data;
    integer in_count=0,out_count=0,lcd_falls=0,i;reg[7:0]rx,crc;
    always #10 clk=~clk;
    audio_path_w2 audio(.clk(clk),.rst(rst),.dsp_mode(dsp_mode),.sample_valid(sample_valid),.sample_in(sample_in),
      .coeff_update_valid(update),.coeff_update_seq(update_seq),.coeff_b0(b0),.coeff_b1(b1),.coeff_b2(b2),
      .coeff_a1(a1),.coeff_a2(a2),.auto_coeff_valid(auto_valid),.applied_coeff_seq(applied_seq),
      .coeff_applied(applied),.sample_out_valid(sample_out_valid),.sample_out(sample_out));
    spi_mode0_slave_w2 spi(.clk(clk),.rst(rst),.spi_sck(spi_sck),.spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),
      .spi_miso(spi_miso),.dsp_mode(dsp_mode),.coeff_update_valid(update),.coeff_update_seq(update_seq),
      .coeff_b0(b0),.coeff_b1(b1),.coeff_b2(b2),.coeff_a1(a1),.coeff_a2(a2),
      .auto_coeff_valid(auto_valid),.applied_coeff_seq(applied_seq),.block_valid(1'b0),.block_bank(1'b0),
      .block_id(16'b0),.block_overflow(1'b0),.block_read_bank(),.block_read_addr(),.block_read_data(8'b0),
      .block_consume_valid(),.block_consume_bank(),.clear_overflow());
    calendar_clock #(.CLOCK_HZ(20)) cal(.clk(clk),.rst(rst),.year(year),.month(month),.day(day),
      .weekday(weekday),.hour(hour),.minute(minute),.second(second));
    stopwatch #(.CLOCK_HZ(20),.TICK_HZ(2)) sw(.clk(clk),.rst(rst),.start_pulse(start_pulse),
      .stop_pulse(1'b0),.clear_pulse(1'b0),.running(sw_running),.hours(sw_hour),.minutes(sw_min),
      .seconds(sw_sec),.centiseconds(sw_cs));
    lcd_status_display #(.TICK_CYCLES(2),.POWER_TICKS(3),.NORMAL_WAIT_TICKS(1),.CLEAR_WAIT_TICKS(2))lcd(
      .clk(clk),.rst(rst),.display_mode(display_mode),.dsp_mode(dsp_mode),.auto_coeff_valid(auto_valid),
      .applied_coeff_seq(applied_seq),.block_overflow(1'b0),.year(year),.month(month),.day(day),
      .weekday(weekday),.hour(hour),.minute(minute),.second(second),.sw_running(sw_running),
      .sw_hours(sw_hour),.sw_minutes(sw_min),.sw_seconds(sw_sec),.sw_centiseconds(sw_cs),
      .lcd_e(lcd_e),.lcd_rs(lcd_rs),.lcd_rw(lcd_rw),.lcd_data(lcd_data));
    always@(negedge lcd_e)if(!rst)lcd_falls=lcd_falls+1;
    always@(posedge clk)begin#1;if(sample_valid)in_count=in_count+1;if(sample_out_valid)out_count=out_count+1;end
    function automatic[7:0]crc8;input[7:0]c0,d;integer k;reg[7:0]c;begin c=c0^d;
      for(k=0;k<8;k=k+1)c=c[7]?((c<<1)^8'h07):(c<<1);crc8=c;end endfunction
    task automatic spi_byte;input[7:0]tx;output[7:0]data_rx;integer bitn;begin data_rx=0;
      for(bitn=7;bitn>=0;bitn=bitn-1)begin spi_mosi=tx[bitn];#500;spi_sck=1;#500;
        data_rx[bitn]=spi_miso;spi_sck=0;#500;end end endtask
    task automatic begin_frame;begin spi_sck=0;spi_cs_n=0;#1000;end endtask
    task automatic end_frame;begin#500;spi_cs_n=1;spi_mosi=0;#1500;end endtask
    task automatic send_data;input[7:0]d;begin spi_byte(d,rx);crc=crc8(crc,d);end endtask
    initial begin
      $dumpfile("project_evidence/fpga/W2/pre/integration/tb_w2_integration.vcd");$dumpvars(1,tb_w2_integration);
      repeat(5)@(posedge clk);rst=0;@(negedge clk);start_pulse=1;@(negedge clk);start_pulse=0;
      fork
        begin
          for(i=0;i<300;i=i+1)begin repeat(60)@(negedge clk);sample_in=(i*13+7);sample_valid=1;
            @(negedge clk);sample_valid=0;if(i==120)display_mode=1;if(i==220)display_mode=2;end
        end
        begin
          #2000;crc=0;begin_frame;spi_byte(8'h20,rx);send_data(8'h31);
          send_data(8'h00);send_data(8'h40); // b0=1.0
          send_data(0);send_data(0);send_data(0);send_data(0);
          send_data(0);send_data(0);send_data(0);send_data(0);
          spi_byte(crc,rx);end_frame;
          wait(auto_valid);begin_frame;spi_byte(8'h06,rx);end_frame;
        end
      join
      repeat(10)@(posedge clk);#1;
      if(in_count!=300||out_count!=300)$fatal(1,"FAIL W2_INTEGRATION audio gap in=%0d out=%0d",in_count,out_count);
      if(!auto_valid||applied_seq!==8'h31||dsp_mode!==8'h06)$fatal(1,"FAIL W2_INTEGRATION apply/mode");
      if(second==0||sw_sec==0||lcd_falls<40)$fatal(1,"FAIL W2_INTEGRATION independent services sec=%0d sw=%0d lcd=%0d",second,sw_sec,lcd_falls);
      $display("PASS W2_INTEGRATION: 300/300 audio samples during SPI coefficient apply, LCD refresh, clock and stopwatch");$finish;
    end
    initial begin #2000000;$fatal(1,"FAIL W2_INTEGRATION timeout");end
endmodule
