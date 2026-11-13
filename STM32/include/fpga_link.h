#ifndef FPGA_LINK_H
#define FPGA_LINK_H

#include "audio_dsp.h"

#include <stddef.h>

typedef enum { FPGA_BYPASS = 0x01, FPGA_FIXED = 0x02, FPGA_AUTO = 0x06 } FpgaMode;
typedef enum { LINK_OK, LINK_NO_BLOCK, LINK_IO_ERROR, LINK_CRC_ERROR, LINK_INVALID_REPLY } LinkResult;

typedef struct {
    void *context;
    void (*select)(void *context, bool selected);
    bool (*transfer)(void *context, const uint8_t *tx, uint8_t *rx, size_t length);
    uint8_t zeros[2 + AUDIO_BLOCK_SIZE + 1];
    uint8_t reply[2 + AUDIO_BLOCK_SIZE + 1];
} FpgaLink;

typedef struct {
    uint16_t id;
    uint8_t samples[AUDIO_BLOCK_SIZE];
    bool loss;
} SampleBlock;

typedef struct {
    FpgaMode mode;
    uint8_t seq;
    bool coeff_valid;
    bool loss;
} FpgaState;

LinkResult fpga_read_block(FpgaLink *link, SampleBlock *block);
LinkResult fpga_read_state(FpgaLink *link, FpgaState *state);
LinkResult fpga_set_coeff(FpgaLink *link, uint8_t seq, const int16_t coeff[NOTCH_COEFF_COUNT]);
LinkResult fpga_set_mode(FpgaLink *link, FpgaMode mode);

#endif
