# FPGA W2 PRE evidence checklist

기준일: 2026-11-15 (Asia/Seoul). `PASS`는 보존된 로그·VCD·보고서 또는 산출물로 결과를 확인한 항목에만 사용한다. 보드 프로그램, 아날로그 측정, STM32–FPGA 물리 통신 및 실제 LCD 표시는 수행하지 않았다. STM32 실제 C 소스의 PC host 실행 결과를 FPGA RTL에 재생한 교차 시뮬레이션은 별도 PRE 증빙으로 보존한다. 자동 생성 PNG는 실제 VCD를 렌더링한 그림이며 VaporView 스크린샷으로 취급하지 않는다.

| ID | 검증 기능 | 실제 관찰 결과 | 판정 | 보존 증빙 | 남은 문제 |
|---|---|---|---|---|---|
| DSP-01 | BYPASS/FIXED/AUTO 선택 | 모든 패턴 일치, seq `0x55` 원자 적용, FIXED valid 유지 | PASS | `dsp/audio_path_w2.log`, `dsp/tb_audio_path_w2.vcd`, `dsp/captures/W2_DSP_mode_and_atomic_apply.png` | 실물 진폭·FIXED 감쇠는 POST |
| DSP-02 | 930 Hz AUTO Notch | 목표 −54.771 dB, 500 Hz −0.222 dB | PASS | `dsp/iir_notch_variable.log`, `dsp/tb_iir_notch_variable.vcd`, `dsp/captures/W2_DSP_930Hz_apply_and_attenuation.png` | 아날로그 결과 아님 |
| DSP-03 | 1,370 Hz AUTO Notch | 목표 −58.867 dB, 500 Hz −0.030 dB | PASS | 동일 로그·VCD | 별도 PNG 없음; 로그/VCD로 검증 |
| DSP-04 | 1,830 Hz AUTO Notch | 목표 −64.815 dB, 500 Hz +0.016 dB | PASS | 동일 로그·VCD | 별도 PNG 없음; 로그/VCD로 검증 |
| DSP-05 | 2,460 Hz AUTO Notch | 목표 −61.937 dB, 500 Hz +0.012 dB | PASS | 동일 로그·VCD | 별도 PNG 없음; 로그/VCD로 검증 |
| DSP-06 | 원자적 계수·포화 | sample edge 전 미적용, 이후 seq 일치; `0xFF`/`0x00` 포화 | PASS | DSP 로그·VCD·두 PNG | 계수 변경 순간 실물 출력은 POST |
| SPI-01 | SET_COEFF | 13 byte, endian/sign/CRC 승인 일치 | PASS | `spi/spi_w2.log`, `spi/tb_spi_w2.vcd`, `spi/captures/W2_SPI_set_coeff_and_read_state.png` | 물리 MISO는 POST |
| SPI-02 | CRC 오류·중단 거부 | update count가 1에서 증가하지 않음 | PASS | 동일 로그·VCD | 별도 상세 PNG 없음 |
| SPI-03 | READ_STATE/Mode-0 | `06 A5 01`, 다음 byte MSB가 sampling edge 전에 유효 | PASS | 동일 로그·VCD, `spi/captures/W2_SPI_read_state_response.png` | 실제 STM32 sampling은 POST |
| SPI-04 | READ_BLOCK | 512 sample/ID/CRC 일치, 완료 후 consume | PASS | 동일 로그·VCD | 실제 전송은 POST |
| SW-01 | 스톱워치 | bounce one-pulse, 정지·재개·reset, 00:59.9→01:00.0 | PASS | `stopwatch/stopwatch.log`, VCD, PNG 2개 | N8/N4 실제 극성은 POST |
| CLK-01 | 달력 시계 | 30/31일, 평년/윤년, 2100/2400, 연말, 요일 경계 일치 | PASS | `clock/calendar_clock.log`, VCD, `clock/captures/W2_calendar_boundaries.png` | 전원 차단 유지 기능 없음 |
| LCD-01 | 초기화·3화면 | `38,38,38,0C,06,01`; DSP/시계/스톱워치 문자 검사 일치 | PASS | `lcd/lcd_status_display.log`, VCD, PNG 3개 | 실제 LCD 표시는 POST |
| INT-01 | 통합 동작 | input/output valid 300/300, seq `0x31`, AUTO, LCD/clock/SW 진행 | PASS | `integration/w2_integration.log`, VCD, PNG 2개 | PNG만으로 300개 전체 연속성을 주장하지 않음; 판정은 TB 로그 기준 |
| XINT-01 | STM32 C–FPGA SPI 교차시험 | 커밋 `91a1a077...`의 실제 `fpga_link.c`가 생성한 FIXED/READ_STATE/BYPASS/AUTO/READ_BLOCK/SET_COEFF 프레임을 500 kHz Mode-0으로 재생; 8개 시험 PASS | PASS | `cross_integration/cross_integration.log`, `stm32_frame_generation.log`, `cross_spi_bytes.log`, VCD, PNG 3개 | PC 가상 SPI callback 기반이며 실제 NUCLEO-G474RE 물리 파형은 POST |
| XINT-02 | STM32 `r=0.98` 계수 | C 생성 Q2.14 계수 `16384,-30274,16384,-29668,15735`; FPGA RTL에서 1 kHz −50.782 dB, 500 Hz +0.143 dB | PASS | `cross_integration/cross_integration.log`, `captures/W2_STM32_notch_r098_response.png` | 디지털 RTL 결과이며 아날로그 진폭·감쇠는 POST |
| REG-01 | W1 회귀 | 기존 8개 시험 8/8 PASS | PASS | `integration/w1_regression.log` | 기존 W1 실물 미해결 사항 유지 |
| VIV-01 | 합성·배치배선·Bitstream | Synthesized, Fully Routed, Bitstream 생성 | PASS | `vivado/*.rpt`, `FPGA/build/w2/post_*.dcp`, `FPGA/build/w2/w2_board_top.bit` | 성공 stdout/stderr 미수집; exit 0은 사용자 확인 결과 |
| VIV-02 | post-route Timing | WNS `+2.681 ns`, TNS `0.000 ns`, WHS `+0.043 ns`, failing endpoint 0 | PASS(지정 제약) | `vivado/post_route_timing.rpt`, `vivado/post_route_check_timing.rpt` | 출력 31개 output delay 미지정으로 외부 I/O timing sign-off 아님 |
| VIV-03 | DRC | Error/Critical Warning 0, Warning 11 (`CFGBVS-1` 1, `DPIP-1` 10) | PASS(차단 오류 0) | `vivado/post_route_drc.rpt` | warning-free DRC가 아님; CFGBVS/CONFIG_VOLTAGE 미확인 |
| CDC-01 | 비동기 입력/CDC | UI·SPI 8개 CDC-3 Info, reset CDC-9 Info; ADC 관련 CDC-1 Critical 11개 | 제한 운용 | `vivado/post_route_cdc.rpt`, `vivado/DRC_TIMING_REVIEW.md` | W2 PRE는 `adc_channel[2:0]`을 reset 해제 전에 설정하고 측정 중 변경하지 않음; 외부 timing·CDC sign-off는 미완료 |

