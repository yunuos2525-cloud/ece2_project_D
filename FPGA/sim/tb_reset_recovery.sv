`timescale 1ns/1ps

module tb_reset_recovery;
    reg clk=0, arst_p=1;
    wire rst;
    reg sample_valid=0;
    reg [7:0] sample_in=8'd128;
    wire sample_out_valid;
    wire [7:0] sample_out;

    reg spi_sck=0, spi_mosi=0, spi_cs_n=1;
    wire spi_miso;
    wire [7:0] dsp_mode;
    wire overflow_sticky, selected_valid, selected_bank;
    wire [15:0] selected_id;
    wire block_read_bank, block_consume_valid, block_consume_bank, clear_overflow;
    wire [8:0] block_read_addr;
    wire [7:0] block_read_data;
    wire [1:0] ready_debug;
    reg [7:0] rx,status,idlo,idhi,rx_crc;
    reg [7:0] expected_crc;
    integer i, outputs_seen;

    always #10 clk=~clk;

    reset_conditioner #(.STAGES(3)) reset_dut(
        .clk(clk), .arst_p(arst_p), .rst(rst));
    audio_path audio_dut(
        .clk(clk),.rst(rst),.dsp_mode(dsp_mode),
        .sample_valid(sample_valid),.sample_in(sample_in),
        .sample_out_valid(sample_out_valid),.sample_out(sample_out));
    analysis_buffer_512 buffer_dut(
        .clk(clk),.rst(rst),.sample_valid(sample_valid),.sample_data(sample_in),
        .clear_overflow(clear_overflow),.overflow_sticky(overflow_sticky),
        .selected_valid(selected_valid),.selected_bank(selected_bank),.selected_id(selected_id),
        .read_bank(block_read_bank),.read_addr(block_read_addr),.read_data(block_read_data),
        .consume_valid(block_consume_valid),.consume_bank(block_consume_bank),.ready_debug(ready_debug));
    spi_mode0_slave spi_dut(
        .clk(clk),.rst(rst),.spi_sck(spi_sck),.spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),.spi_miso(spi_miso),
        .dsp_mode(dsp_mode),.block_valid(selected_valid),.block_bank(selected_bank),.block_id(selected_id),
        .block_overflow(overflow_sticky),.block_read_bank(block_read_bank),.block_read_addr(block_read_addr),
        .block_read_data(block_read_data),.block_consume_valid(block_consume_valid),
        .block_consume_bank(block_consume_bank),.clear_overflow(clear_overflow));

    function automatic [7:0] pattern;
        input integer n;
        begin
            if(n==0) pattern=8'hA5;
            else if(n==1) pattern=8'h5A;
            else pattern=(n*3+7)&8'hff;
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

    task automatic release_between_edges;
        integer stage;
        begin
            @(negedge clk); #3; arst_p=0;
            for(stage=1;stage<=2;stage=stage+1) begin
                @(posedge clk); #1;
                if(!rst) $fatal(1,"FAIL RESET_RECOVERY early deassert stage=%0d",stage);
            end
            @(posedge clk); #1;
            if(rst) $fatal(1,"FAIL RESET_RECOVERY did not deassert after 3 stages");
        end
    endtask
    task automatic assert_between_edges;
        begin
            @(negedge clk); #3; arst_p=1; #1;
            if(!rst) $fatal(1,"FAIL RESET_RECOVERY asynchronous assertion delayed");
            @(posedge clk); #1;
            if(dsp_mode!==8'h01 || selected_valid || ready_debug!==2'b00)
                $fatal(1,"FAIL RESET_RECOVERY downstream state not reset mode=%02x ready=%b",dsp_mode,ready_debug);
        end
    endtask
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
    task automatic command;
        input [7:0] cmd;
        begin begin_frame(); spi_byte(cmd,rx); end_frame(); end
    endtask
    task automatic send_one_sample;
        input [7:0] value;
        input [7:0] expected;
        begin
            @(negedge clk); sample_in=value; sample_valid=1;
            @(negedge clk); sample_valid=0;
            while(!sample_out_valid) begin @(posedge clk); #1; end
            if(sample_out!==expected)
                $fatal(1,"FAIL RESET_RECOVERY audio got=%02x expected=%02x mode=%02x",sample_out,expected,dsp_mode);
        end
    endtask
    task automatic fill_block;
        begin
            for(i=0;i<512;i=i+1) begin
                @(negedge clk); sample_in=pattern(i); sample_valid=1;
            end
            @(negedge clk); sample_valid=0;
            @(posedge clk); #1;
            if(!selected_valid || selected_id!==16'h0000)
                $fatal(1,"FAIL RESET_RECOVERY block restart valid=%b id=%04x",selected_valid,selected_id);
        end
    endtask
    task automatic read_full_block;
        begin
            expected_crc=0;
            begin_frame(); spi_byte(8'h10,rx); spi_byte(8'h00,status);
            if(!status[0]) $fatal(1,"FAIL RESET_RECOVERY restarted READ_BLOCK status=%02x",status);
            spi_byte(8'h00,idlo); spi_byte(8'h00,idhi);
            if({idhi,idlo}!==16'h0000) $fatal(1,"FAIL RESET_RECOVERY restarted block id=%04x",{idhi,idlo});
            expected_crc=crc8(expected_crc,idlo); expected_crc=crc8(expected_crc,idhi);
            for(i=0;i<512;i=i+1) begin
                spi_byte(8'h00,rx);
                if(rx!==pattern(i)) $fatal(1,"FAIL RESET_RECOVERY sample[%0d]=%02x expected=%02x",i,rx,pattern(i));
                expected_crc=crc8(expected_crc,rx);
            end
            spi_byte(8'h00,rx_crc);
            if(rx_crc!==expected_crc) $fatal(1,"FAIL RESET_RECOVERY CRC=%02x expected=%02x",rx_crc,expected_crc);
            end_frame();
            if(selected_valid) $fatal(1,"FAIL RESET_RECOVERY completed block not consumed");
        end
    endtask

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_reset_recovery.vcd");
        $dumpvars(0,tb_reset_recovery);

        repeat(3) @(posedge clk);
        if(!rst) $fatal(1,"FAIL RESET_RECOVERY reset not asserted at startup");
        release_between_edges();
        if(dsp_mode!==8'h01) $fatal(1,"FAIL RESET_RECOVERY startup mode=%02x",dsp_mode);

        // BYPASS works before interruption.
        send_one_sample(8'hA5,8'hA5);

        // Excite filter and buffer, then assert reset while a sample is valid.
        command(8'h02);
        for(i=0;i<32;i=i+1) begin
            @(negedge clk); sample_in=(i[0]?8'd80:8'd180); sample_valid=1;
        end
        @(negedge clk); sample_in=8'd200; sample_valid=1; #3; arst_p=1; #1;
        if(!rst) $fatal(1,"FAIL RESET_RECOVERY sample-time async assertion");
        @(posedge clk); #1; sample_valid=0;
        if(sample_out_valid || dsp_mode!==8'h01 || selected_valid)
            $fatal(1,"FAIL RESET_RECOVERY sample-time reset left state");
        release_between_edges();

        // Filter history must be clear; BYPASS and fixed-center restart cleanly.
        send_one_sample(8'h5A,8'h5A);
        assert_between_edges();
        release_between_edges();
        command(8'h02);
        outputs_seen=0;
        repeat(8) begin
            send_one_sample(8'd128,8'd128);
            outputs_seen=outputs_seen+1;
        end
        if(outputs_seen!=8) $fatal(1,"FAIL RESET_RECOVERY notch restart count");

        // Prepare a block, start READ_BLOCK, then reset in the middle of SCK high.
        fill_block();
        begin_frame(); spi_byte(8'h10,rx); spi_byte(8'h00,status);
        spi_byte(8'h00,idlo); spi_byte(8'h00,idhi);
        repeat(8) spi_byte(8'h00,rx);
        spi_mosi=0; #500; spi_sck=1; #103; arst_p=1; #1;
        if(!rst) $fatal(1,"FAIL RESET_RECOVERY SPI-time async assertion");
        #397; spi_sck=0; repeat(2) @(posedge clk); #1;
        spi_cs_n=1; spi_mosi=0;
        if(dsp_mode!==8'h01 || selected_valid || block_consume_valid)
            $fatal(1,"FAIL RESET_RECOVERY incomplete SPI packet survived reset");
        release_between_edges();

        // No stale block may be advertised after reset.
        begin_frame(); spi_byte(8'h10,rx); spi_byte(8'h00,status); end_frame();
        if(status[0]) $fatal(1,"FAIL RESET_RECOVERY stale block status=%02x",status);

        // Full post-reset recovery: BYPASS, FIXED, new block, SPI data and CRC.
        send_one_sample(8'h3C,8'h3C);
        assert_between_edges();
        release_between_edges();
        command(8'h02);
        send_one_sample(8'd128,8'd128);
        assert_between_edges();
        release_between_edges();
        fill_block();
        read_full_block();

        $display("PASS RESET_RECOVERY: async assert, 3-edge release, sample/SPI interruption, clean BYPASS/notch/buffer/SPI restart");
        $finish;
    end

    initial begin
        #30000000; $fatal(1,"FAIL RESET_RECOVERY timeout");
    end
endmodule
