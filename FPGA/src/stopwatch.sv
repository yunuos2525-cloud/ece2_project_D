`timescale 1ns/1ps

module stopwatch #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer TICK_HZ = 100,
    parameter integer MAX_HOURS = 99
) (
    input wire clk, rst,
    input wire start_pulse, stop_pulse, clear_pulse,
    output reg running,
    output reg [6:0] hours,
    output reg [5:0] minutes, seconds,
    output reg [6:0] centiseconds
);
    localparam integer DIVISOR = CLOCK_HZ / TICK_HZ;
    localparam integer DIV_W = (DIVISOR <= 2) ? 1 : $clog2(DIVISOR);
    reg [DIV_W-1:0] div_count;
    always @(posedge clk) begin
        if (rst) begin
            div_count <= 0; running <= 0; hours <= 0;
            minutes <= 0; seconds <= 0; centiseconds <= 0;
        end else begin
            if (start_pulse) running <= 1;
            if (stop_pulse) running <= 0;
            if (clear_pulse) begin
                div_count <= 0; hours <= 0; minutes <= 0;
                seconds <= 0; centiseconds <= 0;
            end else if (running) begin
                if (div_count == DIVISOR - 1) begin
                    div_count <= 0;
                    if (centiseconds == TICK_HZ - 1) begin
                        centiseconds <= 0;
                        if (seconds == 59) begin
                            seconds <= 0;
                            if (minutes == 59) begin
                                minutes <= 0;
                                hours <= (hours == MAX_HOURS) ? 0 : hours + 1'b1;
                            end else minutes <= minutes + 1'b1;
                        end else seconds <= seconds + 1'b1;
                    end else centiseconds <= centiseconds + 1'b1;
                end else div_count <= div_count + 1'b1;
            end
        end
    end
endmodule
