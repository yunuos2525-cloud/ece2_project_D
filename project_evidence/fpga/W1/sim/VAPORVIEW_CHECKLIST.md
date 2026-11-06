# VaporView capture checklist

Open the fresh VCD files below after `FPGA/tools/run_sim.ps1`. Save screenshots with the listed names under this directory. VCD time values are simulation time; the filter test intentionally presents one sample per RTL clock to keep the file manageable, so its sample index—not the 20 ns testbench clock—is the audio-time reference.

- [ ] `tb_sample_tick.vcd`, 0–260 us: `clk`, `rst`, `tick`, `dut.count`. Confirm 62.5 us spacing and one-clock tick. Save `capture_sample_tick_0_260us.png`.
- [ ] `tb_audio_path.vcd`, full run: `dsp_mode`, `sample_valid`, `sample_in`, `sample_out_valid`, `sample_out`, `bypass_delay`. Confirm BYPASS ordering and AUTO fallback. Save `capture_audio_bypass_full.png`.
- [ ] `tb_iir_notch_fixed.vcd`, first 40 us of each reset-delimited case: `sample_in`, `sample_out`, `sample_out_valid`, `dut.x1`, `dut.y1`, `dut.acc`, `dut.scaled`. Show the 1 kHz transient and settled reduction. Save `capture_notch_transient.png`.
- [ ] `tb_analysis_buffer_512.vcd`, around each `wr_addr=511`: `sample_valid`, `sample_data`, `dut.wr_addr`, `ready_debug`, `selected_id`, `overflow_sticky`, `consume_valid`. Save `capture_buffer_handoff_overflow.png`.
- [ ] `tb_spi_read_block.vcd`, first command and first 6 response bytes: `spi_cs_n`, `spi_sck`, `spi_mosi`, `spi_miso`, `spi.bit_count`, `spi.response_pos`, `read_addr`. Also capture the aborted frame CS high and retry. Save `capture_spi_header.png` and `capture_spi_abort_retry.png`.
- [ ] `tb_timekeeper_basic.vcd`, full run: `rtc_hour`, `rtc_minute`, `rtc_second`, `sw_running`, `sw_centisecond`, `sw_second`, `sw_start`, `sw_stop`, `sw_reset`. Save `capture_timekeeper_boundaries.png`.
- [ ] `tb_adc_dac_bypass.vcd`, 0–300 us: `adc_ncs`, `adc_sclk`, `adc_dout`, `dut.adc_valid`, `dut.adc_sample`, `dut.processed_valid`, `dac_wen`, `dac_d`. Save `capture_adc_dac_bypass.png`.

Do not label these screenshots as board measurements.

## Reset-fix capture

- [ ] `tb_reset_recovery.vcd`, startup through the first reset release: `clk`, `arst_p`, `rst`, `reset_dut.sync_ff`. Confirm immediate assertion and deassertion after exactly three rising edges. Save `capture_reset_assert_release.png`.
- [ ] `tb_reset_recovery.vcd`, around the reset asserted while `sample_valid=1`: `arst_p`, `rst`, `sample_valid`, `sample_in`, `sample_out_valid`, `dsp_mode`, `selected_valid`, `ready_debug`. Save `capture_reset_mid_sample.png`.
- [ ] `tb_reset_recovery.vcd`, around the reset asserted while `spi_sck=1`: `arst_p`, `rst`, `spi_cs_n`, `spi_sck`, `spi_mosi`, `spi_miso`, `spi_dut.bit_count`, `block_consume_valid`, `selected_valid`. Confirm that the interrupted packet is not consumed or advertised after reset. Save `capture_reset_mid_spi.png`.
- [ ] `tb_reset_recovery.vcd`, final post-reset block transfer: `spi_cs_n`, `spi_sck`, `spi_miso`, `block_read_addr`, `block_read_data`, `block_consume_valid`, `selected_id`. Confirm block ID 0, all 512 bytes, CRC completion and consume. Save `capture_reset_full_recovery.png`.

The VCD runs to approximately 6.447 ms. Use signal transitions above to locate each interval; do not label these screenshots as physical-board measurements.
