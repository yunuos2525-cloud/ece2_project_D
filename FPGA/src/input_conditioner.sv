`timescale 1ns/1ps

module input_conditioner #(
    parameter integer STABLE_CYCLES = 1_000_000,
    parameter integer ACTIVE_LOW = 0
) (
    input  wire clk,
    input  wire rst,
    input  wire async_in,
    output reg  stable_level,
    output reg  press_pulse,
    output reg  release_pulse
);
    localparam integer COUNT_W = (STABLE_CYCLES <= 2) ? 1 : $clog2(STABLE_CYCLES);
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync_ff;
    reg [COUNT_W-1:0] count;
    wire logical_in = ACTIVE_LOW ? ~sync_ff[1] : sync_ff[1];
    always @(posedge clk) begin
        if (rst) begin
            sync_ff <= 0;
            count <= 0;
            stable_level <= 0;
            press_pulse <= 0;
            release_pulse <= 0;
        end else begin
            sync_ff <= {sync_ff[0], async_in};
            press_pulse <= 0;
            release_pulse <= 0;
            if (logical_in == stable_level) begin
                count <= 0;
            end else if (count == STABLE_CYCLES - 1) begin
                count <= 0;
                stable_level <= logical_in;
                if (logical_in) press_pulse <= 1;
                else release_pulse <= 1;
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule
