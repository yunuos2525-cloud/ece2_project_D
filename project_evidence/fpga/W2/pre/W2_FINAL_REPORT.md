# FPGA W2 PRE final report

## A. 기준 상태

- Branch: `feat/fpga`. 최종 반영 전 baseline HEAD와 `origin/feat/fpga`는 모두 `8e2d68c87071d7a079ca9b4213870f01b125cb1f`였다.
- W1 baseline 회귀 8/8 PASS. W1 RTL·증빙·Bitstream을 덮어쓰지 않았다.
- W2 기능 시뮬레이션 7개 PASS, 관련 로그·VCD·PNG 보존.
- STM32 실제 C 소스 커밋 `91a1a077fabd8a4c83a0ea8f5b9237c45b87b70b`과 FPGA W2의 SPI 교차 시뮬레이션 8개 PASS. 이는 PC host 실행이며 물리 보드 캡처가 아니다.
- 실제 STM32 통합 대상 보드는 `NUCLEO-G474RE`로 확정했다.
- Windows CMD Vivado 실행 exit code 0은 사용자 확인 결과이며 성공 stdout/stderr는 수집되지 않았다.
- W2 PRE의 ADC 채널은 reset 해제 전에 설정하고 측정 중 변경하지 않는 단일 채널 고정 운용을 전제로 한다. 이는 외부 timing·CDC sign-off를 대체하지 않는다.

## B. PRE 구현 상태

| 기능 | 상태 | 근거/제한 |
|---|---|---|
| 가변 IIR, Q2.14, 원자 적용 | 완료 | 4주파수/500 Hz/포화 PASS |
| READ_BLOCK, SET_COEFF, READ_STATE | 완료 | 길이/endian/sign/CRC/Mode-0/512 sample PASS |
| BYPASS/FIXED/AUTO | 완료 | bit-exact/fallback/계수 적용/W1 fixed 회귀 PASS |
| 스톱워치·달력 시계·LCD | PRE 완료 | 논리/VCD PASS; 실제 버튼 극성·LCD 표시는 POST |
| 통합 | PRE 완료 | TB 로그에서 audio valid 300/300, seq `0x31`, AUTO/LCD/시간 동작 PASS |
| STM32 교차 통합 | PRE 완료 | 실제 C 직렬화 프레임으로 FIXED/READ_STATE/BYPASS/AUTO/READ_BLOCK/SET_COEFF PASS; 1 kHz −50.782 dB, 500 Hz +0.143 dB |
| Vivado 합성·배치배선 | 완료 | Synthesized / Fully Routed 보고서와 DCP 확인 |
| Timing | 지정 제약 PASS | WNS `+2.681 ns`, TNS `0.000 ns`, WHS `+0.043 ns`; output delay 31개 미지정 |
| DRC | 차단 오류 0 | Warning 11: `CFGBVS-1` 1, `DPIP-1` 10 |
| Bitstream | 완료 | SHA-256 `85320DFBA2DD5858B24CE0D0F6F03AB26E8FF2CDE5AB4B52A988E7A82645922D` |
| CDC | 일부 미확인 | UI/SPI/reset synchronizer 확인; ADC 관련 CDC-1 Critical 11개 |

## C. Vivado 산출물

- Top/part: `w2_board_top` / `xc7s75fgga484-1`.
- Bitstream: `FPGA/build/w2/w2_board_top.bit`, 3,687,015 bytes, 2026-11-14 22:04:28.862 KST.
- 상세 provenance: `vivado/BUILD_PROVENANCE.md`.
- DRC/Timing/CDC 해석: `vivado/DRC_TIMING_REVIEW.md`.
- 이전 Codex exit 42 원문은 `vivado/vivado_w2_exact_w1_env.log`에 보존했으며 최종 성공과 구분한다.

## D. PRE 증빙

기능별 로그·VCD·기준 CSV와 기존 PNG 12개, 교차시험 PNG 4개가 실제로 존재한다. PNG는 원본 VCD 데이터를 자동 렌더링한 것으로 VaporView 스크린샷이라고 표기하지 않는다. 통합 300/300 판정과 DSP 수치 판정은 PNG가 아니라 TB 로그를 기준으로 한다. 교차시험의 전체 TX/RX 바이트, C 프레임 생성 provenance와 별도 manifest는 `cross_integration/`에 있다.

전체 파일 해시는 `W2_PRE_HASHES.sha256`, 상세 항목별 판정은 `W2_PRE_EVIDENCE_CHECKLIST.md`에 있다.

## E. 최종 판정과 미완료 범위

W2 PRE의 RTL 기능 검증과 Vivado 구현·Bitstream 생성은 완료됐다. 그러나 이는 BOARD PASS가 아니다. 다음 항목은 보드 프로그램 전에 확인해야 한다.

1. exact board revision의 `CFGBVS`/`CONFIG_VOLTAGE` 및 실제 VCCO.
2. ADC `adc_dout` input delay와 `adc_channel[*]` 안정/동기화 조건.
3. ADC/DAC/LCD/SPI의 외부 I/O timing과 board delay.
4. NUCLEO-G474RE PA6/D12 ↔ G8/BD_SEL1/J10 MISO route, 전압, contention 및 공통 GND.
5. N8/N4 버튼 극성, LCD module 전압·가독성, 실제 Program Device.
6. BYPASS/FIXED/AUTO 아날로그 진폭·감쇠 및 STM32 물리 통신.

공통 `docs/TEAM_SPI_INTERFACE_v8_final.md`는 아직 NUCLEO-H533RE의 커넥터 번호와 H5 보드 문서를 근거로 적고 있다. 실제 대상 G474RE와의 차이는 `STM32_BOARD_ALIGNMENT.md`에 기록했으며, 팀 합의 없이 공통 규격의 핀 배정이나 프로토콜을 변경하지 않았다.

보드 시험에서는 원하는 `adc_channel[2:0]` 값을 reset 해제 전에 설정하고 측정이 끝날 때까지 유지한다. runtime 채널 변경은 현재 W2 필수 범위가 아니며, 향후 지원하려면 다중 비트 원자 동기화와 ADC 응답 channel-ID 검증이 필요하다.

