#ifndef AUDIO_CONTROL_H
#define AUDIO_CONTROL_H

#include "fpga_link.h"

enum { TONE_CONFIRM_BLOCKS = 3 };

typedef struct {
    FpgaLink *link;
    AudioFft fft;
    SampleBlock block;
    FpgaState remote;
    FpgaMode requested;
    bool adopt_mode;
    bool have_state;
    bool have_block;
    bool block_loss;
    bool pending;
    uint8_t next_seq;
    uint8_t pending_seq;
    uint16_t last_id;
    unsigned stable_blocks;
    unsigned next_tone_index;
    uint32_t next_state_ms;
    uint32_t next_block_ms;
    uint32_t apply_deadline_ms;
    float candidate_hz;
    float recent_hz[TONE_CONFIRM_BLOCKS];
    float pending_hz;
    float applied_hz;
    uint32_t valid_blocks;
    uint32_t clipped_blocks;
    uint32_t discontinuities;
    uint32_t crc_errors;
    uint32_t link_errors;
    uint32_t applied_updates;
} AudioControl;

void audio_control_init(AudioControl *control, FpgaLink *link, uint32_t now);
void audio_control_request(AudioControl *control, FpgaMode mode, uint32_t now);
void audio_control_step(AudioControl *control, uint32_t now);

#endif
