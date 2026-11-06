`timescale 1ns/1ps

module w1_board_top (
    input  wire       clk_50mhz,
    input  wire       rst_p,
    input  wire [2:0] adc_channel,
    input  wire       adc_dout,
    output wire       adc_sclk,
    output wire       adc_ncs,
    output wire       adc_din,
    output wire       dac_a_b,
    output wire       dac_csn,
    output wire       dac_ldacn,
    output wire       dac_wen,
    output wire [7:0] dac_d,
    input  wire       spi_sck,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    output wire       spi_miso,
    output wire [7:0] led_out
);
    wire tick_16k;
    wire rst_50mhz;
    wire [7:0] adc_sample, processed_sample;
    wire adc_valid, adc_busy, adc_drop;
    wire processed_valid;
    wire [7:0] dsp_mode;
    wire overflow;
    wire selected_valid, selected_bank;
    wire [15:0] selected_id;
    wire read_bank, consume_valid, consume_bank, clear_overflow;
    wire [8:0] read_addr;
    wire [7:0] read_data;
    wire [1:0] ready_debug;
    wire [4:0] rtc_hour;
    wire [5:0] rtc_minute, rtc_second, sw_second, sw_minute;
    wire [6:0] sw_centisecond;
    wire sw_running;
    reg adc_drop_sticky;

    reset_conditioner #(.STAGES(3)) u_reset_conditioner (
        .clk(clk_50mhz), .arst_p(rst_p), .rst(rst_50mhz)
    );
    sample_tick u_tick(.clk(clk_50mhz), .rst(rst_50mhz), .tick(tick_16k));
    adc_reader_16k u_adc (
        .clk(clk_50mhz), .rst(rst_50mhz), .sample_tick(tick_16k),
        .channel(adc_channel), .adc_dout(adc_dout), .adc_sclk(adc_sclk),
        .adc_ncs(adc_ncs), .adc_din(adc_din), .sample_data(adc_sample),
        .sample_valid(adc_valid), .busy(adc_busy), .sample_drop(adc_drop)
    );
    audio_path u_audio (
        .clk(clk_50mhz), .rst(rst_50mhz), .dsp_mode(dsp_mode),
        .sample_valid(adc_valid), .sample_in(adc_sample),
        .sample_out_valid(processed_valid), .sample_out(processed_sample)
    );
    dac_writer u_dac_writer (
        .clk(clk_50mhz), .rst(rst_50mhz), .sample_valid(processed_valid),
        .sample_data(processed_sample), .channel(1'b0), .dac_csn(dac_csn),
        .dac_ldacn(dac_ldacn), .dac_wen(dac_wen), .dac_a_b(dac_a_b), .dac_d(dac_d)
    );
    analysis_buffer_512 u_buffer (
        .clk(clk_50mhz), .rst(rst_50mhz), .sample_valid(adc_valid),
        .sample_data(adc_sample), .clear_overflow(clear_overflow),
        .overflow_sticky(overflow), .selected_valid(selected_valid),
        .selected_bank(selected_bank), .selected_id(selected_id),
        .read_bank(read_bank), .read_addr(read_addr), .read_data(read_data),
        .consume_valid(consume_valid), .consume_bank(consume_bank),
        .ready_debug(ready_debug)
    );
    spi_mode0_slave u_spi (
        .clk(clk_50mhz), .rst(rst_50mhz), .spi_sck(spi_sck),
        .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n), .spi_miso(spi_miso),
        .dsp_mode(dsp_mode), .block_valid(selected_valid),
        .block_bank(selected_bank), .block_id(selected_id),
        .block_overflow(overflow), .block_read_bank(read_bank),
        .block_read_addr(read_addr), .block_read_data(read_data),
        .block_consume_valid(consume_valid), .block_consume_bank(consume_bank),
        .clear_overflow(clear_overflow)
    );
    // W1 board-visible baseline: RTC and stopwatch free-run. Debounced user
    // controls and LCD/calendar presentation remain W2 work.
    timekeeper_basic u_timekeeper (
        .clk(clk_50mhz), .rst(rst_50mhz), .sw_start(1'b1), .sw_stop(1'b0),
        .sw_reset(1'b0), .rtc_hour(rtc_hour), .rtc_minute(rtc_minute),
        .rtc_second(rtc_second), .sw_centisecond(sw_centisecond),
        .sw_second(sw_second), .sw_minute(sw_minute), .sw_running(sw_running)
    );

    always @(posedge clk_50mhz) begin
        if (rst_50mhz) adc_drop_sticky <= 1'b0;
        else if (adc_drop) adc_drop_sticky <= 1'b1;
    end

    assign led_out = {dsp_mode == 8'h06, dsp_mode == 8'h02,
                      overflow, adc_drop_sticky, ready_debug,
                      rtc_second[0], sw_second[0]};

    wire _unused_debug = &{1'b0, adc_busy, tick_16k, rtc_hour,
                           rtc_minute, sw_centisecond, sw_minute, sw_running};
endmodule
