# FPGA W1 simulation and bitstream archive

Date: 2026-11-06 (Asia/Seoul)

Branch: `feat/fpga`

## Implemented W1 scope

- 50 MHz / 16 kHz sample enable and modeled 8-bit ADC-to-DAC path.
- Bit-exact BYPASS and signed Q2.14 fixed 1 kHz second-order IIR Notch.
- Immutable double-bank 512-sample buffer with block ID and overflow state.
- Synchronized SPI Mode 0 slave with `READ_BLOCK`, 512 data bytes,
  CRC-8/ATM, complete-transfer consume and abort/retry.
- W1 RTC/stopwatch basic counters.
- Three-stage active-high external reset conditioner: asynchronous assertion
  and synchronous deassertion in the 50 MHz domain.
- COMBO II-DLD S75 top/XDC and Vivado 2026.1 non-project build flow.

## Verified results

- Eight self-checking simulations PASS: sample tick, audio path, fixed Notch,
  analysis buffer, SPI, timekeeper, reset recovery and modeled ADC-to-DAC
  BYPASS. One latest VCD and textual PASS log per test are archived.
- Corrected quantized-input Notch gains: A40 500 Hz `-0.862 dB`, A35 500 Hz
  `-0.331 dB`, mixed A35+A35 500 Hz `-0.210 dB`, and mixed 1 kHz
  `-27.277 dB`. Thresholds remain wanted error <=1 dB and interference
  attenuation >=10 dB.
- Reset-related CDC changed from `CDC-1 8688` plus `CDC-13 4` to one
  informational depth-3 `CDC-9` reset synchronizer.
- Vivado synthesis, implementation, route and write_bitstream PASS.
- Routed timing: WNS `+5.744 ns`, TNS `0`, WHS `+0.096 ns`, THS `0`.
- DRC: 0 errors; one `CFGBVS-1` and four `DPIP-1` warnings retained.

## Bitstream identity

The `.bit` is not committed to Git. Its local build result is:

- Path: `FPGA/build/w1/w1_board_top.bit`
- Size: 3,687,015 bytes
- SHA-256: `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`

`board/vivado/reset_fix_20261106_public/BUILD_INPUTS.sha256` records every
RTL/XDC/Tcl build input and the Bitstream hash. Current files match that
manifest.

## Evidence state

- PRE: complete; original `pre/TEST_PLAN.md` preserved.
- SIM: complete; eight PASS logs, eight testbenches, numeric results and eight
  latest VCDs archived.
- VIVADO DIGITAL BUILD: complete; synthesis/implementation/timing/CDC/DRC
  text reports archived with host/user paths sanitized.
- BOARD: `NOT_VERIFIED`.
- STM32 PHYSICAL SPI/MISO: `NOT_VERIFIED`.

Eleven ADC `CDC-1` paths, eight externally false-pathed inputs, 21 outputs
without output delay, BDIO03/G8 routing, J10/`BD_SEL1`, configuration voltage,
analog references and safe ranges remain open. Program Device, ADC/DAC
measurement and physical STM32 MISO transfer have not been claimed.

## Deferred to W2+

Variable coefficient receive/application, real AUTO filtering, full calendar,
debounced controls and Text LCD remain deferred. No W2 feature was added by
this archive operation.
