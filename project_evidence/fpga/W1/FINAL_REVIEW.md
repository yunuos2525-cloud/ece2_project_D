# FPGA W1 final technical review

## Reset correction final update — 2026-11-06

| Area | Classification | Result and evidence |
|---|---|---|
| Reset architecture | **PASS** | Added a three-stage `ASYNC_REG`/`SHREG_EXTRACT=NO` conditioner. Assertion is asynchronous; release is synchronous to `clk_50mhz`. Raw `rst_p` now reaches only the conditioner, and every downstream W1 module receives `rst_50mhz`. |
| Reset functional regression | **PASS** | New integration test covers between-edge release, active-sample reset, mid-SPI reset, stale-state rejection, and clean BYPASS/Notch/buffer/SPI restart. Eight total automated tests PASS with logs and VCDs. |
| Reset CDC | **PASS** | Previous reset-driven `CDC-1 8688` and `CDC-13 4` are gone. Vivado recognizes one depth-3 informational `CDC-9` asynchronous-reset synchronizer. |
| SPI synchronizers | **PASS / 확인 필요** | Existing SCK/MOSI/CS three-stage chains are unchanged and reported as three depth-3 `CDC-3` chains. False paths terminate only at stage 0. Physical SCK/MOSI/CS/MISO timing is still unmeasured. |
| ADC CDC and I/O timing | **확인 필요** | Eleven `CDC-1` paths remain: eight `adc_dout` captures and three `adc_channel` command bits. ADC inputs remain false-pathed because verified device/board delays are unavailable. Twenty-one outputs have no output delay. This is not hidden as reset PASS and blocks full external timing signoff. |
| 50 MHz internal timing | **PASS** | WNS +5.744 ns, TNS 0, WHS +0.096 ns, THS 0; `no_clock=0`, `unconstrained_internal_endpoints=0`, unconstrained path table empty. |
| Notch measurement | **PASS** | Corrected actual-quantized-input gains: A40 500 Hz -0.862 dB; A35 500 Hz -0.331 dB; mixed A35+A35: 500 Hz -0.210 dB, 1 kHz -27.277 dB. Original nominal-denominator results remain preserved. |
| Vivado/bitstream | **PASS** | Synthesis, implementation, route and bitstream completed in Vivado 2026.1. New SHA-256 is `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`. |
| DRC/board voltage | **확인 필요** | 0 DRC errors; `CFGBVS-1` (1) and `DPIP-1` (4) remain. No CFGBVS/configuration voltage was inferred. |
| Physical board use | **확인 필요** | Program Device and ADC/DAC/SPI measurements were not performed. BDIO03/G8, BD_SEL1/J10 routing, voltage compatibility, analog connectors/reference, and common ground remain hardware gates. |

There is no remaining **수정 필요** item in the reset correction scope. The
remaining items are **확인 필요** because their correct constraints or RTL
handling depend on missing board/device timing facts.

### Implemented correction

- `reset_conditioner.sv`: three flip-flops initialized asserted by the external active-high asynchronous input; zeros shift through on three 50 MHz rising edges before reset release. `ASYNC_REG=TRUE` and `SHREG_EXTRACT=NO` prevent inappropriate SRL extraction.
- `w1_board_top.sv`: all downstream resets and `adc_drop_sticky` use only `rst_50mhz`; there is no other RTL clock domain.
- `w1_board.xdc`: reset exception is limited to the conditioner's asynchronous controls, and each SPI exception is limited to the first synchronizer stage. The ADC exception is separately retained and explicitly classified unverified rather than treated as timing signoff.
- `tb_reset_recovery.sv` and `run_sim.ps1`: reset-specific integration regression added without changing W1 functional requirements.
- `tb_iir_notch_fixed.sv`: only the measurement denominator and A35 standalone reporting were corrected; coefficients, signals, window, and acceptance thresholds were not weakened.
- `build_vivado.tcl`: post-route `check_timing`, `report_cdc`, unconstrained timing, and exception reports are generated with every rebuild.

### Before/after evidence

