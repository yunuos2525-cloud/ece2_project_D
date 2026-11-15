`timescale 1ns/1ps

module calendar_clock #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer INITIAL_YEAR = 2026,
    parameter integer INITIAL_MONTH = 1,
    parameter integer INITIAL_DAY = 1,
    parameter integer INITIAL_WEEKDAY = 4,
    parameter integer INITIAL_HOUR = 0,
    parameter integer INITIAL_MINUTE = 0,
    parameter integer INITIAL_SECOND = 0
) (
    input wire clk, rst,
    output reg [13:0] year,
    output reg [3:0] month,
    output reg [5:0] day,
    output reg [2:0] weekday,
    output reg [4:0] hour,
    output reg [5:0] minute, second
);
    localparam integer SEC_W = (CLOCK_HZ <= 2) ? 1 : $clog2(CLOCK_HZ);
    reg [SEC_W-1:0] sec_count;
    function automatic is_leap;
        input [13:0] y;
        begin is_leap = ((y % 400) == 0) || (((y % 4) == 0) && ((y % 100) != 0)); end
    endfunction
    function automatic [5:0] days_in_month;
        input [13:0] y;
        input [3:0] m;
        begin
            case (m)
                4,6,9,11: days_in_month = 30;
                2: days_in_month = is_leap(y) ? 29 : 28;
                default: days_in_month = 31;
            endcase
        end
    endfunction
    always @(posedge clk) begin
        if (rst) begin
            sec_count <= 0; year <= INITIAL_YEAR; month <= INITIAL_MONTH;
            day <= INITIAL_DAY; weekday <= INITIAL_WEEKDAY; hour <= INITIAL_HOUR;
            minute <= INITIAL_MINUTE; second <= INITIAL_SECOND;
        end else if (sec_count == CLOCK_HZ - 1) begin
            sec_count <= 0;
            if (second != 59) second <= second + 1'b1;
            else begin
                second <= 0;
                if (minute != 59) minute <= minute + 1'b1;
                else begin
                    minute <= 0;
                    if (hour != 23) hour <= hour + 1'b1;
                    else begin
                        hour <= 0;
                        weekday <= (weekday == 6) ? 0 : weekday + 1'b1;
                        if (day < days_in_month(year, month)) day <= day + 1'b1;
                        else begin
                            day <= 1;
                            if (month == 12) begin month <= 1; year <= year + 1'b1; end
                            else month <= month + 1'b1;
                        end
                    end
                end
            end
        end else sec_count <= sec_count + 1'b1;
    end
endmodule
