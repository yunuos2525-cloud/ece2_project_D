`timescale 1ns/1ps

module sample_tick #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer SAMPLE_HZ = 16_000
) (
    input  wire clk,
    input  wire rst,
    output reg  tick
);
    localparam integer DIVISOR = CLOCK_HZ / SAMPLE_HZ;
    localparam integer COUNT_W = (DIVISOR <= 2) ? 1 : $clog2(DIVISOR);
    reg [COUNT_W-1:0] count;

    initial begin
        if ((CLOCK_HZ % SAMPLE_HZ) != 0)
            $error("sample_tick requires an integer clock/sample ratio");
    end

    always @(posedge clk) begin
        if (rst) begin
            count <= {COUNT_W{1'b0}};
            tick  <= 1'b0;
        end else if (count == DIVISOR - 1) begin
            count <= {COUNT_W{1'b0}};
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end
endmodule
