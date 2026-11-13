# Project D STM32

NUCLEO-G474RE용 음향 간섭 제어 펌웨어. FPGA의 원본 512샘플을 SPI로 읽어
16 kHz 기준 FFT를 수행하고, 추정한 간섭에 맞춘 Q2.14 계수를 FPGA로 전달한다.
패킷 형식과 실험 배선은 [공통 SPI v8 규격](../docs/TEAM_SPI_INTERFACE_v8_final.md)을 따른다.

| 경로 | 역할 |
| --- | --- |
| `src/audio_dsp.c` | 512점 FFT, 간섭 피크 추정, Notch 계수 계산 |
| `src/fpga_link.c` | SPI 프레임, CRC-8/ATM, 리틀엔디언 인코딩 |
| `src/audio_control.c` | 모드 제어, 블록 검사, 재추적, 계수 적용 확인 |
| `board/main.c` | 보드별 SPI1·CS GPIO·ST-LINK 가상 COM 포트 설정 |
| `tests/audio_test.c` | 생성한 시험 신호 및 모의 FPGA를 이용한 PC 시험 |

## PC에서 시험

저장소 루트에서 CMake 3.24 이상과 PC용 C 컴파일러로 실행한다.

```powershell
cmake -S STM32 -B STM32/build/host
cmake --build STM32/build/host --config Release
ctest --test-dir STM32/build/host -C Release --output-on-failure
```

## Nucleo 펌웨어 빌드

`cmake`, `ninja`, `arm-none-eabi-gcc`를 PATH에 넣고 저장소 루트에서 실행한다.
최초 구성 시 CMake가 선택한 보드의 ST HAL, CMSIS Device, Arm CMSIS Core를 가져온다.

```powershell
cmake -S STM32 -B STM32/build/g474 -G Ninja "-DCMAKE_TOOLCHAIN_FILE=cmake/arm-gcc.cmake" "-DSTM32_BOARD=NUCLEO_G474RE" "-DCMAKE_BUILD_TYPE=Release"
cmake --build STM32/build/g474
```

결과는 `STM32/build/g474/ece2_project_d_g474re.elf`와 `.hex`다.
팀 문서의 H533RE를 사용할 경우 별도의 `STM32/build/h533` 경로를 지정하고
`-DSTM32_BOARD=NUCLEO_H533RE`를 사용한다. H533RE 바이너리의 이름은 `ece2_project_d_h533re`다.

## 보드에서 확인할 항목

- SPI1은 Mode 0, MSB first, 명목 500 kHz다. 패킷과 MCU GPIO 배정은 공통 규격 v8을 따른다.
- G474RE(MB1367)의 점퍼 위치는 `PB3` SCK → `D3`, `PA7` MOSI → `D11`,
  `PA6` MISO → `D12`, `PB6` CS → `D10`이다. `SCK/D13` 표기의 핀은 `PA5`다.
  FPGA 쪽 점퍼 위치와 공통 GND는 공통 규격을 기준으로 대조한다.
- G474RE 기본 ST-LINK 가상 COM은 `LPUART1`(`PA2/PA3`), 115200 8N1이다.
  `b` BYPASS, `f` FIXED, `a` AUTO,
  `s` 상태 출력, `t` 생성 신호 DSP 자체 시험이다. FPGA 없이 `t`를 실행할 수 있다.
  MCU 재시작 시 살아 있는 FPGA의 모드를 읽어 이어간다.
- 먼저 MISO와 `READ_STATE`를 확인하고, 이어서 512샘플 CRC 및 `SET_COEFF` 적용을 확인한다.
- AUTO는 700~3,000 Hz의 단일 간섭을 대상으로 한다. 경계 밖 인접 피크도 검사하며
  보간 오차를 고려해 경계에 3 Hz 허용 폭을 둔다. 초기 검출 기준은 보정 진폭 3 ADC
  카운트 이상, 피크 전력은 피크 주변을 제외한 평균 전력의 12배 이상이다.
- 최근 유효 블록 3개의 추정치를 갱신한다. 후보 일치 허용 폭은 10 Hz, 적용 계수의
  갱신 기준은 8 Hz이고, Notch 모델의 `r=0.98`이다. ADC 레일(0 또는 255)이 한 블록에서
  네 번 이상 나타나면 블록을 버리고 이전 계수를 유지한다. `s`의 `clip`은 이 블록 수다.
- `s`의 `max_step_ms`는 SPI·분석을 포함한 STM32 제어 루프 한 번의 최대 실행 시간이다.
  오디오 입력→출력 지연과 주파수 변경→감쇠 회복 시간은 각각 실물에서 따로 측정한다.
