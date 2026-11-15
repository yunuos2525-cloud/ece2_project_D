`timescale 1ns/1ps

module w2_board_top #(
    parameter integer BUTTON_ACTIVE_LOW = 0
) (
    input wire clk_50mhz, rst_p,
    input wire [2:0] adc_channel,
    input wire adc_dout,
    output wire adc_sclk, adc_ncs, adc_din,
    output wire dac_a_b, dac_csn, dac_ldacn, dac_wen,
    output wire [7:0] dac_d,
    input wire spi_sck, spi_mosi, spi_cs_n,
    output wire spi_miso,
    input wire [1:0] display_mode,
    input wire sw_start_btn, sw_stop_btn, sw_reset_switch,
    output wire lcd_e, lcd_rs, lcd_rw,
    output wire [7:0] lcd_data,
    output wire [7:0] led_out
);
    wire rst_50mhz, tick_16k, adc_valid, adc_busy, adc_drop, processed_valid;
    wire [7:0] adc_sample, processed_sample, dsp_mode;
    wire overflow, selected_valid, selected_bank, read_bank;
    wire [15:0] selected_id;
    wire [8:0] read_addr;
    wire [7:0] read_data;
    wire consume_valid, consume_bank, clear_overflow;
    wire [1:0] ready_debug;
    wire coeff_update_valid, auto_coeff_valid, coeff_applied;
    wire [7:0] coeff_update_seq, applied_coeff_seq;
    wire signed [15:0] coeff_b0,coeff_b1,coeff_b2,coeff_a1,coeff_a2;
    wire start_pulse,stop_pulse,reset_pulse;
    wire start_level,stop_level,reset_level;
    wire [1:0] display_level;
    wire display_dummy0,display_dummy1;
    wire [13:0] year; wire [3:0] month; wire [5:0] day;
    wire [2:0] weekday; wire [4:0] hour; wire [5:0] minute,second;
    wire sw_running; wire [6:0] sw_hours,sw_centiseconds;
    wire [5:0] sw_minutes,sw_seconds;
    reg adc_drop_sticky;

    reset_conditioner #(.STAGES(3)) u_reset_conditioner(.clk(clk_50mhz),.arst_p(rst_p),.rst(rst_50mhz));
    sample_tick u_tick(.clk(clk_50mhz),.rst(rst_50mhz),.tick(tick_16k));
    adc_reader_16k u_adc(.clk(clk_50mhz),.rst(rst_50mhz),.sample_tick(tick_16k),
        .channel(adc_channel),.adc_dout(adc_dout),.adc_sclk(adc_sclk),.adc_ncs(adc_ncs),
        .adc_din(adc_din),.sample_data(adc_sample),.sample_valid(adc_valid),.busy(adc_busy),.sample_drop(adc_drop));
    audio_path_w2 u_audio(.clk(clk_50mhz),.rst(rst_50mhz),.dsp_mode(dsp_mode),
        .sample_valid(adc_valid),.sample_in(adc_sample),.coeff_update_valid(coeff_update_valid),
        .coeff_update_seq(coeff_update_seq),.coeff_b0(coeff_b0),.coeff_b1(coeff_b1),
        .coeff_b2(coeff_b2),.coeff_a1(coeff_a1),.coeff_a2(coeff_a2),
        .auto_coeff_valid(auto_coeff_valid),.applied_coeff_seq(applied_coeff_seq),
        .coeff_applied(coeff_applied),.sample_out_valid(processed_valid),.sample_out(processed_sample));
    dac_writer u_dac(.clk(clk_50mhz),.rst(rst_50mhz),.sample_valid(processed_valid),
        .sample_data(processed_sample),.channel(1'b0),.dac_csn(dac_csn),.dac_ldacn(dac_ldacn),
        .dac_wen(dac_wen),.dac_a_b(dac_a_b),.dac_d(dac_d));
    analysis_buffer_512 u_buffer(.clk(clk_50mhz),.rst(rst_50mhz),.sample_valid(adc_valid),
        .sample_data(adc_sample),.clear_overflow(clear_overflow),.overflow_sticky(overflow),
        .selected_valid(selected_valid),.selected_bank(selected_bank),.selected_id(selected_id),
        .read_bank(read_bank),.read_addr(read_addr),.read_data(read_data),.consume_valid(consume_valid),
        .consume_bank(consume_bank),.ready_debug(ready_debug));
    spi_mode0_slave_w2 u_spi(.clk(clk_50mhz),.rst(rst_50mhz),.spi_sck(spi_sck),
        .spi_mosi(spi_mosi),.spi_cs_n(spi_cs_n),.spi_miso(spi_miso),.dsp_mode(dsp_mode),
        .coeff_update_valid(coeff_update_valid),.coeff_update_seq(coeff_update_seq),
        .coeff_b0(coeff_b0),.coeff_b1(coeff_b1),.coeff_b2(coeff_b2),.coeff_a1(coeff_a1),.coeff_a2(coeff_a2),
        .auto_coeff_valid(auto_coeff_valid),.applied_coeff_seq(applied_coeff_seq),
        .block_valid(selected_valid),.block_bank(selected_bank),.block_id(selected_id),
        .block_overflow(overflow),.block_read_bank(read_bank),.block_read_addr(read_addr),
        .block_read_data(read_data),.block_consume_valid(consume_valid),.block_consume_bank(consume_bank),
        .clear_overflow(clear_overflow));

    input_conditioner #(.ACTIVE_LOW(BUTTON_ACTIVE_LOW)) u_start(.clk(clk_50mhz),.rst(rst_50mhz),
        .async_in(sw_start_btn),.stable_level(start_level),.press_pulse(start_pulse),.release_pulse());
    input_conditioner #(.ACTIVE_LOW(BUTTON_ACTIVE_LOW)) u_stop(.clk(clk_50mhz),.rst(rst_50mhz),
        .async_in(sw_stop_btn),.stable_level(stop_level),.press_pulse(stop_pulse),.release_pulse());
    input_conditioner #(.STABLE_CYCLES(50_000)) u_sw_reset(.clk(clk_50mhz),.rst(rst_50mhz),
        .async_in(sw_reset_switch),.stable_level(reset_level),.press_pulse(reset_pulse),.release_pulse());
    input_conditioner #(.STABLE_CYCLES(50_000)) u_display0(.clk(clk_50mhz),.rst(rst_50mhz),
        .async_in(display_mode[0]),.stable_level(display_level[0]),.press_pulse(display_dummy0),.release_pulse());
    input_conditioner #(.STABLE_CYCLES(50_000)) u_display1(.clk(clk_50mhz),.rst(rst_50mhz),
        .async_in(display_mode[1]),.stable_level(display_level[1]),.press_pulse(display_dummy1),.release_pulse());
    stopwatch u_stopwatch(.clk(clk_50mhz),.rst(rst_50mhz),.start_pulse(start_pulse),
        .stop_pulse(stop_pulse),.clear_pulse(reset_pulse),.running(sw_running),.hours(sw_hours),
        .minutes(sw_minutes),.seconds(sw_seconds),.centiseconds(sw_centiseconds));
    calendar_clock u_calendar(.clk(clk_50mhz),.rst(rst_50mhz),.year(year),.month(month),
        .day(day),.weekday(weekday),.hour(hour),.minute(minute),.second(second));
    lcd_status_display u_lcd(.clk(clk_50mhz),.rst(rst_50mhz),.display_mode(display_level),
        .dsp_mode(dsp_mode),.auto_coeff_valid(auto_coeff_valid),.applied_coeff_seq(applied_coeff_seq),
        .block_overflow(overflow),.year(year),.month(month),.day(day),.weekday(weekday),
        .hour(hour),.minute(minute),.second(second),.sw_running(sw_running),.sw_hours(sw_hours),
        .sw_minutes(sw_minutes),.sw_seconds(sw_seconds),.sw_centiseconds(sw_centiseconds),
        .lcd_e(lcd_e),.lcd_rs(lcd_rs),.lcd_rw(lcd_rw),.lcd_data(lcd_data));

    always @(posedge clk_50mhz) begin
        if(rst_50mhz) adc_drop_sticky<=0; else if(adc_drop) adc_drop_sticky<=1;
    end
    assign led_out={dsp_mode==8'h06,dsp_mode==8'h02,auto_coeff_valid,overflow,
                    adc_drop_sticky,ready_debug,sw_running};
    wire _unused=&{1'b0,adc_busy,tick_16k,coeff_applied,start_level,stop_level,reset_level,
                    display_dummy0,display_dummy1};
endmodule
