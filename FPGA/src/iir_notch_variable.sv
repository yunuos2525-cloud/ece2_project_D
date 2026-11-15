`timescale 1ns/1ps

// Runtime-coefficient second-order IIR. Coefficients are signed Q2.14 and
// follow y=b0*x+b1*x1+b2*x2-a1*y1-a2*y2. Recursive state retains 14
// fractional bits; output conversion uses symmetric round-to-nearest and
// saturates to signed 8-bit audio before restoring offset binary.
module iir_notch_variable (
    input  wire               clk,
    input  wire               rst,
    input  wire               sample_valid,
    input  wire [7:0]         sample_in,
    input  wire               coeff_update_valid,
    input  wire [7:0]         coeff_update_seq,
    input  wire signed [15:0] coeff_b0,
    input  wire signed [15:0] coeff_b1,
    input  wire signed [15:0] coeff_b2,
    input  wire signed [15:0] coeff_a1,
    input  wire signed [15:0] coeff_a2,
    output reg                coeff_valid,
    output reg  [7:0]         applied_seq,
    output reg                coeff_applied,
    output reg                sample_out_valid,
    output reg  [7:0]         sample_out
);
    reg signed [15:0] active_b0, active_b1, active_b2, active_a1, active_a2;
    reg signed [15:0] pending_b0, pending_b1, pending_b2, pending_a1, pending_a2;
    reg [7:0] pending_seq;
    reg pending_valid;
    reg signed [8:0] x1, x2;
    reg signed [22:0] y1_q14, y2_q14;

    wire signed [8:0] x0 = $signed({1'b0, sample_in}) - 9'sd128;
    wire signed [15:0] use_b0 = pending_valid ? pending_b0 : active_b0;
    wire signed [15:0] use_b1 = pending_valid ? pending_b1 : active_b1;
    wire signed [15:0] use_b2 = pending_valid ? pending_b2 : active_b2;
    wire signed [15:0] use_a1 = pending_valid ? pending_a1 : active_a1;
    wire signed [15:0] use_a2 = pending_valid ? pending_a2 : active_a2;

    wire signed [24:0] p_b0 = use_b0 * x0;
    wire signed [24:0] p_b1 = use_b1 * x1;
    wire signed [24:0] p_b2 = use_b2 * x2;
    wire signed [38:0] p_a1_q28 = use_a1 * y1_q14;
    wire signed [38:0] p_a2_q28 = use_a2 * y2_q14;
    wire signed [41:0] acc_q14 =
        $signed({{17{p_b0[24]}}, p_b0}) +
        $signed({{17{p_b1[24]}}, p_b1}) +
        $signed({{17{p_b2[24]}}, p_b2}) -
        ($signed({{3{p_a1_q28[38]}}, p_a1_q28}) >>> 14) -
        ($signed({{3{p_a2_q28[38]}}, p_a2_q28}) >>> 14);

    localparam signed [41:0] MAX_Q14 = 42'sd2080768;  // 127 * 2^14
    localparam signed [41:0] MIN_Q14 = -42'sd2097152; // -128 * 2^14
    reg signed [22:0] y_next_q14;
    reg signed [8:0] y_rounded;
    reg signed [41:0] rounded_mag;
    always @* begin
        if (acc_q14 > MAX_Q14) begin
            y_next_q14 = 23'sd2080768;
            y_rounded = 9'sd127;
        end else if (acc_q14 < MIN_Q14) begin
            y_next_q14 = -23'sd2097152;
            y_rounded = -9'sd128;
        end else begin
            y_next_q14 = acc_q14[22:0];
            if (acc_q14 >= 0)
                y_rounded = (acc_q14 + 42'sd8192) >>> 14;
            else begin
                rounded_mag = ((-acc_q14) + 42'sd8192) >>> 14;
                y_rounded = -$signed(rounded_mag[8:0]);
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            active_b0 <= 0; active_b1 <= 0; active_b2 <= 0;
            active_a1 <= 0; active_a2 <= 0;
            pending_b0 <= 0; pending_b1 <= 0; pending_b2 <= 0;
            pending_a1 <= 0; pending_a2 <= 0;
            pending_seq <= 8'hff;
            pending_valid <= 1'b0;
            coeff_valid <= 1'b0;
            applied_seq <= 8'hff;
            coeff_applied <= 1'b0;
            x1 <= 0; x2 <= 0; y1_q14 <= 0; y2_q14 <= 0;
            sample_out_valid <= 1'b0;
            sample_out <= 8'd128;
        end else begin
            coeff_applied <= 1'b0;
            sample_out_valid <= sample_valid;
            if (coeff_update_valid) begin
                pending_b0 <= coeff_b0; pending_b1 <= coeff_b1;
                pending_b2 <= coeff_b2; pending_a1 <= coeff_a1;
                pending_a2 <= coeff_a2; pending_seq <= coeff_update_seq;
                pending_valid <= 1'b1;
            end
            if (sample_valid) begin
                if (pending_valid) begin
                    active_b0 <= pending_b0; active_b1 <= pending_b1;
                    active_b2 <= pending_b2; active_a1 <= pending_a1;
                    active_a2 <= pending_a2;
                    applied_seq <= pending_seq;
                    coeff_valid <= 1'b1;
                    coeff_applied <= 1'b1;
                    pending_valid <= 1'b0;
                end
                x2 <= x1;
                x1 <= x0;
                y2_q14 <= y1_q14;
                y1_q14 <= y_next_q14;
                sample_out <= y_rounded + 9'sd128;
            end
        end
    end
endmodule