## PRE 판정

- 완료: W2 기능 시뮬레이션 7개, W1 회귀 8개, STM32 실제 C–FPGA 교차 시뮬레이션 8개, 파형 PNG 16개, Vivado 합성·배치배선·지정 Timing·Bitstream 생성.
- 제한 포함 완료: DRC 차단 오류는 0이지만 Warning 11개가 남아 있다.
- STM32 대상: 실제 통합 대상은 `NUCLEO-G474RE`로 확정했다. 공통 v8 문서의 H533RE 전용 보드명·커넥터 근거는 팀 합의 후 정정할 항목이며 프로토콜과 PA6/PB3/PA7/PB6 신호 배정은 이번 반영에서 변경하지 않았다.
- 운용 조건: ADC 채널은 reset 해제 전에 보드 스위치로 설정하고 측정 중 변경하지 않는다. 이 조건은 runtime 다중 비트 CDC 위험을 회피하기 위한 것이며 CDC closure를 의미하지 않는다.
- 미완료: 실물 Program Device, 외부 I/O timing, ADC CDC/입력 지연, configuration-bank 전압, 물리 SPI/LCD/UI/아날로그 시험.
- 무결성 목록: 전체 PRE는 `W2_PRE_HASHES.sha256`, 교차시험 내부는 `cross_integration/CROSS_INTEGRATION_HASHES.sha256`; Vivado 상세: `vivado/VIVADO_STATUS.md`, `vivado/BUILD_PROVENANCE.md`, `vivado/DRC_TIMING_REVIEW.md`.

