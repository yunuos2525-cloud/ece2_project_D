# VaporView required user captures

All items are currently **not captured**. Open the VCDs under
`project_evidence/fpga/W1/sim/reset_fix_20261106/`. Times below are simulation
times, not physical-board measurements.

- [ ] `tb_sample_tick.vcd`, `0–250.1 us`: `clk`, `rst`, `tick`, `dut.count`.
  Confirm 3,125-clock intervals and one-clock pulse width. Save as
  `w1_sim_sample_tick_0_250us.png`.
- [ ] `tb_iir_notch_fixed.vcd`, `0–82 us` and `246–328 us`: `sample_in`,
  `sample_out`, `sample_out_valid`, `dut.x1`, `dut.y1`, `dut.acc`, `dut.scaled`.
  Capture A40 500 Hz and A35+A35 mixed cases separately. Save as
  `w1_sim_notch_a40_500hz.png` and `w1_sim_notch_mixed_a35.png`.
- [ ] `tb_spi_read_block.vcd`, `40.5–100 us`: `spi_cs_n`, `spi_sck`,
  `spi_mosi`, `spi_miso`, `spi.bit_count`, `spi.response_pos`, `read_addr`,
  `selected_id`. Show command/status/ID and first data bytes. Save as
  `w1_sim_spi_read_block_header.png`.
- [ ] `tb_spi_read_block.vcd`, `6.28–6.54 ms`: `spi_cs_n`, `spi_sck`,
  `spi_miso`, `selected_valid`, `selected_id`, `consume_valid`, `read_addr`.
  Show aborted transfer retaining block ID 1 and retry start. Save as
  `w1_sim_spi_abort_retry.png`.
- [ ] `tb_reset_recovery.vcd`, `0–0.12 us`: `clk`, `arst_p`, `rst`,
  `reset_dut.sync_ff`. Confirm immediate assertion and three-edge release. Save
  as `w1_sim_reset_assert_release.png`.
- [ ] `tb_reset_recovery.vcd`, `187.0–187.8 us`: `arst_p`, `rst`, `spi_cs_n`,
  `spi_sck`, `spi_miso`, `spi_dut.bit_count`, `selected_valid`,
  `block_consume_valid`. Show mid-SPI reset without consume. Save as
  `w1_sim_reset_mid_spi.png`.
- [ ] `tb_adc_dac_bypass.vcd`, `0–266.3 us`: `adc_ncs`, `adc_sclk`,
  `adc_dout`, `dut.adc_valid`, `dut.adc_sample`, `dut.processed_valid`,
  `dac_wen`, `dac_d`. Save as `w1_sim_adc_dac_bypass.png`.
- [ ] `tb_timekeeper_basic.vcd`, `0–2.366 us`: `rtc_hour`, `rtc_minute`,
  `rtc_second`, `sw_running`, `sw_centisecond`, `sw_second`, `sw_start`,
  `sw_stop`, `sw_reset`. Save as `w1_sim_timekeeper.png`.

Do not label these captures as Program Device, ADC/DAC measurement or physical
SPI evidence.
