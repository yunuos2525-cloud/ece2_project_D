`timescale 1ns/1ps
module tb_audio_path_w2;
    reg clk=0,rst=1,sample_valid=0,update=0;reg[7:0]mode=8'h01,sample_in=128,seq=8'h55;
    reg signed[15:0]b0=16'sd16384,b1=0,b2=0,a1=0,a2=0;
    wire coeff_valid,applied,out_valid;wire[7:0]applied_seq,sample_out;
    reg[7:0]patterns[0:7];integer i;
    always #10 clk=~clk;
    audio_path_w2 dut(.clk(clk),.rst(rst),.dsp_mode(mode),.sample_valid(sample_valid),.sample_in(sample_in),
      .coeff_update_valid(update),.coeff_update_seq(seq),.coeff_b0(b0),.coeff_b1(b1),.coeff_b2(b2),
      .coeff_a1(a1),.coeff_a2(a2),.auto_coeff_valid(coeff_valid),.applied_coeff_seq(applied_seq),
      .coeff_applied(applied),.sample_out_valid(out_valid),.sample_out(sample_out));
    task automatic send_and_check;input[7:0]value;begin@(negedge clk);sample_in=value;sample_valid=1;
      @(posedge clk);#1;if(!out_valid||sample_out!==value)$fatal(1,"FAIL AUDIO_W2 mode=%02x got=%02x expected=%02x",mode,sample_out,value);
      @(negedge clk);sample_valid=0;end endtask
    initial begin
      patterns[0]=0;patterns[1]=8'h80;patterns[2]=8'ha5;patterns[3]=8'h5a;
      patterns[4]=8'hff;patterns[5]=1;patterns[6]=8'h7f;patterns[7]=8'hc3;
      $dumpfile("project_evidence/fpga/W2/pre/dsp/tb_audio_path_w2.vcd");$dumpvars(0,tb_audio_path_w2);
      repeat(4)@(negedge clk);rst=0;
      for(i=0;i<8;i=i+1)send_and_check(patterns[i]);
      mode=8'h06;if(coeff_valid)$fatal(1,"FAIL AUDIO_W2 coefficient unexpectedly valid");
      for(i=0;i<8;i=i+1)send_and_check(patterns[7-i]);
      @(negedge clk);update=1;@(negedge clk);update=0;
      send_and_check(8'h80);
      if(!coeff_valid||applied_seq!==8'h55)$fatal(1,"FAIL AUDIO_W2 coefficient not applied");
      for(i=0;i<8;i=i+1)send_and_check(patterns[i]);
      mode=8'h02;@(negedge clk);sample_in=8'h90;sample_valid=1;@(posedge clk);#1;
      if(!out_valid)$fatal(1,"FAIL AUDIO_W2 FIXED valid missing");
      $display("PASS AUDIO_PATH_W2: BYPASS bit-exact, AUTO fallback, atomic identity coefficients and mode selection");$finish;
    end
endmodule
