`timescale 1ns/1ps

module adc_reader_16k #(
    parameter integer HALF_CYCLES = 25
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       sample_tick,
    input  wire [2:0] channel,
    input  wire       adc_dout,
    output wire       adc_sclk,
    output wire       adc_ncs,
    output wire       adc_din,
    output reg  [7:0] sample_data,
    output reg        sample_valid,
    output wire       busy,
    output reg        sample_drop
);
    wire [15:0] command, rx_word;
    wire frame_done;
    reg frame_start, first_frame;

    adc_command u_cmd(.channel(channel), .command(command));
    serial_frame16 #(.HALF_CYCLES(HALF_CYCLES)) u_frame (
        .clk(clk), .rst(rst), .start(frame_start), .tx_word(command),
        .adc_dout(adc_dout), .adc_sclk(adc_sclk), .adc_ncs(adc_ncs),
        .adc_din(adc_din), .busy(busy), .done(frame_done), .rx_word(rx_word)
    );

    always @(posedge clk) begin
        if (rst) begin
            frame_start <= 1'b0;
            first_frame <= 1'b1;
            sample_data <= 8'h00;
            sample_valid <= 1'b0;
            sample_drop <= 1'b0;
        end else begin
            frame_start <= 1'b0;
            sample_valid <= 1'b0;
            sample_drop <= 1'b0;
            if (sample_tick) begin
                if (!busy) frame_start <= 1'b1;
                else sample_drop <= 1'b1;
            end
            if (frame_done) begin
                first_frame <= 1'b0;
                if (!first_frame) begin
                    sample_data <= rx_word[11:4];
                    sample_valid <= 1'b1;
                end
            end
        end
    end
endmodule
