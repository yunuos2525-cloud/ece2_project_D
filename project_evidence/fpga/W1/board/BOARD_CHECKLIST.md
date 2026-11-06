# W1 physical-board checklist

- [ ] Confirm board marking and FPGA part/revision match COMBO II-DLD S75 / `xc7s75fgga484-1`.
- [ ] With power off, identify ADC IN signal/GND, selected channel and switch/rotary state.
- [ ] Measure ADC REFIN/AVDD and establish a safe unipolar generator amplitude/offset.
- [ ] Identify DAC OUT A/B signal/GND; measure code `00`, `80`, `FF` before applying a waveform.
- [ ] Confirm J10 positions for BDIO00..03 and `BD_SEL1`/bus switch configuration.
- [ ] Check G8/BDIO03 continuity, 3.3 V compatibility, common GND and no output contention.
- [ ] Start SPI Mode 0 at <=500 kHz: `A5/5A`, 16 bytes, 512 samples+CRC, interrupted transfer/retry.
- [ ] BYPASS: capture function-generator 500 Hz input and DAC output; record gain, offset, latency, clipping and drop LED/status.
- [ ] FIXED: capture 500 Hz, 1 kHz and mixed input/output; calculate 500 Hz change and 1 kHz attenuation.
- [ ] Store original scope/logic-analyzer files, settings, date, bitstream hash and source Git status in this folder.

No item is checked because no physical board was available in this run.
