# Deferred beyond W1

- `SET_COEFF` (`0x20`) receive packet, CRC validation, Q2.14 five-coefficient staging and atomic application.
- `READ_STATE` (`0x21`) and applied coefficient sequence reporting.
- Actual AUTO variable-notch datapath; W1 deliberately falls back to BYPASS for mode `0x06`.
- Variable-notch tests at 930, 1,370, 1,830 and 2,460 Hz and coefficient-switch transient measurement.
- Full calendar (year/month/day/weekday/leap year), debounced buttons/switches and Text LCD display pages.
- Physical STM32 integration, analog attenuation/latency measurement and repeated restart/recovery tests.

These are W2 or later roadmap items and are not represented as completed by the W1 simulation.