- Pre-fix bitstream: 3,687,015 bytes, SHA-256 `3313F117CE1728117086C7FD51E686AD42E086A502F0879E23C444EEA63ADA1E`.
- Post-fix bitstream: 3,687,015 bytes, SHA-256 `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`.
- Frozen post-fix artifact: `FPGA/build/w1_reset_fix_20261106/w1_board_top.bit`; current build output and frozen copy have identical hashes.
- Pre-fix timing: WNS +5.878 ns / WHS +0.062 ns. Post-fix: WNS +5.744 ns / WHS +0.096 ns. Both have TNS/THS 0.
- Pre-fix artifacts and hashes: `reset_fix/pre/`; post-fix hashes: `reset_fix/post/post_state_hashes.sha256`.
- Regression comparison: `sim/RESET_FIX_REGRESSION.md`; frozen post-fix logs/VCDs: `sim/reset_fix_20261106/`; new Vivado reports: `board/vivado/reset_fix_20261106/`.

### Final disposition

The reset defect is corrected and the Bitstream was necessarily regenerated. No further RTL modification is required for the reset scope. The new image is a valid digital build candidate, but it is **not yet a board-validated release**: ADC CDC/timing, all external output timing, G8/BD_SEL1/J10 routing, configuration voltage, and physical Program Device/measurement remain open.

The residual ADC `CDC-1` paths are not waived as harmless. `adc_dout` enters
eight serial receive-register data pins without a verified input-delay model,
and the three external channel-select inputs enter command latch bits directly.
If they change near a 50 MHz capture edge, metastability or a wrong command/data
bit is possible. Closure requires the exact ADC clock-to-out/setup/hold and
board delay plus a documented channel-input stability rule (or an appropriate
RTL capture/synchronization change); a broader false-path exception would only
hide the risk.

---

## Preserved pre-fix review

Review date: 2026-11-06 (Asia/Seoul)
Branch: `feat/fpga`
Scope: review only; no RTL/TB/XDC feature change, no original log/VCD/bitstream overwrite, no commit/push.

## Executive disposition

| Area | Disposition | Basis |
|---|---|---|
| Seven W1 simulations and fixed-notch threshold | **PASS with measurement note** | Original seven PASS logs remain intact. Both 500 Hz cases meet the <=1 dB W1 threshold, but the reported dB values use nominal rather than quantized-input amplitude. |
| 50 MHz internal timing | **PASS** | One 20.000 ns clock; WNS +5.878 ns, TNS 0, WHS +0.062 ns, THS 0; `no_clock=0`, `unconstrained_internal_endpoints=0`. |
| SPI/ADC external timing signoff | **CONFIRMATION REQUIRED** | Eight inputs are blanket false-pathed with no input delay; 21 outputs have no output delay. Internal timing PASS does not cover physical SPI or ADC/DAC interface timing. |
| SPI CDC structure | **PASS with physical limit** | SCK/MOSI/CS each have a three-register `ASYNC_REG` chain (9 cells total). Independent sampling still requires slow SCK and adequate MOSI/CS stability; no physical timing proof exists. |
| Reset release | **MODIFICATION REQUIRED** | Raw asynchronous `rst_p` directly drives reset/set controls across the design and is blanket false-pathed. `report_cdc` reports 8,688 `CDC-1` and four `CDC-13` paths dominated by this reset. |
| Board package-pin mapping | **PASS / CONFIRMATION REQUIRED split** | Clock, reset, ADC and DAC package pins are corroborated by prior LAB XDCs. BDIO03/G8 physical identity/path and all analog connector/voltage facts remain unverified. |
| Bitstream build artifact | **PASS locally; archival confirmation required** | Bitstream and reports match the recorded Vivado 2026.1 build. Exact inputs are hashed, but the sources are still uncommitted/untracked. |
| Physical board readiness | **NOT YET APPROVED** | Program Device, voltage/jumper checks, ADC/DAC measurements and physical SPI have not been performed. Reset and physical routing gates remain. |

## 1. Fixed-notch 500 Hz discrepancy

### Original test conditions

- Pure case: 500 Hz nominal amplitude 40.
- Mixed case: 500 Hz nominal amplitude 35 plus 1 kHz nominal amplitude 35.
- Both use `N=4096`, discard samples 0..511, and correlate samples 512..4095 against exact 500 Hz and 1 kHz sin/cos bases.
- The official window has 3,584 samples: exactly 112 cycles at 500 Hz and 224 cycles at 1 kHz. The tones are FFT-bin coherent, so ordinary leakage/window mismatch is not the cause.
- Original dB calculations divide by nominal amplitudes 40 and 35, not by the measured spectrum of the quantized 8-bit input.

### RTL-exact diagnostic

The independent diagnostic in `review/notch_diagnostic.py` duplicates the RTL Q2.14 coefficients, arithmetic right shift, integer `y1/y2` state and saturation. It does not modify the original TB or RTL.

