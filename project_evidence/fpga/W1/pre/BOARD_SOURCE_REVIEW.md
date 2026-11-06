# Existing board-source review (read-only)

Review date: 2026-11-06. No file under the existing `ece2_2026` repository was modified.

## Confirmed from existing local material

- Board: Hanback COMBO II-DLD S75.
- FPGA part used by prior successful Vivado flows: `xc7s75fgga484-1` (Spartan-7).
- 50 MHz clock: B6; active-high reset input: K4.
- ADC serial interface: NCS H3, DIN H5, DOUT J6, SCLK H7. Prior material identifies an AD7908-style 16-bit serial reply and uses bits `[11:4]` as the 8-bit sample.
- Parallel DAC interface: A/B G2, CSN E1, LDACN F4, WEN G4, data pins E3/E5/D2/D5/C2/C4/B1/B3.
- STM32-facing SPI: SCK BDIO00/F8, MOSI BDIO01/E8, CSN BDIO02/A7, MISO BDIO03/G8.
- Reviewed sources: `ece2_2026/PROJECT/docs/pinmap.md`, `PROJECT/FPGA/constraints/project.xdc`, LAB5 ADC, LAB6 DAC, LAB7 SPI XDC/research and Vivado evidence.

## Still requires physical inspection

- Exact ADC input terminal/channel, ADC REFIN/AVDD and safe analog range on the installed board revision.
- Exact DAC output terminal A/B, reference voltage, full-scale voltage and load restrictions.
- BDIO03 physical J10 position, `BD_SEL1`/bus-switch state, continuity to G8, 3.3 V compatibility and absence of another driver.
- Common-ground continuity and connector polarity.

The supplied board top and XDC use only package mappings supported by the reviewed sources. They do not guess the unresolved analog terminal or jumper state.
