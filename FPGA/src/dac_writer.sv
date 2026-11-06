`timescale 1ns/1ps

module dac_writer (
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_valid,
    input  wire [7:0] sample_data,
    input  wire       channel,
    output wire       dac_csn,
    output wire       dac_ldacn,
    output wire       dac_wen,
    output wire       dac_a_b,
    output wire [7:0] dac_d
);
    dac_parallel8 u_dac (
        .clk(clk), .rst(rst), .update(sample_valid), .channel(channel),
        .value(sample_data), .cs_n(dac_csn), .ldac_n(dac_ldacn),
        .we_n(dac_wen), .a_b(dac_a_b), .data(dac_d)
    );
endmodule
