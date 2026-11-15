`timescale 1ns/1ps
module tb_spi_w2;
    reg clk=0,rst=1,spi_sck=0,spi_mosi=0,spi_cs_n=1;
    reg sample_valid=0;reg[7:0]sample_data=0;
    reg auto_coeff_valid=0;reg[7:0]applied_coeff_seq=8'hff;
    wire spi_miso;wire[7:0]dsp_mode;wire update;wire[7:0]update_seq;
    wire signed[15:0]b0,b1,b2,a1,a2;
    wire overflow,selected_valid,selected_bank,read_bank,consume_valid,consume_bank,clear_overflow;
    wire[15:0]selected_id;wire[8:0]read_addr;wire[7:0]read_data;wire[1:0]ready_debug;
    reg[7:0]rx,status,idlo,idhi,rxcrc,crc,mode_rx,seq_rx,flags_rx;
    integer i,update_count=0;reg[7:0]seen_seq;reg signed[15:0]seen_b0,seen_b1,seen_b2,seen_a1,seen_a2;
    always #10 clk=~clk;
    analysis_buffer_512 buffer(.clk(clk),.rst(rst),.sample_valid(sample_valid),.sample_data(sample_data),
      .clear_overflow(clear_overflow),.overflow_sticky(overflow),.selected_valid(selected_valid),
      .selected_bank(selected_bank),.selected_id(selected_id),.read_bank(read_bank),.read_addr(read_addr),
      .read_data(read_data),.consume_valid(consume_valid),.consume_bank(consume_bank),.ready_debug(ready_debug));
    spi_mode0_slave_w2 dut(.clk(clk),.rst(rst),.spi_sck(spi_sck),.spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),
      .spi_miso(spi_miso),.dsp_mode(dsp_mode),.coeff_update_valid(update),.coeff_update_seq(update_seq),
      .coeff_b0(b0),.coeff_b1(b1),.coeff_b2(b2),.coeff_a1(a1),.coeff_a2(a2),
      .auto_coeff_valid(auto_coeff_valid),.applied_coeff_seq(applied_coeff_seq),
      .block_valid(selected_valid),.block_bank(selected_bank),.block_id(selected_id),.block_overflow(overflow),
      .block_read_bank(read_bank),.block_read_addr(read_addr),.block_read_data(read_data),
      .block_consume_valid(consume_valid),.block_consume_bank(consume_bank),.clear_overflow(clear_overflow));
    always@(posedge clk)if(update)begin update_count=update_count+1;seen_seq=update_seq;
      seen_b0=b0;seen_b1=b1;seen_b2=b2;seen_a1=a1;seen_a2=a2;end
    function automatic[7:0]crc8;input[7:0]c0,d;integer k;reg[7:0]c;begin c=c0^d;
      for(k=0;k<8;k=k+1)c=c[7]?((c<<1)^8'h07):(c<<1);crc8=c;end endfunction
    task automatic spi_byte;input[7:0]tx;output[7:0]data_rx;integer bitn;begin data_rx=0;
      for(bitn=7;bitn>=0;bitn=bitn-1)begin spi_mosi=tx[bitn];#500;spi_sck=1;#500;
        data_rx[bitn]=spi_miso;spi_sck=0;#500;end end endtask
    task automatic begin_frame;begin spi_sck=0;spi_cs_n=0;#1000;end endtask
    task automatic end_frame;begin #500;spi_cs_n=1;spi_mosi=0;#1500;end endtask
    task automatic coeff_data;input[7:0]d;begin spi_byte(d,rx);crc=crc8(crc,d);end endtask
    task automatic send_coeff;input[7:0]seq_value;input good;input complete;begin
      crc=0;begin_frame;spi_byte(8'h20,rx);coeff_data(seq_value);
      coeff_data(8'h34);coeff_data(8'h12);coeff_data(8'h00);coeff_data(8'h80);
      coeff_data(8'hff);coeff_data(8'h7f);coeff_data(8'hfe);coeff_data(8'hff);
      coeff_data(8'h01);coeff_data(8'h00);
      if(complete)begin if(good)spi_byte(crc,rx);else spi_byte(crc^8'h5a,rx);end
      end_frame;end endtask
    task automatic fill_block;begin for(i=0;i<512;i=i+1)begin@(negedge clk);sample_data=i[7:0];sample_valid=1;end
      @(negedge clk);sample_valid=0;@(posedge clk);#1;end endtask
    initial begin
      $dumpfile("project_evidence/fpga/W2/pre/spi/tb_spi_w2.vcd");$dumpvars(0,tb_spi_w2);
      repeat(5)@(posedge clk);rst=0;#200;
      send_coeff(8'ha5,1,1);
      if(update_count!=1||seen_seq!==8'ha5||seen_b0!==16'sh1234||seen_b1!==16'sh8000||
         seen_b2!==16'sh7fff||seen_a1!==-16'sd2||seen_a2!==16'sd1)
        $fatal(1,"FAIL SPI_W2 SET_COEFF endian/sign count=%0d seq=%02x",update_count,seen_seq);
      send_coeff(8'ha6,0,1);if(update_count!=1)$fatal(1,"FAIL SPI_W2 bad CRC accepted");
      send_coeff(8'ha7,1,0);if(update_count!=1)$fatal(1,"FAIL SPI_W2 incomplete accepted");
      auto_coeff_valid=1;applied_coeff_seq=8'ha5;
      begin_frame;spi_byte(8'h06,rx);end_frame;if(dsp_mode!==8'h06)$fatal(1,"FAIL SPI_W2 AUTO mode");
      begin_frame;spi_byte(8'h21,rx);spi_byte(0,mode_rx);#100;
      if(spi_miso!==1'b1)$fatal(1,"FAIL SPI_W2 next-byte MSB miso=%b shift=%02x pending=%02x valid=%b pos=%0d bits=%0d",
        spi_miso,dut.tx_shift,dut.tx_pending,dut.tx_pending_valid,dut.response_pos,dut.bit_count);
      spi_byte(0,seq_rx);spi_byte(0,flags_rx);end_frame;
      if(mode_rx!==8'h06||seq_rx!==8'ha5||flags_rx[1:0]!==2'b01)
        $fatal(1,"FAIL SPI_W2 READ_STATE mode=%02x seq=%02x flags=%02x",mode_rx,seq_rx,flags_rx);
      fill_block;if(!selected_valid)$fatal(1,"FAIL SPI_W2 block not ready");
      crc=0;begin_frame;spi_byte(8'h10,rx);spi_byte(0,status);spi_byte(0,idlo);spi_byte(0,idhi);
      crc=crc8(crc,idlo);crc=crc8(crc,idhi);
      for(i=0;i<512;i=i+1)begin spi_byte(0,rx);if(rx!==i[7:0])$fatal(1,"FAIL SPI_W2 sample %0d",i);crc=crc8(crc,rx);end
      spi_byte(0,rxcrc);end_frame;
      if(!status[0]||{idhi,idlo}!==0||rxcrc!==crc||selected_valid)
        $fatal(1,"FAIL SPI_W2 READ_BLOCK status=%02x id=%04x crc=%02x/%02x",status,{idhi,idlo},rxcrc,crc);
      $display("PASS SPI_W2: Mode0 timing, SET_COEFF CRC/length/endian, READ_STATE, READ_BLOCK/CRC");$finish;
    end
endmodule
