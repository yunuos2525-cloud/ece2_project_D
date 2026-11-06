# W1 reset fix regression

Run date: 2026-11-06 (Asia/Seoul)
Branch: `feat/fpga`
Simulator: Icarus Verilog 12.0 development build, SystemVerilog 2012 mode

The original logs, VCDs and bitstream were preserved before this run under
`project_evidence/fpga/W1/reset_fix/pre/` and `FPGA/build/w1_pre_reset_fix/`.
An immutable copy of this run is under `sim/reset_fix_20261106/`; the table
below names files within that directory.

## Regression result

| Test | Result | Evidence |
|---|---|---|
| 50 MHz / 16 kHz sample tick | PASS | `sample_tick.log`, `tb_sample_tick.vcd` |
| 8-bit BYPASS/AUTO fallback | PASS | `audio_path.log`, `tb_audio_path.vcd` |
| Fixed 1 kHz Notch | PASS | `iir_notch_fixed.log`, `notch_metrics.csv`, `tb_iir_notch_fixed.vcd` |
| 512-sample block buffer | PASS | `analysis_buffer_512.log`, VCD |
| SPI Mode 0 / READ_BLOCK / CRC / abort | PASS | `spi_read_block.log`, VCD |
| RTC/stopwatch basic counter | PASS | `timekeeper_basic.log`, VCD |
| Reset recovery integration | PASS | `reset_recovery.log`, `tb_reset_recovery.vcd` |
| Modeled ADC-to-DAC BYPASS | PASS | `adc_dac_bypass.log`, VCD |

`simulation_summary.log` records eight PASS results and no FAIL result.

## Reset-specific checks

The new integration test uses a testbench-calculated pattern and CRC-8/ATM,
not internal DUT state, for packet acceptance. It checks:

- asynchronous assertion between 50 MHz clock edges;
- synchronous deassertion only after three rising edges;
- assertion while a sample and Notch history are active;
- assertion while READ_BLOCK is active and SCK is high;
- no stale ready block, consume pulse or partial packet after reset;
- clean restart of BYPASS, fixed Notch, block ID 0, 512 data bytes and CRC.

Actual result:

```text
PASS RESET_RECOVERY: async assert, 3-edge release, sample/SPI interruption, clean BYPASS/notch/buffer/SPI restart
```

## Notch calculation correction

The coefficients, integer input sequences, 4,096-sample length and
512..4095 measurement window are unchanged. The corrected gain divides the
output correlation by the measured spectrum of the actual quantized input in
the same window.

| Input case | Quantized input | Output | Corrected gain | Criterion | Result |
|---|---:|---:|---:|---|---|
| 500 Hz A40 | 39.798794 | 36.040817 | -0.862 dB | wanted error <= 1 dB | PASS |
| 500 Hz A35 | 34.774371 | 33.473357 | -0.331 dB | wanted error <= 1 dB | PASS |
| 1 kHz A40 | 39.861392 | 0.000000 | -332.908 dB numerical floor | attenuation >= 10 dB | PASS |
| mixed A35+A35, 500 Hz | 35.105350 | 34.266899 | -0.210 dB | wanted error <= 1 dB | PASS |
| mixed A35+A35, 1 kHz | 34.892729 | 1.509702 | -27.277 dB | attenuation >= 10 dB | PASS |

The previous nominal-denominator values (`-0.905 dB` pure A40 and
`-0.184 dB` mixed wanted component) are retained in
`reset_fix/pre/sim/iir_notch_fixed.log` and the previous FINAL_REVIEW. No pass
threshold was relaxed. The pure 1 kHz result is a digital correlation floor,
not an analog attenuation claim.

## Scope limit

The VCDs prove RTL behavior only. They do not prove physical reset pulse
quality, SPI connector timing, ADC/DAC timing or analog performance.
