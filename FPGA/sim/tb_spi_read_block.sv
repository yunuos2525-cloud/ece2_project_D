`timescale 1ns/1ps

module tb_spi_read_block;
    reg clk=0,rst=1;
    reg sample_valid=0,clear_overflow_external=0;
    reg [7:0] sample_data=0;
    reg spi_sck=0,spi_mosi=0,spi_cs_n=1;
    wire spi_miso;
    wire overflow_sticky,selected_valid,selected_bank;
    wire [15:0] selected_id;
    wire read_bank,consume_valid,consume_bank,clear_overflow;
    wire [8:0] read_addr;
    wire [7:0] read_data,dsp_mode;
    wire [1:0] ready_debug;
    reg [7:0] rx,status,idlo,idhi,rx_crc;
    reg [7:0] expected_crc;
    integer i;
    always #10 clk=~clk;

    analysis_buffer_512 buffer(
        .clk(clk),.rst(rst),.sample_valid(sample_valid),.sample_data(sample_data),
        .clear_overflow(clear_overflow|clear_overflow_external),.overflow_sticky(overflow_sticky),
        .selected_valid(selected_valid),.selected_bank(selected_bank),.selected_id(selected_id),
        .read_bank(read_bank),.read_addr(read_addr),.read_data(read_data),
        .consume_valid(consume_valid),.consume_bank(consume_bank),.ready_debug(ready_debug));
    spi_mode0_slave spi(
        .clk(clk),.rst(rst),.spi_sck(spi_sck),.spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),.spi_miso(spi_miso),
        .dsp_mode(dsp_mode),.block_valid(selected_valid),.block_bank(selected_bank),.block_id(selected_id),
        .block_overflow(overflow_sticky),.block_read_bank(read_bank),.block_read_addr(read_addr),
        .block_read_data(read_data),.block_consume_valid(consume_valid),.block_consume_bank(consume_bank),
        .clear_overflow(clear_overflow));

    function automatic [7:0] pattern;
        input integer n;
        begin
            if(n==0) pattern=8'hA5;
            else if(n==1) pattern=8'h5A;
            else pattern=n[7:0];
        end
    endfunction
    function automatic [7:0] crc8;
        input [7:0] c0;
        input [7:0] d;
        integer k;
        reg [7:0] c;
        begin
            c=c0^d;
            for(k=0;k<8;k=k+1) c=c[7]?((c<<1)^8'h07):(c<<1);
            crc8=c;
        end
    endfunction
    task automatic spi_byte;
        input [7:0] tx;
        output [7:0] data_rx;
        integer b;
        begin
            data_rx=0;
            for(b=7;b>=0;b=b-1) begin
                spi_mosi=tx[b]; #500;
                spi_sck=1; #500;
                data_rx[b]=spi_miso;
                spi_sck=0; #500;
            end
        end
    endtask
    task automatic begin_frame;
        begin spi_sck=0; spi_cs_n=0; #1000; end
    endtask
    task automatic end_frame;
        begin #500; spi_cs_n=1; spi_mosi=0; #1500; end
    endtask
    task automatic send_block;
        begin
            for(i=0;i<512;i=i+1) begin
                @(negedge clk); sample_data=pattern(i); sample_valid=1;
            end
            @(negedge clk); sample_valid=0;
            @(posedge clk); #1;
        end
    endtask
    task automatic read_full_block;
        input [15:0] wanted_id;
        begin
            expected_crc=0;
            begin_frame(); spi_byte(8'h10,rx);
            spi_byte(8'h00,status);
            if(!status[0]) $fatal(1,"FAIL SPI status=%02x no block selected_valid=%b id=%04x",status,selected_valid,selected_id);
            spi_byte(8'h00,idlo); spi_byte(8'h00,idhi);
            if({idhi,idlo}!==wanted_id) $fatal(1,"FAIL SPI ID=%04x expected=%04x",{idhi,idlo},wanted_id);
            expected_crc=crc8(expected_crc,idlo); expected_crc=crc8(expected_crc,idhi);
            for(i=0;i<512;i=i+1) begin
                spi_byte(8'h00,rx);
                if(rx!==pattern(i)) $fatal(1,"FAIL SPI sample[%0d]=%02x expected=%02x",i,rx,pattern(i));
                expected_crc=crc8(expected_crc,rx);
            end
            spi_byte(8'h00,rx_crc);
            if(rx_crc!==expected_crc) $fatal(1,"FAIL SPI CRC=%02x expected=%02x",rx_crc,expected_crc);
            end_frame();
        end
    endtask

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_spi_read_block.vcd");
        $dumpvars(0,tb_spi_read_block);
        repeat(5) @(posedge clk); rst=0; #200;

        begin_frame(); spi_byte(8'h02,rx); end_frame();
        if(dsp_mode!==8'h02) $fatal(1,"FAIL SPI FIXED command mode=%02x",dsp_mode);
        begin_frame(); spi_byte(8'h01,rx); end_frame();
        if(dsp_mode!==8'h01) $fatal(1,"FAIL SPI BYPASS command mode=%02x",dsp_mode);

        send_block();
        if(!selected_valid) $fatal(1,"FAIL SPI buffer not ready before READ_BLOCK");
        read_full_block(16'h0000);
        if(selected_valid) $fatal(1,"FAIL SPI complete block not consumed");

        begin_frame(); spi_byte(8'h10,rx); spi_byte(8'h00,status); end_frame();
        if(status[0]) $fatal(1,"FAIL SPI empty-buffer status=%02x",status);

        send_block();
        begin_frame(); spi_byte(8'h10,rx); spi_byte(8'h00,status);
        spi_byte(8'h00,idlo); spi_byte(8'h00,idhi);
        for(i=0;i<16;i=i+1) spi_byte(8'h00,rx);
        end_frame();
        if(!selected_valid || selected_id!==16'h0001)
            $fatal(1,"FAIL SPI interrupted transfer consumed block valid=%b id=%04x",selected_valid,selected_id);
        read_full_block(16'h0001);
        if(selected_valid) $fatal(1,"FAIL SPI retry completion not consumed");

        $display("PASS SPI_READ_BLOCK: Mode0 commands, A5/5A, 512 samples, CRC, abort/retry");
        $finish;
    end
endmodule
