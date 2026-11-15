# W2 LCD/UI pin provenance and conflict review

로컬 수업자료 `C:\Users\yunji\ece2\ece2_2026`에서 다음 검증된 LAB 제약을 재사용했다.

- LCD: `LAB3/24_character_lcd/constraints/lab3_character_lcd.xdc`
- 버튼·스위치: `LAB2/08A_integrated/constraints/lab2_integrated.xdc`
- LCD 초기화/타이밍 구조: `LAB3/24_character_lcd/src/lab3_character_lcd.v`

| 자원 | W2 port | package pin | W1 충돌 |
|---|---|---|---|
| LCD E/RS/RW | `lcd_e/lcd_rs/lcd_rw` | A6/G6/D6 | 없음 |
| LCD D0..D7 | `lcd_data[0..7]` | A4,B2,C3,D4,A2,C5,C1,D1 | 없음 |
| 화면 선택 | `display_mode[0..1]` | W4,T1 | 없음; ADC channel U4,V4,W1과 분리 |
| START/STOP | `sw_start_btn/sw_stop_btn` | N8,N4 | 없음 |
| SW RESET | `sw_reset_switch` | Y1 | 없음 |

모든 새 입력은 동기화·debounce 후 사용하며, 화면 선택은 DSP mode와 독립이다. N8/N4의 실물 active-high/low 판정 기록이 없으므로 top parameter 기본값은 active-high이고 실제 극성은 POST에서 확인해야 한다. LCD 모듈 장착, 전압, 문자 가독성 및 버튼 명칭은 시뮬레이션으로 확인할 수 없다.
