# FPGA W1 pre-implementation test plan

Recorded before RTL implementation on 2026-11-06 (Asia/Seoul).

## Fixed requirements

- System clock: 50 MHz; audio rate: 16 kHz; one-cycle enable every 3,125 clocks.
- Samples: mono, unsigned offset-binary 8 bit.
- Fixed DSP: second-order 1 kHz IIR notch, Q2.14 coefficients, signed arithmetic and saturated 8-bit output.
- Analysis path: immutable 512-sample blocks, 16-bit little-endian block ID, explicit loss flag.
- SPI: slave, Mode 0, MSB first, initially at or below 500 kHz.
- `READ_BLOCK` (`0x10`): status, ID low/high, 512 samples, CRC-8/ATM over ID and samples.
- A block is consumed only after the final CRC byte and CS deassertion. An interrupted frame must be retryable.
- Audio processing must continue independently of SPI traffic.
- Power-up DSP mode is BYPASS. W1 AUTO has no coefficient receiver and therefore falls back to BYPASS.

## Tests, expected results, pass criteria

| ID | Stimulus | Expected result | Pass criterion |
|---|---|---|---|
| T01 | Reset and repeated sample ticks | Tick is low during reset and one 50 MHz cycle wide every 3,125 clocks | Exact interval and pulse width for at least four ticks |
| T02 | BYPASS values including `00`, `80`, `A5`, `5A`, `FF` | Output order and value are unchanged | Every accepted sample matches bit-for-bit |
| T03 | 500 Hz sine, 16 kHz sampling | Fixed-notch output preserves the wanted tone | Output/input magnitude change within 1 dB after settling |
| T04 | 1 kHz sine | Fixed notch suppresses the interference | Output/input magnitude at 1 kHz is at most -10 dB |
| T05 | 500 Hz + 1 kHz mixture | 500 Hz is preserved and 1 kHz is suppressed | 500 Hz within 1 dB and 1 kHz at most -10 dB |
| T06 | 512 sequential samples | One ready block with ID 0 and stable ordered bytes | All 512 random-access reads match |
| T07 | Two unread blocks followed by more samples | Valid blocks are not overwritten | Sticky loss flag sets; oldest complete blocks remain intact |
| T08 | SPI mode commands and known `A5`, `5A` samples | Mode 0/MSB-first receive and MISO ordering are correct | Command state and received bytes match |
| T09 | Complete `READ_BLOCK` | Status/ID/512 samples/CRC match v8 | 517-byte frame, exact data, CRC-8/ATM match, block consumed after CS high |
| T10 | Abort `READ_BLOCK` before CRC, then retry | Same block remains available | Same block ID/data returned on retry; no premature consume |
| T11 | RTC and stopwatch basic boundaries | RTC seconds/minutes/hours and stopwatch 10 ms count advance correctly | Automated rollover/start/stop/reset assertions pass |
| T12 | Vivado non-project build | Top elaborates for `xc7s75fgga484-1`; implementation has no fatal DRC/timing error | Synthesis, implementation and bitstream complete, or exact tool error is recorded |

All simulation tests must emit a fresh textual log and VCD. A simulator exit alone is not PASS; each self-checking testbench must print its named `PASS` line. Board tests are never promoted to PASS from simulation or bitstream generation.

## Fixed-notch design point

The W1 filter uses `r = 0.95` and DC-gain normalization for 16 kHz sampling:

`[b0,b1,b2,a1,a2] = [15834,-29257,15834,-28760,14787] / 2^14`.

The implemented equation is exactly the shared v8 convention:

`y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]`.

These are simulation design coefficients, not a claim of analog-board performance.