| Case/window | Actual quantized input A500 | Output A500 | Output/input gain | Saturations |
|---|---:|---:|---:|---:|
| Pure A40, official 512..4095 | 39.798794 | 36.040817 | -0.861506 dB | 0 |
| Pure A40, late 2048..4095 | 39.798794 | 36.040817 | -0.861506 dB | 0 |
| Pure A35, official 512..4095 | 34.774371 | 33.473357 | -0.331200 dB | 0 |
| Mixed A35+A35, official 512..4095 | 35.105350 | 34.266899 | -0.209970 dB | 0 |
| Mixed A35+A35, late 2048..4095 | 35.105350 | 34.266899 | -0.209970 dB | 0 |

The official `-0.905 dB` and `-0.184 dB` values are reproduced when the same output amplitudes are divided by the nominal 40 and 35. The small difference between those values and the table above is input-sample quantization.

The quantized-coefficient linear transfer function predicts 500 Hz gain `-0.172422 dB`. The RTL stores `y1/y2` as whole signed samples and uses `acc >>> 14`, which floors the recursive state every sample. This nonlinear, periodic quantization makes gain depend on the exact integer input sequence and amplitude. The added 1 kHz sequence also changes that quantization error (deterministic dither) even though the filter later suppresses it. The mixed case therefore lands near the linear prediction while the pure A40 periodic case does not.

Transient response is not the cause: the official and late-window gains are identical for both reported cases. Neither input nor output saturates; maximum accumulator magnitudes are far below the signed 28-bit range.

Disposition:

- **PASS:** both original results meet the predeclared wanted-signal limit of <=1 dB.
- **MODIFICATION REQUIRED — test evidence only:** future metrics should calculate output/input from the actual quantized input spectrum over the same measurement window. Preserve the original logs and generate a new comparison log rather than replacing them.
- **CONFIRMATION REQUIRED — DSP quality:** if amplitude-independent passband gain is required beyond W1, evaluate wider fractional recursive state and symmetric rounding. That would be an RTL change and require full regression and a new bitstream; it is not performed in this review.

Evidence: `review/notch_diagnostic.log`, original `sim/iir_notch_fixed.log`, `sim/notch_metrics.csv`, and `sim/tb_iir_notch_fixed.vcd`.

## 2. Timing constraints, unconstrained paths, CDC and reset

### Confirmed PASS

- XDC creates only `clk_50mhz` at 20.000 ns. The routed checkpoint contains exactly one clock.
- Post-route timing: WNS +5.878 ns, TNS 0.000 ns, WHS +0.062 ns, THS 0.000 ns, WPWS +9.500 ns.
- `check_timing`: `no_clock=0`, `constant_clock=0`, `unconstrained_internal_endpoints=0`, `multiple_clock=0`, loops=0.
- SPI SCK/MOSI/CS each use a three-stage synchronizer and all nine registers retain `ASYNC_REG=TRUE` after implementation.

### Confirmation required

- The XDC blanket-false-paths `rst_p`, `adc_channel[*]`, `adc_dout`, `spi_sck`, `spi_mosi`, and `spi_cs_n`.
- `check_timing` reports eight input ports with no input delay but a false-path exception, and 21 output ports with no output delay. `spi_miso` is among those outputs.
- `report_cdc` explicitly warns that ports without input-delay constraints are skipped for normal clock-to-clock CDC analysis. The SPI synchronizers reduce metastability risk, but the independent SCK/MOSI/CS sampling does not prove byte coherency at a physical connector.
- The SPI simulation rate and <=500 kHz design intent provide functional evidence only. There is no virtual SCK/input-output delay model, no board-delay allowance and no oscilloscope/logic-analyzer result. MISO setup/hold at the STM32 is therefore not timing-signed-off.
- `adc_dout` and ADC/DAC output timing are also outside the reported +5.878 ns internal WNS.

### Modification required: reset

Every sequential module uses raw `rst_p` directly. Although the RTL tests reset on the 50 MHz edge, the physical pin may assert/deassert asynchronously. The blanket false path hides setup/recovery behavior. Routed `report_cdc` reports 8,688 `CDC-1` reset crossings and four `CDC-13` DSP reset crossings; the three SPI data/control inputs themselves are recognized as `CDC-3` synchronized paths.

Required change scope before final board-candidate approval:

