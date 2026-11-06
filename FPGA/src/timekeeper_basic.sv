`timescale 1ns/1ps

module timekeeper_basic #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer SW_HZ = 100
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       sw_start,
    input  wire       sw_stop,
    input  wire       sw_reset,
    output reg  [4:0] rtc_hour,
    output reg  [5:0] rtc_minute,
    output reg  [5:0] rtc_second,
    output reg  [6:0] sw_centisecond,
    output reg  [5:0] sw_second,
    output reg  [5:0] sw_minute,
    output reg        sw_running
);
    localparam integer SEC_W = (CLOCK_HZ <= 2) ? 1 : $clog2(CLOCK_HZ);
    localparam integer SW_DIV = CLOCK_HZ / SW_HZ;
    localparam integer SW_W = (SW_DIV <= 2) ? 1 : $clog2(SW_DIV);
    reg [SEC_W-1:0] sec_count;
    reg [SW_W-1:0] sw_count;

    always @(posedge clk) begin
        if (rst) begin
            sec_count <= 0;
            sw_count <= 0;
            rtc_hour <= 0;
            rtc_minute <= 0;
            rtc_second <= 0;
            sw_centisecond <= 0;
            sw_second <= 0;
            sw_minute <= 0;
            sw_running <= 1'b0;
        end else begin
            if (sec_count == CLOCK_HZ - 1) begin
                sec_count <= 0;
                if (rtc_second == 59) begin
                    rtc_second <= 0;
                    if (rtc_minute == 59) begin
                        rtc_minute <= 0;
                        rtc_hour <= (rtc_hour == 23) ? 0 : rtc_hour + 1'b1;
                    end else rtc_minute <= rtc_minute + 1'b1;
                end else rtc_second <= rtc_second + 1'b1;
            end else sec_count <= sec_count + 1'b1;

            if (sw_start) sw_running <= 1'b1;
            if (sw_stop) sw_running <= 1'b0;

            if (sw_reset) begin
                sw_count <= 0;
                sw_centisecond <= 0;
                sw_second <= 0;
                sw_minute <= 0;
            end else if (sw_running) begin
                if (sw_count == SW_DIV - 1) begin
                    sw_count <= 0;
                    if (sw_centisecond == SW_HZ - 1) begin
                        sw_centisecond <= 0;
                        if (sw_second == 59) begin
                            sw_second <= 0;
                            sw_minute <= (sw_minute == 59) ? 0 : sw_minute + 1'b1;
                        end else sw_second <= sw_second + 1'b1;
                    end else sw_centisecond <= sw_centisecond + 1'b1;
                end else sw_count <= sw_count + 1'b1;
            end
        end
    end
endmodule
