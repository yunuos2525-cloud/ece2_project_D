# FPGA W1 and W2 implementation

## Structure

- `src/sample_tick.sv`: 50 MHz to 16 kHz clock-enable generator.
- `src/iir_notch_fixed.sv`, `audio_path.sv`: signed Q2.14 fixed 1 kHz notch and BYPASS/FIXED selection. W1 AUTO safely falls back to BYPASS.
- `src/analysis_buffer_512.sv`: two immutable 512-byte banks, block IDs and sticky overflow reporting.
- `src/spi_mode0_slave.sv`: synchronized Mode-0/MSB-first slave, mode commands and v8 `READ_BLOCK`/CRC/abort semantics.
- `src/timekeeper_basic.sv`: W1 RTC h:m:s and 10 ms stopwatch counters.
- `src/adc_*`, `serial_frame16.sv`, `dac_*`: project-owned board I/O path based on reviewed prior LAB modules.
- `src/w1_board_top.sv`: COMBO II-DLD S75 integration top.
- `sim/`: self-checking testbenches.
- `constraints/w1_board.xdc`: reviewed package pins for `xc7s75fgga484-1`; physical connector/analog checks are still required.
- `tools/`: repeatable Icarus regression and Vivado non-project build.

## Run

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/run_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/run_vivado.ps1
```

Simulation outputs go to `project_evidence/fpga/W1/sim/`; generated executables, Vivado reports/checkpoints and bitstream go under ignored `FPGA/build/`. See the evidence folder for actual results and physical-board limitations.

## W2 additions

- `src/iir_notch_variable.sv`, `audio_path_w2.sv`: runtime signed-Q2.14 Notch, fractional recursive state, atomic sample-boundary coefficient application and BYPASS/FIXED/AUTO selection.
- `src/spi_mode0_slave_w2.sv`: v8 `SET_COEFF`, `READ_STATE` and preserved `READ_BLOCK` semantics.
- `src/calendar_clock.sv`, `stopwatch.sv`, `input_conditioner.sv`: seven-field Gregorian clock and debounced elapsed-time controls.
- `src/lcd_status_display.sv`: 16x2 LCD DSP/clock/stopwatch pages.
- `src/w2_board_top.sv`, `constraints/w2_board.xdc`: separate W2 board integration; W1 top/XDC remain preserved.
- `sim/tb_stm32_fpga_cross.sv`, `tools/cross_integration/`: replay frames serialized by the actual STM32 C implementation into the FPGA RTL and render cross-integration evidence.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/run_w2_sim.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/notch_reference.ps1 -Output project_evidence/fpga/W2/pre/dsp/notch_reference.csv
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/run_w2_vivado.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File FPGA/tools/cross_integration/run_cross_integration.ps1
```

W2 PRE evidence is under `project_evidence/fpga/W2/pre/`. The final Windows CMD Vivado run completed synthesis, implementation and bitstream generation; see `pre/vivado/VIVADO_STATUS.md` for results, retained exit-42 history and unresolved board-timing limits. The confirmed STM32 target is NUCLEO-G474RE. Cross-integration PRE evidence uses a PC host build of the STM32 C source and does not replace the physical-board POST test.
