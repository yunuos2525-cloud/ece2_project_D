# W1 GitHub archive status

## Completed evidence

- Eight self-checking simulations: PASS logs, numeric Notch CSV, testbenches
  and one latest VCD per test.
- Reset correction: pre/post CDC and timing reports plus reset regression VCD.
- Vivado 2026.1 synthesis, implementation, timing, CDC, DRC, utilization and
  build log in path-sanitized text form.
- Bitstream identity: 3,687,015 bytes, SHA-256
  `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`.
- Pre-implementation `pre/TEST_PLAN.md` and prior failure/correction history.

## NOT_VERIFIED

- `NOT_VERIFIED`: Program Device on the school FPGA board.
- `NOT_VERIFIED`: physical ADC input and DAC output waveform/attenuation.
- `NOT_VERIFIED`: STM32-to-FPGA physical SPI, including MISO transfer timing.
- `NOT_VERIFIED`: eleven remaining ADC `CDC-1` paths and ADC input timing.
- `NOT_VERIFIED`: eight asynchronous/false-pathed inputs and 21 outputs without
  external I/O delays.
- `NOT_VERIFIED`: BDIO03/G8 physical route, J10, `BD_SEL1`, bus contention and
  3.3 V compatibility.
- `NOT_VERIFIED`: `CFGBVS`, `CONFIG_VOLTAGE`, ADC/DAC reference and safe analog
  ranges for the exact board revision.

No screenshot is claimed as captured. The required user captures remain
unchecked in `sim/VAPORVIEW_REQUIRED_CAPTURES.md`.
