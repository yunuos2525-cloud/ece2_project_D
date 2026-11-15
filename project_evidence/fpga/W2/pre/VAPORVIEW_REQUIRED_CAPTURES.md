# W2 waveform PNG status

기존 VCD에서 자동 렌더링한 PNG가 아래와 같이 존재한다. 이 그림들은 VaporView 스크린샷이 아니며, 중복 캡처는 필요하지 않다. 시간축·신호·값은 VCD 원본을 기준으로 검토한다.

| 기능 | VCD | 존재하는 PNG | 검증 범위 |
|---|---|---|---|
| DSP mode/원자 적용 | `dsp/tb_audio_path_w2.vcd` | `dsp/captures/W2_DSP_mode_and_atomic_apply.png` | BYPASS/AUTO fallback, seq `55`, sample-boundary 적용 |
| 930 Hz Notch | `dsp/tb_iir_notch_variable.vcd` | `dsp/captures/W2_DSP_930Hz_apply_and_attenuation.png` | 계수 적용과 정상상태 파형; 수치 판정은 DSP 로그 기준 |
| SPI SET_COEFF/READ_STATE | `spi/tb_spi_w2.vcd` | `spi/captures/W2_SPI_set_coeff_and_read_state.png`, `W2_SPI_read_state_response.png` | Mode-0 edge, CRC/계수 승인, READ_STATE 응답 |
| 스톱워치 | `stopwatch/tb_stopwatch.vcd` | `stopwatch/captures/W2_stopwatch_controls_rollover.png`, `W2_stopwatch_rollover_reset_detail.png` | debounce, start/stop/resume/reset, rollover |
| 달력 시계 | `clock/tb_calendar_clock.vcd` | `clock/captures/W2_calendar_boundaries.png` | 월말·연말·윤년·요일 경계 |
| LCD | `lcd/tb_lcd_status_display.vcd` | `lcd/captures/W2_LCD_init_and_three_modes.png`, `W2_LCD_init_and_dsp_detail.png`, `W2_LCD_clock_stopwatch_detail.png` | 초기화 명령과 세 표시 모드 문자 전환 |
| 통합 | `integration/tb_w2_integration.vcd` | `integration/captures/W2_integration_no_audio_gap.png`, `W2_integration_coeff_apply_detail.png` | SPI 계수 적용, AUTO, LCD/시간, 오디오 valid 구간 |

통합 PNG만으로 300개 샘플 전체의 연속성을 입증하지 않는다. `integration/w2_integration.log`의 300/300 자동 검사 결과가 판정 근거다. 1,370/1,830/2,460 Hz는 별도 PNG가 없지만 기존 VCD와 `dsp/iir_notch_variable.log`에 자동 검사 결과가 있어 추가 중복 캡처는 필수가 아니다.

