`timescale 1ns/1ps

// W1 fixed 1 kHz notch at Fs=16 kHz. Coefficients are signed Q2.14.
// Equation: y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2.
module iir_notch_fixed #(
    parameter signed [15:0] B0 = 16'sd15834,
    parameter signed [15:0] B1 = -16'sd29257,
    parameter signed [15:0] B2 = 16'sd15834,
    parameter signed [15:0] A1 = -16'sd28760,
    parameter signed [15:0] A2 = 16'sd14787
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_valid,
    input  wire [7:0] sample_in,
    output reg        sample_out_valid,
    output reg  [7:0] sample_out
);
    reg signed [8:0] x1, x2;
    reg signed [8:0] y1, y2;
    wire signed [8:0] x0 = $signed({1'b0, sample_in}) - 9'sd128;

    wire signed [24:0] p_b0 = B0 * x0;
    wire signed [24:0] p_b1 = B1 * x1;
    wire signed [24:0] p_b2 = B2 * x2;
    wire signed [24:0] p_a1 = A1 * y1;
    wire signed [24:0] p_a2 = A2 * y2;
    wire signed [27:0] acc = p_b0 + p_b1 + p_b2 - p_a1 - p_a2;
    wire signed [27:0] scaled = acc >>> 14;

    reg signed [8:0] y_sat;
    always @* begin
        if (scaled > 28'sd127)
            y_sat = 9'sd127;
        else if (scaled < -28'sd128)
            y_sat = -9'sd128;
        else
            y_sat = scaled[8:0];
    end

    always @(posedge clk) begin
        if (rst) begin
            x1 <= 9'sd0;
            x2 <= 9'sd0;
            y1 <= 9'sd0;
            y2 <= 9'sd0;
            sample_out <= 8'd128;
            sample_out_valid <= 1'b0;
        end else begin
            sample_out_valid <= sample_valid;
            if (sample_valid) begin
                x2 <= x1;
                x1 <= x0;
                y2 <= y1;
                y1 <= y_sat;
                sample_out <= y_sat + 9'sd128;
            end
        end
    end
endmodule
