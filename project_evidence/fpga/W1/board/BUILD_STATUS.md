# W1 board build status

Current status on 2026-11-06: **RESET FIX REBUILD PASS / NEW BITSTREAM GENERATED**.

This is a digital build result only. FPGA programming, ADC/DAC analog measurements, STM32 SPI wiring and physical-board verification remain **PENDING**.

## Reset-fix rebuild

- Actual command: `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -nolog -nojournal -source <REPO_ROOT>\FPGA\tools\build_vivado.tcl`
- Exit code: 0; Vivado 2026.1 build 6511674 acquired the valid BASIC synthesis and implementation licenses.
- Synthesis: PASS, 0 errors and 0 critical warnings. The two existing constant-output warnings for `dac_csn` and `dac_ldacn` remain.
- Implementation: `opt_design`, `place_design`, `phys_opt_design`, and `route_design` PASS; 0 failed or unrouted nets.
- Timing: WNS `+5.744 ns`, TNS `0.000 ns`, WHS `+0.096 ns`, THS `0.000 ns`, WPWS `+9.500 ns` at 50 MHz.
- `check_timing`: `no_clock=0`, `unconstrained_internal_endpoints=0`. Eight input ports remain covered by asynchronous false paths and 21 outputs have no output delay; external ADC/DAC/SPI timing is not signed off.
- CDC: reset-related `CDC-1 8688` and `CDC-13 4` changed to one informational `CDC-9` three-stage reset synchronizer. Three SPI synchronizer chains are informational `CDC-3`. Eleven critical `CDC-1` paths remain on `adc_dout` and `adc_channel[2:0]`; these are an unresolved ADC interface/timing risk, not a reset path.
- DRC: 0 errors. The existing `CFGBVS-1` warning (1) and DSP `DPIP-1` recommendations (4) remain. No board voltage was guessed.
- New bitstream: `FPGA/build/w1/w1_board_top.bit`
- Frozen copy: `FPGA/build/w1_reset_fix_20261106/w1_board_top.bit` (same size and SHA-256).
- Size: 3,687,015 bytes.
- SHA-256: `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`
- Build log: `project_evidence/fpga/W1/sim/vivado_build_reset_fix.log`.
- New reports: `project_evidence/fpga/W1/board/vivado/reset_fix_20261106/`.
- Pre-fix bitstream preserved at `FPGA/build/w1_pre_reset_fix/w1_board_top.bit`, SHA-256 `3313F117CE1728117086C7FD51E686AD42E086A502F0879E23C444EEA63ADA1E`.

Program Device was not run. ADC/DAC, reset pin, and physical SPI/MISO measurements were not performed. `BDIO03/G8`, `BD_SEL1`, J10 routing, voltage compatibility, `CFGBVS`, and `CONFIG_VOLTAGE` must be confirmed from the exact board hardware before BOARD PASS.

## Preserved earlier successful retry

The following section records the pre-reset-fix build and is retained for history.

- Vivado executable: `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`
- Vivado version: 2026.1, build 6511674.
- License observed by the new process: valid Vivado Design Suite BASIC, active through 2027-09-12.
- `XILINXD_LICENSE_FILE`: unset at Process/User/Machine scope.
- `LM_LICENSE_FILE`: unset at Process/User/Machine scope.
- Standard search directory `%USERPROFILE%\.Xilinx` exists; no root-level license file was found. `%APPDATA%\Xilinx\license` does not exist. No license file content was read or recorded.
- Tcl: `FPGA/tools/build_vivado.tcl`
- Actual command:

```text
C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat -mode batch -nolog -nojournal -source <REPO_ROOT>\FPGA\tools\build_vivado.tcl
```

- Exit code: 0.
- Synthesis: PASS, 0 errors, 0 critical warnings, 2 warnings (`dac_csn` and `dac_ldacn` are intentionally constant low in the current DAC interface).
- Implementation: `opt_design`, `place_design`, `phys_opt_design` and `route_design` PASS; final route has 0 failed/unrouted nets.
- Timing signoff: PASS. WNS `+5.878 ns`, TNS `0.000 ns`, WHS `+0.062 ns`, THS `0.000 ns`, WPWS `+9.500 ns`. All user-specified timing constraints are met.
- DRC: 0 errors. Five warnings: one `CFGBVS-1` (configuration-bank voltage properties not documented) and four `DPIP-1` DSP input-pipelining recommendations.
- Pin constraints: all 33 user I/O rows are `FIXED` and `LVCMOS33`; no `UCIO-1` or `NSTD-1` violation is present.
- Bitstream: `FPGA/build/w1/w1_board_top.bit`
- Bitstream size: 3,687,015 bytes.
- SHA-256: `3313F117CE1728117086C7FD51E686AD42E086A502F0879E23C444EEA63ADA1E`
- Retry log: `project_evidence/fpga/W1/sim/vivado_build_retry.log`.
- Preserved signoff reports: `project_evidence/fpga/W1/board/vivado/`.

`CFGBVS` and `CONFIG_VOLTAGE` were not guessed. They must be confirmed from the exact board revision/configuration circuit before adding those properties. The positive timing result does not waive the physical J10/BD_SEL1, common-ground, 3.3 V, ADC/DAC reference and contention checks.

## Preserved initial failed attempt

Earlier on 2026-11-06, the first Vivado launcher attempt exited with code 42 before reading the design and reported that no valid license was found. Its original log remains at `project_evidence/fpga/W1/sim/vivado_build.log`; it was not overwritten. That attempt was a launcher/license-access failure, not a synthesis failure.

After the License Manager state was corrected, a fresh `-version` process started Vivado 2026.1 successfully (`vivado_minimal_retry.log`), and the full retry explicitly detected the BASIC license before synthesis. No ERROR or FATAL line occurs in the successful retry log.

## Physical-board gate

Do not mark W1 BOARD complete from this bitstream. Program Device has not been run, and no ADC/DAC waveform or physical SPI/MISO transfer has been measured. Continue with `BOARD_CHECKLIST.md` before connecting or programming the school board.
