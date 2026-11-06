`timescale 1ns/1ps

// AD7908 serial cycle reused from the reviewed local LAB5 implementation.
module serial_frame16 #(
    parameter integer HALF_CYCLES = 25
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [15:0] tx_word,
    input  wire        adc_dout,
    output reg         adc_sclk,
    output reg         adc_ncs,
    output reg         adc_din,
    output reg         busy,
    output reg         done,
    output reg  [15:0] rx_word
);
    localparam integer HALF_W = (HALF_CYCLES <= 1) ? 1 : $clog2(HALF_CYCLES);
    reg [HALF_W-1:0] half_count;
    reg [4:0] bit_index;
    reg [15:0] tx_latched;
    reg [2:0] quiet_count;

    always @(posedge clk) begin
        if (rst) begin
            adc_sclk <= 1'b1;
            adc_ncs <= 1'b1;
            adc_din <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            rx_word <= 16'b0;
            tx_latched <= 16'b0;
            half_count <= 0;
            bit_index <= 5'd15;
            quiet_count <= 3'd4;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                adc_sclk <= 1'b1;
                adc_ncs <= 1'b1;
                adc_din <= 1'b0;
                if (quiet_count < 4) quiet_count <= quiet_count + 1'b1;
                if (start && quiet_count == 4) begin
                    adc_ncs <= 1'b0;
                    adc_din <= tx_word[15];
                    tx_latched <= tx_word;
                    busy <= 1'b1;
                    bit_index <= 5'd15;
                    half_count <= 0;
                    rx_word <= 0;
                end
            end else if (half_count == HALF_CYCLES - 1) begin
                half_count <= 0;
                if (adc_sclk) begin
                    rx_word[bit_index] <= adc_dout;
                    adc_sclk <= 1'b0;
                end else begin
                    adc_sclk <= 1'b1;
                    if (bit_index == 0) begin
                        adc_ncs <= 1'b1;
                        adc_din <= 1'b0;
                        busy <= 1'b0;
                        done <= 1'b1;
                        quiet_count <= 0;
                    end else begin
                        bit_index <= bit_index - 1'b1;
                        adc_din <= tx_latched[bit_index - 1'b1];
                    end
                end
            end else half_count <= half_count + 1'b1;
        end
    end
endmodule
