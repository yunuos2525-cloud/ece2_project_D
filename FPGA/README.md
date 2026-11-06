# FPGA W1 implementation

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
