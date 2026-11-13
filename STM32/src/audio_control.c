#include "audio_control.h"

#include <math.h>
#include <string.h>

enum { BLOCK_POLL_MS = 2, STATE_POLL_MS = 64, VERIFY_POLL_MS = 2, APPLY_TIMEOUT_MS = 40 };
static const float confirmation_tolerance_hz = 10.0f;
/* Leave margin to the roughly 17 Hz center error that costs 10 dB rejection. */
static const float retune_hysteresis_hz = 8.0f;
/* Provisional radius from the team's starting filter model. */
static const float notch_radius = 0.98f;

void audio_control_init(AudioControl *control, FpgaLink *link, uint32_t now)
{
    memset(control, 0, sizeof *control);
    control->link = link;
    control->requested = FPGA_BYPASS;
    control->adopt_mode = true;
    control->next_state_ms = now;
    control->next_block_ms = now;
    audio_fft_init(&control->fft);
}

void audio_control_request(AudioControl *control, FpgaMode mode, uint32_t now)
{
    control->adopt_mode = false;
    control->requested = mode;
    control->stable_blocks = 0;
    control->have_block = false;
    control->next_state_ms = now;
    control->next_block_ms = now;
}

static bool due(uint32_t now, uint32_t deadline)
{
    return now - deadline < UINT32_C(0x80000000);
}

static void service_state(AudioControl *control, uint32_t now)
{
    FpgaState state;
    const LinkResult result = fpga_read_state(control->link, &state);
    control->next_state_ms = now + (control->pending ? VERIFY_POLL_MS : STATE_POLL_MS);
    if (result != LINK_OK) {
        ++control->link_errors;
        control->have_state = false;
        control->stable_blocks = 0;
        if (control->pending && due(now, control->apply_deadline_ms)) {
            control->pending = false;
        }
        return;
    }

    if (control->adopt_mode) {
        /* A microcontroller reboot can leave the FPGA and audio path running. */
        control->requested = state.mode;
        control->next_seq = state.coeff_valid ? (uint8_t)(state.seq + 1u) : 0;
        control->adopt_mode = false;
    }
    if (!state.coeff_valid || (control->remote.coeff_valid && state.seq != control->remote.seq)) {
        control->applied_hz = 0.0f;
    }
    control->remote = state;
    control->have_state = true;
    control->block_loss = state.loss;
    if (control->pending) {
        if (state.coeff_valid && state.seq == control->pending_seq) {
            control->applied_hz = control->pending_hz;
            control->pending = false;
            ++control->applied_updates;
        } else if (due(now, control->apply_deadline_ms)) {
            control->pending = false;
            ++control->link_errors;
        }
    }

    FpgaMode desired = control->requested;
    if (desired == FPGA_AUTO && !state.coeff_valid) {
        desired = FPGA_BYPASS;
    }
    if (state.mode != desired) {
        if (fpga_set_mode(control->link, desired) != LINK_OK) {
            ++control->link_errors;
        }
        control->next_state_ms = now + VERIFY_POLL_MS;
    }
}

static void record_tone(AudioControl *control, float hz)
{
    if (fabsf(hz - control->candidate_hz) > confirmation_tolerance_hz) {
        control->stable_blocks = 0;
    }
    if (control->stable_blocks == 0) {
        control->next_tone_index = 0;
    }
    control->recent_hz[control->next_tone_index] = hz;
    control->next_tone_index = (control->next_tone_index + 1) % TONE_CONFIRM_BLOCKS;
    if (control->stable_blocks < TONE_CONFIRM_BLOCKS) {
        ++control->stable_blocks;
    }

    float sum = 0.0f;
    for (unsigned i = 0; i < control->stable_blocks; ++i) {
        sum += control->recent_hz[i];
    }
    control->candidate_hz = sum / control->stable_blocks;
}

static void track_block(AudioControl *control, uint32_t now)
{
    const LinkResult result = fpga_read_block(control->link, &control->block);
    if (result == LINK_OK || result == LINK_NO_BLOCK) {
        control->block_loss = control->block.loss;
    }
    if (result == LINK_NO_BLOCK) {
        return;
    }
    if (result != LINK_OK) {
        if (result == LINK_CRC_ERROR) {
            ++control->crc_errors;
        } else {
            ++control->link_errors;
        }
        control->stable_blocks = 0;
        return;
    }

    if (control->have_block) {
        const uint16_t delta = (uint16_t)(control->block.id - control->last_id);
        if (delta == 0) {
            return;
        }
        if (delta != 1) {
            ++control->discontinuities;
            control->stable_blocks = 0;
        }
    }
    control->have_block = true;
    control->last_id = control->block.id;
    ++control->valid_blocks;

    Tone tone;
    const ToneResult detection = audio_find_tone(&control->fft, control->block.samples, &tone);
    if (detection != TONE_DETECTED) {
        if (detection == TONE_CLIPPED) {
            ++control->clipped_blocks;
        }
        control->stable_blocks = 0;
        return;
    }
    record_tone(control, tone.hz);
    if (control->stable_blocks < TONE_CONFIRM_BLOCKS || control->pending ||
        (control->remote.coeff_valid && fabsf(control->candidate_hz - control->applied_hz) < retune_hysteresis_hz)) {
        return;
    }

    int16_t coeff[NOTCH_COEFF_COUNT];
    if (!audio_notch_coefficients(control->candidate_hz, notch_radius, coeff)) {
        control->stable_blocks = 0;
        return;
    }
    if (control->remote.coeff_valid && control->next_seq == control->remote.seq) {
        ++control->next_seq;
    }
    const uint8_t seq = control->next_seq++;
    if (fpga_set_coeff(control->link, seq, coeff) != LINK_OK) {
        ++control->link_errors;
        control->stable_blocks = 0;
        return;
    }
    control->pending = true;
    control->pending_seq = seq;
    control->pending_hz = control->candidate_hz;
    control->apply_deadline_ms = now + APPLY_TIMEOUT_MS;
    control->next_state_ms = now + VERIFY_POLL_MS;
}

void audio_control_step(AudioControl *control, uint32_t now)
{
    if (due(now, control->next_state_ms)) {
        service_state(control, now);
    }
    if (control->have_state && control->requested == FPGA_AUTO && due(now, control->next_block_ms)) {
        control->next_block_ms = now + BLOCK_POLL_MS;
        track_block(control, now);
    }
}
