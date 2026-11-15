# W2 PRE development failure history

최종 PASS 이전에 관찰한 실패를 보존한다.

1. 가변 IIR 최초 실행에서 목표/500 Hz 출력이 `0x00`에 고정됐다. 피드백 곱을 sign-extend한 concatenation이 unsigned로 해석되어 arithmetic shift가 잘못된 것이 원인이었다. 각 확장 항을 `$signed(...)`로 명시한 뒤 4개 목표와 500 Hz 시험을 모두 재실행해 PASS했다.
2. 최초 DSP 재실행에서는 reset 해제 race도 의심되어 TB가 reset을 하강 edge에서만 바꾸도록 수정했다. 이 변경만으로 실패는 사라지지 않았고, 위 signed 연산 수정 후 해결됐다.
3. READ_STATE 첫-bit 시험은 seq `0x42`의 MSB를 1로 잘못 기대했다. 내부 shift register가 실제로 `0x42`를 선행 로드한 것을 확인했고, 시험 벡터를 MSB=1인 seq `0xA5`로 바꿔 요구 타이밍을 검증했다. RTL 결함은 아니었다.
4. 최초 통합 TB는 모의 오디오 스트림이 13-byte SPI frame보다 먼저 끝나 계수 후보 뒤의 sample boundary가 없었다. RTL은 규격대로 적용을 보류했고 TB가 대기했다. 스트림을 frame 전체와 겹치게 연장하고 timeout을 추가한 뒤 300/300 sample PASS를 얻었다.
5. 위 무한 대기 실행의 `vvp`가 남아 재귀 VCD를 계속 기록했다. 해당 작업에서 생성된 프로세스만 종료하고 통합 VCD를 top-level 신호로 제한하여 약 693 KB로 다시 생성했다.
6. Codex 실행 환경에서는 `vivado`와 과거 W1 성공 경로인 `vivado.bat` 모두 license 확인 단계에서 exit 42로 종료됐다. 당시에는 합성 실패나 구현 PASS로 바꾸지 않고 실행 불가로 기록했고 원문 로그를 보존했다.
7. 이후 사용자가 Windows CMD에서 동일 `vivado.bat -mode batch -nolog -nojournal -source FPGA\tools\build_w2_vivado.tcl` 명령을 실행해 exit code 0을 확인했다. 성공 stdout/stderr는 수집되지 않았으므로 생성하지 않았으며, DCP·보고서·Bitstream으로 최종 성공을 검증했다. 두 실행 문맥의 차이는 현재 증거로 확정하지 않는다.
