`timescale 1ns/1ps

module tb_audio_path;
    reg clk = 0, rst = 1;
    reg [7:0] mode = 8'h01, sample_in = 0;
    reg sample_valid = 0;
    wire [7:0] sample_out;
    wire sample_out_valid;
    integer i, out_idx;
    reg [7:0] expected [0:7];
    always #10 clk = ~clk;

    audio_path dut(.clk(clk), .rst(rst), .dsp_mode(mode),
        .sample_valid(sample_valid), .sample_in(sample_in),
        .sample_out_valid(sample_out_valid), .sample_out(sample_out));

    initial begin
        expected[0]=8'h00; expected[1]=8'h80; expected[2]=8'hA5; expected[3]=8'h5A;
        expected[4]=8'hFF; expected[5]=8'h01; expected[6]=8'h7F; expected[7]=8'hC3;
        $dumpfile("project_evidence/fpga/W1/sim/tb_audio_path.vcd");
        $dumpvars(0, tb_audio_path);
        repeat(4) @(posedge clk); rst = 0;
        out_idx=0;
        fork
            begin
                for (i=0;i<8;i=i+1) begin
                    @(negedge clk); sample_in=expected[i]; sample_valid=1;
                end
                @(negedge clk); sample_valid=0;
            end
            begin
                while(out_idx<8) begin
                    @(posedge clk); #1;
                    if(sample_out_valid) begin
                        if(sample_out !== expected[out_idx])
                            $fatal(1,"FAIL AUDIO_PATH index=%0d got=%02x expected=%02x",out_idx,sample_out,expected[out_idx]);
                        out_idx=out_idx+1;
                    end
                end
            end
        join
        mode=8'h06;
        @(negedge clk); sample_in=8'h3C; sample_valid=1;
        @(negedge clk); sample_valid=0;
        wait(sample_out_valid); #1;
        if(sample_out!==8'h3C) $fatal(1,"FAIL AUDIO_PATH AUTO fallback got=%02x",sample_out);
        $display("PASS AUDIO_PATH: BYPASS bit-exact and W1 AUTO fallback");
        $finish;
    end
endmodule
