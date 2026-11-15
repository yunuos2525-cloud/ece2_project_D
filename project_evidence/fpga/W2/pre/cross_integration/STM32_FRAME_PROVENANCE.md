# STM32 frame provenance

- Git commit: `91a1a077fabd8a4c83a0ea8f5b9237c45b87b70b`
- Execution: Microsoft Visual C host executable with virtual SPI callbacks.
- Important: these are bytes produced by the STM32 C implementation on a PC; they are not a physical-board SPI capture.
- C sources are exported directly from the named Git object at test time and are not edited.
- `fpga_link.c` performs the actual command serialization and response deserialization.
- `audio_dsp.c` generates the 1 kHz, radius 0.98 Q2.14 coefficients passed to `fpga_set_coeff`.

## Exported source SHA-256

- `d681dc44e923bbad0ed43e83c1bfcc7c97ce3ab219d4403d3f2d4bff9bf490e3` - `fpga_link.c`
- `e5031a206391f686a19a927202f19766ded03c78a0a2387aecb170f0d58d6852` - `audio_dsp.c`
- `c733228f392148064c37b52fbf37d478ec8ad68131bc83e11f6747c576b81247` - `fpga_link.h`
- `f7bed7b6cd4f18279d956e6ba73de57eb15176782af4cf701a6e3b7eceaa1b2d` - `audio_dsp.h`

## Git blob object IDs

- `ecd3c91168e86c26b98559d5f3df4c3f57ebc465` - `STM32/src/fpga_link.c`
- `aa0967774e0455fadd1b96336845d793c5a03731` - `STM32/src/audio_dsp.c`
- `f012b94cc0edbd2f6b04475b300d803694aa043f` - `STM32/include/fpga_link.h`
- `f1cdd3b31cbeb55a0a6573c7fcfc09cf6eb0d871` - `STM32/include/audio_dsp.h`

The exported files are temporary compilation inputs and are not copied into the repository evidence.
