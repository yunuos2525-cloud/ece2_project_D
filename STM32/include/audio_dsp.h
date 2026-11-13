#ifndef AUDIO_DSP_H
#define AUDIO_DSP_H

#include <stdbool.h>
#include <stdint.h>

enum { AUDIO_SAMPLE_RATE = 16000, AUDIO_BLOCK_SIZE = 512, NOTCH_COEFF_COUNT = 5 };

typedef struct {
    float window[AUDIO_BLOCK_SIZE];
    float twiddle_re[AUDIO_BLOCK_SIZE / 2];
    float twiddle_im[AUDIO_BLOCK_SIZE / 2];
    float real[AUDIO_BLOCK_SIZE];
    float imag[AUDIO_BLOCK_SIZE];
    float window_sum;
} AudioFft;

typedef struct {
    float hz;
    float amplitude;
} Tone;

typedef enum { TONE_ABSENT, TONE_DETECTED, TONE_CLIPPED } ToneResult;

void audio_fft_init(AudioFft *fft);
ToneResult audio_find_tone(AudioFft *fft, const uint8_t samples[AUDIO_BLOCK_SIZE], Tone *tone);
bool audio_notch_coefficients(float hz, float radius, int16_t coeff[NOTCH_COEFF_COUNT]);

#endif
