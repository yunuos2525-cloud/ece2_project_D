# W2 Vivado status

## 최종 상태

2026-11-14 Windows CMD에서 사용자가 다음 명령을 직접 실행하고 exit code 0을 확인했다.

```text
"C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat" -mode batch -nolog -nojournal -source FPGA\tools\build_w2_vivado.tcl
```

성공 당시 stdout/stderr는 수집되지 않았다. 따라서 콘솔 로그나 `PASS VIVADO_W2_BUILD` 출력은 복원하지 않으며, exit code 0은 사용자 확인 결과로 기록한다. 아래 구현 결과는 생성된 DCP, Bitstream 및 Vivado 보고서를 직접 검사한 값이다.

- Tool: Vivado 2026.1, build 6511674, win64
- Top: `w2_board_top`
- Part: `xc7s75fgga484-1`
- Synthesis: PASS (`post_synth.dcp`, 보고서의 `Design State: Synthesized`)
- Place/route: PASS (`post_route.dcp`, `Design State: Fully Routed`)
- Timing: WNS `+2.681 ns`, TNS `0.000 ns`, WHS `+0.043 ns`; 지정된 timing constraint 충족
- DRC: Error/Critical Warning 0, Warning 11 (`CFGBVS-1` 1, `DPIP-1` 10)
- Bitstream: `FPGA/build/w2/w2_board_top.bit`, 3,687,015 bytes, 2026-11-14 22:04:28.862 KST
- Bitstream SHA-256: `85320DFBA2DD5858B24CE0D0F6F03AB26E8FF2CDE5AB4B52A988E7A82645922D`

Timing PASS는 FPGA 내부의 사용자 지정 제약에 대한 결과다. 31개 출력에 output delay가 없으며 ADC 입력 timing/CDC도 미확인이다. 상세 제한은 `DRC_TIMING_REVIEW.md`를 따른다.

## 이전 실패 이력

최종 성공 전에 Codex 실행 환경에서 Vivado launcher가 RTL/XDC를 읽기 전에 exit 42로 종료됐다. 원문은 `vivado_w2_exact_w1_env.log`에 그대로 보존한다.

```text
ERROR: Vivado Design Suite cannot be launched because a valid license was not found.
```

최종 성공과 이전 실패는 서로 다른 실행 시점·프로세스 문맥의 결과다. 동일 executable/명령 형식임에도 결과가 달랐지만 성공 실행의 환경 snapshot과 콘솔 로그가 없으므로 정확한 원인은 확정하지 않는다. exit 42를 RTL/TCL/XDC 결함으로 해석하지 않는다.

## W1 보존

`FPGA/build/w1/w1_board_top.bit`은 3,687,015 bytes, SHA-256 `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`로 기존 기록과 동일하다.

