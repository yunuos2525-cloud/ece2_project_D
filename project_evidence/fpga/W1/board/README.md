# FPGA W1 board evidence — NOT YET MEASURED

Status: **PENDING / do not mark complete before physical measurement**.

The bitstream build, if successful, proves only digital implementation for the selected device. It does not prove ADC/DAC analog behavior or STM32-to-FPGA wiring.

Required on-board evidence:

- power-off photos and continuity record for ADC IN, DAC OUT A/B, common GND and BDIO00..03;
- ADC/DAC device markings, reference/supply measurements and switch/jumper positions;
- BDIO03/G8 to J10 route and `BD_SEL1` state;
- one-byte `A5`/`5A`, 16-byte, then full 512-byte+CRC MISO captures;
- oscilloscope CH1 input / CH2 output captures for BYPASS 500 Hz and FIXED mixed 500 Hz + 1 kHz;
- measured attenuation, wanted-signal change, latency and sample-loss status.

Do not connect an external generator until the unresolved ADC voltage range and ground/polarity are checked.
