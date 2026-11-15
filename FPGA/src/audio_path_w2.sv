`timescale 1ns/1ps

module audio_path_w2 (
    input  wire               clk,
    input  wire               rst,
    input  wire [7:0]         dsp_mode,
    input  wire               sample_valid,
    input  wire [7:0]         sample_in,
    input  wire               coeff_update_valid,
    input  wire [7:0]         coeff_update_seq,
    input  wire signed [15:0] coeff_b0, coeff_b1, coeff_b2, coeff_a1, coeff_a2,
    output wire               auto_coeff_valid,
    output wire [7:0]         applied_coeff_seq,
    output wire               coeff_applied,
    output wire               sample_out_valid,
    output wire [7:0]         sample_out
);
    reg [7:0] bypass_delay;
    wire fixed_valid, variable_valid;
    wire [7:0] fixed_sample, variable_sample;

    always @(posedge clk) begin
        if (rst) bypass_delay <= 8'd128;
        else if (sample_valid) bypass_delay <= sample_in;
    end

    iir_notch_fixed u_fixed (
        .clk(clk), .rst(rst), .sample_valid(sample_valid), .sample_in(sample_in),
        .sample_out_valid(fixed_valid), .sample_out(fixed_sample)
    );
    iir_notch_variable u_variable (
        .clk(clk), .rst(rst), .sample_valid(sample_valid), .sample_in(sample_in),
        .coeff_update_valid(coeff_update_valid), .coeff_update_seq(coeff_update_seq),
        .coeff_b0(coeff_b0), .coeff_b1(coeff_b1), .coeff_b2(coeff_b2),
        .coeff_a1(coeff_a1), .coeff_a2(coeff_a2),
        .coeff_valid(auto_coeff_valid), .applied_seq(applied_coeff_seq),
        .coeff_applied(coeff_applied), .sample_out_valid(variable_valid),
        .sample_out(variable_sample)
    );

    assign sample_out_valid = fixed_valid;
    assign sample_out = (dsp_mode == 8'h02) ? fixed_sample :
                        ((dsp_mode == 8'h06) && auto_coeff_valid) ? variable_sample :
                        bypass_delay;
    wire _unused_variable_valid = variable_valid;
endmodule
