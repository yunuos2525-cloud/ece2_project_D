# FPGA W1 simulation results

## Reset-fix rerun — 2026-11-06

The post-fix regression ran all original seven tests plus the new
`reset_recovery` integration test. All eight tests PASS. The new test checks
asynchronous assertion, three-edge synchronous release, reset during sample
processing, reset during READ_BLOCK, rejection of an interrupted packet, and
clean BYPASS/Notch/buffer/SPI restart. See `RESET_FIX_REGRESSION.md`,
`reset_recovery.log`, and `tb_reset_recovery.vcd`.

The current Notch metrics now use the measured spectrum of the quantized
input as the denominator: A40 pure 500 Hz `-0.862 dB`, A35 pure 500 Hz
`-0.331 dB`, and mixed A35+A35 `-0.210 dB` at 500 Hz / `-27.277 dB` at
1 kHz. The acceptance limits remain <=1 dB wanted-component error and >=10 dB
interference attenuation. The table below is the preserved original
nominal-denominator record, not the corrected current metric.

---

## Preserved original seven-test record

Run date: 2026-11-06 (Asia/Seoul)
Simulator: Icarus Verilog 12.0 development build, SystemVerilog 2012 mode.

| Test | Actual result | Evidence |
|---|---|---|
| 50 MHz / 16 kHz tick | PASS — divisor 3,125; one-clock pulse; four repeated intervals | `sample_tick.log`, `tb_sample_tick.vcd` |
| 8-bit BYPASS/AUTO fallback | PASS — `00 80 A5 5A FF 01 7F C3` preserved; W1 AUTO is BYPASS | `audio_path.log`, `tb_audio_path.vcd` |
| Fixed 1 kHz notch | PASS — all three numeric cases meet the pre-recorded thresholds | `iir_notch_fixed.log`, `notch_metrics.csv`, VCD |
| 512-sample double buffer | PASS — ordering, stable reads, two-bank overflow flag and consume | `analysis_buffer_512.log`, VCD |
| SPI Mode 0 `READ_BLOCK` | PASS — mode commands, empty status, `A5/5A`, ID, 512 samples, CRC and abort/retry | `spi_read_block.log`, VCD |
| Basic RTC/stopwatch | PASS — RTC rollover and stopwatch start/stop/reset | `timekeeper_basic.log`, VCD |
| Modeled ADC→DAC BYPASS | PASS — first ADC pipeline frame discarded; `12 A5 7E` reach DAC unchanged | `adc_dac_bypass.log`, VCD |

## Numeric notch result

| Input | 500 Hz output/change | 1 kHz output/change | Verdict |
|---|---:|---:|---|
| 500 Hz, amplitude 40 | 36.0408 / -0.905 dB | — | PASS (damage <=1 dB) |
| 1 kHz, amplitude 40 | — | quantized to zero / -332.938 dB computed floor | PASS (attenuation >=10 dB) |
| 500 Hz + 1 kHz, amplitudes 35+35 | 34.2669 / -0.184 dB | 1.5097 / -27.304 dB | PASS |

The pure-tone `-332.938 dB` is a numerical simulation result caused by a zero measured correlation after fixed-point quantization; it is not a physically achievable analog attenuation claim. The mixed-signal result (-27.304 dB) is the useful finite W1 performance figure. Analog performance remains unmeasured.

## Error found and corrected

The first SPI regression exposed a last-bit timing error: the response register loaded the next byte on the eighth SCK rising edge, changing MISO before the master sampled the final bit. The design now stages the next byte and loads it on the following falling edge, consistent with Mode 0. The complete regression was rerun after the fix and all tests passed.

Icarus emits a benign compile warning that the combinational memory read block is sensitive to all 512 entries. The warning is retained in the compile logs. During the original attempt Vivado synthesis was not reached because its launcher could not obtain a license; a later licensed retry completed synthesis, implementation and bitstream generation. The original failure and successful retry are both retained in `../board/BUILD_STATUS.md`.
