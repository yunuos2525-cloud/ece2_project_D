# W2 DRC and timing constraint review

## 판정 요약

- 내부 구현 Timing: PASS. WNS `+2.681 ns`, TNS `0.000 ns`, WHS `+0.043 ns`, failing endpoint 0.
- DRC: 차단 오류 0, Warning 11. warning-free DRC는 아니다.
- CDC: UI/SPI/reset synchronizer는 확인됐지만 ADC 관련 CDC-1 Critical 11개가 남아 있어 clean CDC가 아니다.
- 외부 I/O Timing: output delay가 없어 미검증이다.

W2 PRE의 운용 결정은 `adc_channel[2:0]`을 reset 해제 전에 설정하고 측정 중 변경하지 않는 단일 채널 고정 방식이다. 이 제한은 runtime 다중 비트 변경 위험을 회피하지만, `adc_dout` 외부 timing이나 CDC 보고서를 clean 상태로 바꾸지는 않는다.

## CFGBVS-1

W2 XDC와 확인한 로컬 COMBO II-DLD LAB XDC는 모든 I/O를 `LVCMOS33`으로 지정하지만 `CFGBVS`와 `CONFIG_VOLTAGE`는 지정하지 않는다. 로컬 보드 조사 문서도 configuration-bank 전압이 inspected source에서 문서화되지 않았다고 기록한다. `LVCMOS33`은 I/O standard 설정이며 configuration bank의 실제 전압을 증명하지 않는다.

따라서 현재 자료로 올바른 `CFGBVS`/`CONFIG_VOLTAGE` 값을 확정할 수 없다. 보드 revision의 schematic/manual 또는 실측 없이 값을 추정하거나 경고를 억제하면 안 된다.

## DPIP-1

10건은 DSP48 입력 파이프라이닝을 권고하는 성능 warning이다. 현재 50 MHz 제약에서 post-route WNS가 양수이고 failing endpoint가 없으므로 PRE Bitstream 생성을 위해 즉시 RTL을 변경할 근거는 없다. 더 높은 clock, 추가 logic, 전력·지연 최적화 또는 timing margin 요구가 생기면 파이프라이닝을 재검토한다.

## 출력 31개 output delay 미지정

`adc_din`, `adc_ncs`, `adc_sclk`, `dac_d[7:0]`, `dac_wen`, `lcd_data[7:0]`, `lcd_e`, `lcd_rs`, `led_out[7:0]`, `spi_miso`에 output delay가 없다. 따라서 보고된 WNS/TNS는 내부 사용자 제약을 충족한다는 의미이며 외부 ADC/DAC/LCD/STM32의 setup/hold 또는 board delay를 보증하지 않는다.

외부 timing sign-off에는 각 장치 datasheet, board trace/level-shifter 정보, 실제 interface clock 관계를 확인한 뒤 `set_output_delay` 또는 적절한 interface-specific constraint가 필요하다. LCD/LED처럼 시스템적으로 느린 출력도 전기적·기능적 보드 검증은 별도다.

## 입력 false-path와 CDC

`check_timing`의 13개 입력 false-path는 다음과 같이 분류된다.

- `rst_p`: 3-stage `ASYNC_REG` reset conditioner로 asynchronous assert/synchronous release. 첫 conditioner stage까지의 false-path와 구조가 일치한다.
- `spi_sck`, `spi_mosi`, `spi_cs_n`: 각각 3-stage `ASYNC_REG` synchronizer의 첫 stage까지만 false-path다. 50 MHz oversampling 구조와 일치하지만 허용 가능한 외부 SPI SCK 주파수와 실제 Mode-0 sampling margin은 보드에서 확인해야 한다.
- `sw_start_btn`, `sw_stop_btn`, `sw_reset_switch`, `display_mode[1:0]`: 2-stage `ASYNC_REG` 뒤 debounce/level logic을 사용하며 첫 stage까지만 false-path다. 구조적으로 타당하다.
- `adc_channel[2:0]`, `adc_dout`: port에서 모든 destination으로 포괄 false-path다. `report_cdc`는 이 그룹에서 CDC-1 Critical 11개를 보고한다. `adc_channel`은 직접 command 조합 논리에 들어가며 synchronizer가 없다. `adc_dout`은 FPGA가 만든 `adc_sclk`에 대응하는 외부 반환 데이터지만 input delay가 없다. 데이터시트와 보드 지연을 확인하지 않은 상태에서는 이 false-path의 타당성을 완전히 승인할 수 없다.

결론적으로 UI/SPI/reset의 9개 CDC 항목은 ASYNC_REG 구조가 보고서에서 확인된다. ADC 관련 11개 Critical은 W1에서 이어진 미검증 사항이며, 보드 프로그램 전에 ADC timing/채널 안정 조건을 확인해야 한다.

