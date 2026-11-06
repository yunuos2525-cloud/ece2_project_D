# W1 reset-fix build provenance

- Build tool: Vivado 2026.1 build 6511674.
- Part/top: `xc7s75fgga484-1` / `w1_board_top`.
- Build interval: 2026-11-06 21:04:07–21:07:35 Asia/Seoul.
- Bitstream generated at: 2026-11-06 21:07:21 Asia/Seoul.
- Bitstream size: 3,687,015 bytes.
- Bitstream SHA-256: `67FD1CAB419903EB764ADCF04DE3D7440A1723CFFDA9E0D5A24979AD7410DED4`.

All files listed in `BUILD_INPUTS.sha256` match the current workspace. Their
latest modification time is 20:53:10, before the build started. The retained
build log records `read_verilog -sv` over every `FPGA/src/*.sv`, the W1 XDC,
successful synthesis/implementation, and `PASS VIVADO_BUILD`. Therefore the
current RTL/XDC/Tcl set corresponds to the recorded bitstream.

The `.bit`, DCP, Vivado cache and run directories are deliberately excluded
from Git. The hash and generated text reports are the GitHub archival record.
The reports in this `_public` directory differ from the local raw reports only
by replacement of the workstation hostname and user-specific absolute
repository path. Timing, CDC, DRC, utilization and build messages are unchanged.
