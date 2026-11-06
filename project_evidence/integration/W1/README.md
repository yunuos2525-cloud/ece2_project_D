# W1 FPGA–STM32 physical SPI integration packet

Status: **PENDING PHYSICAL TEST**.

Wiring target from the v8 interface:

| STM32 NUCLEO-H533RE | FPGA COMBO II-DLD S75 | Direction |
|---|---|---|
| PB3 / SPI1_SCK | BDIO00 / F8 | STM32 to FPGA |
| PA7 / SPI1_MOSI | BDIO01 / E8 | STM32 to FPGA |
| PB6 / GPIO CS | BDIO02 / A7 | STM32 to FPGA |
| PA6 / SPI1_MISO | BDIO03 / G8 | FPGA to STM32 |
| GND | GND | common reference |

Procedure: power off, verify continuity/jumpers/3.3 V and no output conflict; then start at <=500 kHz Mode 0 MSB-first. Validate `A5`/`5A`, 16 bytes, and finally `READ_BLOCK` with block ID and CRC. Abort one frame before CRC and prove that the same block is returned on retry. Record logic-analyzer traces and STM32 receive logs here. Simulation logs are not physical integration evidence.
