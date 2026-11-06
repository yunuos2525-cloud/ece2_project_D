`timescale 1ns/1ps

module audio_path (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] dsp_mode,
    input  wire       sample_valid,
    input  wire [7:0] sample_in,
    output wire       sample_out_valid,
    output wire [7:0] sample_out
);
    reg [7:0] bypass_delay;
    wire filter_valid;
    wire [7:0] filter_sample;

    always @(posedge clk) begin
        if (rst)
            bypass_delay <= 8'd128;
        else if (sample_valid)
            bypass_delay <= sample_in;
    end

    iir_notch_fixed u_fixed_notch (
        .clk(clk), .rst(rst),
        .sample_valid(sample_valid), .sample_in(sample_in),
        .sample_out_valid(filter_valid), .sample_out(filter_sample)
    );

    // AUTO (0x06) intentionally falls back to BYPASS in W1: no valid
    // variable-coefficient receiver exists until W2.
    assign sample_out_valid = filter_valid;
    assign sample_out = (dsp_mode == 8'h02) ? filter_sample : bypass_delay;
endmodule
