# ECE2 Project D

**FPGA–STM32 기반 미지의 단일 협대역 간섭 자동 추적·억제 시스템**

## 목표

- 16 kHz, mono, 초기 8-bit 신호 처리
- 500 Hz 정상 시험 신호에 미지의 협대역 간섭 1개를 추가한 입력 조건에서 자동 추정·억제
- STM32가 분석용 샘플을 받아 FFT로 간섭 주파수를 추정하고, 가변 Notch 계수를 계산·전달
- FPGA가 ADC/DAC 실시간 경로와 가변 IIR Notch 연산 수행
- FPGA에서 디지털시계(연·월·일·시·분·초·요일), 스톱워치, Text LCD 구현
- 오실로스코프 측정으로 간섭 감쇠와 정상 신호 보존 검증

## 저장소 구성

```text
FPGA/                     FPGA RTL·시뮬레이션·핀 제약
  src/
  sim/
  constraints/
  tools/
STM32/                    STM32 C 프로젝트 및 관련 설정
  (STM32 담당자가 실제 프로젝트 구조 유지)
docs/                     팀 공통 기술 문서·개발 로드맵
project_evidence/         팀 프로젝트 검증 자료
  fpga/
  stm32/
  integration/
tools/                    공동 검증 스크립트
```

빈 폴더는 Git이 저장하지 않기 때문에 `.gitkeep`으로 유지한다. 실제 소스는 각 담당자가 해당 폴더에 추가한다.

## 공통 기준 문서

- [FPGA 5주 개발 로드맵](docs/FPGA_5W_ROADMAP_v8_final.md)
- [STM32 5주 개발 로드맵](docs/STM32_5W_ROADMAP_v8_final.md)
- [SPI·데이터 교환 규격](docs/TEAM_SPI_INTERFACE_v8_final.md)

**모드 구분:** DSP의 `BYPASS/FIXED/AUTO`는 STM32가 지시하며, FPGA의 LCD 표시 화면 선택과 독립적이다.

## 협업·검증

- `main`: 팀이 검토한 통합 기준 버전.
- FPGA와 STM32는 담당 소스 폴더에서 개발하고, 공통 SPI 규격 변경은 양측과 공유한다.
- 시뮬레이션 통과, 실제 보드 통합 성공, 오실로스코프 성능 검증을 서로 다른 단계로 기록한다.
- `project_evidence/`에는 프로젝트에서 실제 확보한 파형·로그·측정표만 넣는다.
- 실험실 검증은 함수발생기와 오실로스코프를 기본으로 한다.

> 이 저장소의 문서는 설계·개발 목표이다. 하드웨어 구현 완료나 목표 성능 달성을 의미하지 않는다.
