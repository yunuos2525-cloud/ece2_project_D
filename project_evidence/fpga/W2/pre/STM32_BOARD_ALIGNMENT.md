# STM32 target-board alignment

## Confirmed target

The physical STM32 integration target is **NUCLEO-G474RE**. This is a project confirmation recorded for the W2 FPGA PRE handoff; no physical-board SPI result is inferred from it.

The STM32 source used by the cross-integration test is commit `91a1a077fabd8a4c83a0ea8f5b9237c45b87b70b` on `origin/feat/stm32`. Its repository evidence is consistent with G474RE:

- `STM32/README.md` identifies the firmware as NUCLEO-G474RE firmware and documents the G474 build output.
- `STM32/CMakePresets.json` selects `STM32_BOARD=NUCLEO_G474RE` in the `g474-debug` preset.
- `STM32/cmake/arm-gcc.cmake` defaults `STM32_BOARD` to `NUCLEO_G474RE`.
- The documented G474RE signal locations are PB3/D3 SCK, PA7/D11 MOSI, PA6/D12 MISO, and PB6/D10 CS.
- The actual C implementation configures SPI Mode 0, MSB first, and nominal 500 kHz for the G474 path.

## Common-spec discrepancy retained for team review

`docs/TEAM_SPI_INTERFACE_v8_final.md` still names **NUCLEO-H533RE**, gives H533RE-specific CN5/CN10 connector numbering, and cites the STM32H5 Nucleo-64 board manual. Those board-specific statements do not describe the confirmed G474RE target and require a joint document update.

This FPGA commit does **not** change the shared specification because the user required team agreement before changing common pin assignments or protocol text. The following items should be corrected jointly:

1. Replace the H533RE board name and H533-specific CN5/CN10 references with verified NUCLEO-G474RE connector references.
2. Replace the STM32H5 board-manual citation with the appropriate G474RE board documentation.
3. Preserve the already matching signal-level assignment unless the physical wiring review finds otherwise: PB3 SCK, PA7 MOSI, PB6 CS, PA6 MISO.
4. Preserve SPI Mode 0, MSB-first, command bytes, frame layouts, CRC, and Q2.14 rules; the cross-integration simulation verified those protocol elements.

## Still required before POST

- Verify PA6/D12 to FPGA G8 through J10/BD_SEL1 on the actual equipment.
- Verify common GND, 3.3 V compatibility, pin direction, and absence of MISO contention.
- Capture CS/SCK/MOSI/MISO on the physical NUCLEO-G474RE with a logic analyzer.
- Keep ADC external timing, ADC CDC closure, CFGBVS/configuration-bank voltage, and analog-path measurements open.

PRE and POST remain distinct: the PC-host C/RTL cross test is PASS, while physical NUCLEO-G474RE operation is not yet verified.
