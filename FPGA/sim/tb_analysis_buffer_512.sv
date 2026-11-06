`timescale 1ns/1ps

module tb_analysis_buffer_512;
    reg clk=0,rst=1,sample_valid=0,clear_overflow=0;
    reg [7:0] sample_data=0;
    wire overflow_sticky,selected_valid,selected_bank;
    wire [15:0] selected_id;
    reg read_bank=0,consume_valid=0,consume_bank=0;
    reg [8:0] read_addr=0;
    wire [7:0] read_data;
    wire [1:0] ready_debug;
    integer i;
    always #10 clk=~clk;

    analysis_buffer_512 dut(.*);

    task automatic send_block;
        input integer seed;
        begin
            for(i=0;i<512;i=i+1) begin
                @(negedge clk); sample_data=(seed+i)&8'hff; sample_valid=1;
            end
            @(negedge clk); sample_valid=0;
            @(posedge clk); #1;
        end
    endtask

    initial begin
        $dumpfile("project_evidence/fpga/W1/sim/tb_analysis_buffer_512.vcd");
        $dumpvars(0,tb_analysis_buffer_512);
        repeat(4) @(posedge clk); rst=0;
        send_block(0);
        if(!selected_valid || selected_id!==0) $fatal(1,"FAIL BUFFER first block valid=%b id=%0d",selected_valid,selected_id);
        read_bank=selected_bank;
        for(i=0;i<512;i=i+1) begin
            read_addr=i; #1;
            if(read_data!==i[7:0]) $fatal(1,"FAIL BUFFER data[%0d]=%02x",i,read_data);
        end
        send_block(16);
        if(ready_debug!==2'b11) $fatal(1,"FAIL BUFFER expected two ready banks: %b",ready_debug);
        @(negedge clk); sample_data=8'hee; sample_valid=1;
        @(negedge clk); sample_valid=0;
        @(posedge clk); #1;
        if(!overflow_sticky) $fatal(1,"FAIL BUFFER overflow not sticky");
        if(selected_id!==0) $fatal(1,"FAIL BUFFER oldest ID changed: %0d",selected_id);
        read_bank=selected_bank; read_addr=0; #1;
        if(read_data!==8'h00) $fatal(1,"FAIL BUFFER oldest data overwritten: %02x",read_data);
        consume_bank=selected_bank; consume_valid=1;
        @(posedge clk); #1; consume_valid=0;
        if(!selected_valid || selected_id!==1) $fatal(1,"FAIL BUFFER next ID=%0d",selected_id);
        clear_overflow=1; @(posedge clk); #1; clear_overflow=0;
        if(overflow_sticky) $fatal(1,"FAIL BUFFER clear_overflow");
        $display("PASS ANALYSIS_BUFFER_512: ordering, immutability, overflow and consume");
        $finish;
    end
endmodule
