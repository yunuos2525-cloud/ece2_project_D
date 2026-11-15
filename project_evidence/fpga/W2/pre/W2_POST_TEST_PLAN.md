# FPGA W2 POST laboratory plan

| 우선 | 시험 | 장비·연결 | 입력 | 예상/관찰 | 실패 시 분리할 가설 |
|---:|---|---|---|---|---|
| 1 | BYPASS 50% 진폭 원인 | 함수발생기, 2ch 오실로스코프, ADC IN1/DAC A, 공통 GND | 500 Hz, 기존 3.20 Vpp/offset 조건부터 | 디지털 보정 없이 ADC 입력·DAC 출력 Vpp/mean 동시 기록 | ADC RANGE/CODING, SPI bit 정렬, DAC Vref, 출력 부하, probe 설정 |
| 2 | FIXED 명령 | NUCLEO-G474RE+FPGA, logic analyzer/oscilloscope | CS low에서 `0x02` | MOSI byte와 `led_out` mode indication, DAC 변화 | STM32 AF/GPIO, CPOL/CPHA, CS 길이, FPGA pin |
| 3 | MISO 물리 경로 | G474RE PA6/D12↔BDIO03/G8, J10/BD_SEL1, common GND | A5/5A 1 byte→16 byte | rising-edge sampling 값 반복 일치 | J10 위치, bus switch, contention, 3.3 V, PA6 AF |
| 4 | READ_BLOCK | STM32 SPI ≤500 kHz 시작 | `0x10` + 516 dummy bytes | status, ID, 512 samples, CRC 일치; 다음 ID 증가 | MISO timing, buffer consume, CRC 범위, SPI 속도 |
| 5 | FIXED 주파수 | 함수발생기/오실로스코프 FFT | 500 Hz 및 1 kHz 동일 amplitude | 500 Hz 통과, 1 kHz ≥10 dB 목표 | ADC/DAC headroom, Q2.14, analog bandwidth |
| 6 | AUTO 계수 | STM32 SET_COEFF/READ_STATE | 930/1370/1830/2460 Hz 계수 | seq 일치 후 `0x06`, 목표 tone 감소 | endian/sign/CRC, sample-boundary 적용, filter state 튐 |
| 7 | LCD/시계/SW | FPGA board LCD, N8/N4, W4/T1/Y1 | 각 화면과 버튼 조작 | 7개 달력 항목, START/STOP/RESET, 화면 독립 | 버튼 극성/debounce, LCD 배선/timing, switch mapping |
| 8 | 음성 조건 | 오디오 소스, 필요 시 bias/attenuator | ADC 허용 범위 내 bias된 음성+tone | clipping 없이 BYPASS/AUTO 비교 | AC coupling, bias, Vpp/offset, source impedance |

각 시험은 입력 설정 사진/값, CH1 ADC와 CH2 DAC 파형, SPI logic trace, 실행 bitstream hash를 함께 기록한다. PRE 시뮬레이션 수치를 보드 실측값으로 복사하지 않는다.