1. Add a top-level 50 MHz reset conditioner (asynchronous assertion if required by the board policy, synchronous deassertion through at least two marked stages).
2. Feed the conditioned reset to all W1 modules instead of raw `rst_p`.
3. Replace the broad reset false path with a narrowly scoped exception to the reset synchronizer's first stage/async controls.
4. Re-run all seven simulations, `report_cdc`, `check_timing`, synthesis, implementation and bitstream generation.
5. Once external interface timing data is known, replace blanket SPI/ADC exceptions with documented CDC exceptions and applicable I/O timing assumptions; do not invent delays.

Evidence: `review/check_timing.rpt`, `review/timing_unconstrained.rpt`, `review/cdc.rpt`, `review/timing_exceptions.rpt`, and `review/timing_review_vivado.log`.

## 3. Board top and XDC cross-check

### Confirmed package-level facts

- Board/device used by prior builds: COMBO II-DLD S75 / `xc7s75fgga484-1`.
- Clock B6 and reset K4 match prior LAB material.
- ADC serial pins H3/H5/J6/H7 match the LAB5 ADC XDC.
- DAC G2/E1/F4/G4 and E3/E5/D2/D5/C2/C4/B1/B3 match the LAB6 DAC XDC.
- SPI BDIO00/F8, BDIO01/E8 and BDIO02/A7 match LAB7 research; Vivado confirms bonded general-purpose pins.
- Current top port names/directions match the XDC, and the routed IO report has all 33 user ports fixed as LVCMOS33 with no UCIO-1/NSTD-1.

### Unconfirmed board-level facts

- Current XDC assigns `spi_miso` to G8. G8 is a valid bonded FPGA pin, and the team v8 interface names it BDIO03, but the independent older local project pin review still labels `BDIO03/G8` as a candidate and intentionally omitted it from its XDC. The physical board manual/silkscreen or continuity measurement must settle this before STM32 wiring.
- J10 position, U19/bus-switch path, `BD_SEL1` state, 3.3 V compatibility and absence of another driver are not verified.
- ADC input terminal/channel, ADC REFIN/AVDD/safe range, DAC output A/B, DAC reference/full scale and common-ground connector are not verified.
- `CFGBVS` and `CONFIG_VOLTAGE` remain unknown. The routed DRC correctly retains `CFGBVS-1`; no property or voltage was guessed.

Disposition: package-level ADC/DAC and BDIO00..02 mapping **PASS**; BDIO03/G8 physical mapping, analog terminals, voltage and switch state **CONFIRMATION REQUIRED**. If G8 is disproved, the XDC and bitstream must change.

## 4. Bitstream identity and reproducibility

- Current bitstream: `FPGA/build/w1/w1_board_top.bit`.
- SHA-256 rechecked during review: `3313F117CE1728117086C7FD51E686AD42E086A502F0879E23C444EEA63ADA1E`.
- Vivado: 2026.1 build 6511674; part `xc7s75fgga484-1`; exact non-project Tcl and successful command are retained in `board/BUILD_STATUS.md` and `sim/vivado_build_retry.log`.
- Post-synth checkpoint SHA-256: `4DEB7CFF4B531111B8F7A7608803C57E214D8A7707BD5119D6691B65C26C6EF0`.
- Post-route checkpoint SHA-256: `121B246C33CE03F9FA92ED261A6E987886F5A84D5DDDCF01DD19B1D965D97B54`.
- Fourteen RTL/XDC/Tcl input hashes are recorded in `review/build_input_hashes.sha256` and match the current workspace files.

The build is locally reconstructable from the current workspace and recorded tool/command. Bit-identical long-term reproduction is **not yet proven** because the W1 sources are uncommitted/untracked and a second isolated build was not performed. Commit/tag or an immutable source archive is required later, but this review does not commit or push.

## 5. Board-use decision

- **Bitstream regeneration required:** yes, before treating the design as the final board/integration candidate, because reset deassertion must be synchronized and the timing/CDC reports must be rerun. A measurement-only correction to the Notch TB does not itself require bitstream regeneration.
- **Physical board test possible now:** preparation and power-off continuity/voltage/jumper inspection are possible. Do not claim BOARD PASS. Do not connect STM32 MISO or analog equipment until BDIO03/J10/BD_SEL1, common ground and voltage compatibility are confirmed.
- The current bitstream may be retained as the reviewed W1 build artifact, but it is not approved as the final hardware-validation image. Program Device and ADC/DAC/SPI measurements remain undone.

No existing artifact was deleted or overwritten during this review.
