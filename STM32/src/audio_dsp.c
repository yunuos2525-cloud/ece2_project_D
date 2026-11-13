#include "audio_dsp.h"

#include <math.h>

static const float two_pi = 6.2831853071795864769f;
static const float bin_hz = (float)AUDIO_SAMPLE_RATE / AUDIO_BLOCK_SIZE;
static const float minimum_hz = 700.0f;
static const float maximum_hz = 3000.0f;
/* Initial thresholds in ADC counts and peak-to-background power. */
static const float minimum_amplitude = 3.0f;
static const float minimum_prominence = 12.0f;
static const float edge_tolerance_hz = 3.0f;
enum { EDGE_GUARD_BINS = 3, PEAK_GUARD_BINS = 2, CLIP_RAIL_COUNT = 4 };

void audio_fft_init(AudioFft *fft)
{
    fft->window_sum = 0.0f;
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        fft->window[i] = 0.5f * (1.0f - cosf(two_pi * i / (AUDIO_BLOCK_SIZE - 1)));
        fft->window_sum += fft->window[i];
    }
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE / 2; ++i) {
        const float angle = -two_pi * i / AUDIO_BLOCK_SIZE;
        fft->twiddle_re[i] = cosf(angle);
        fft->twiddle_im[i] = sinf(angle);
    }
}

static bool fft_transform(AudioFft *fft, const uint8_t samples[AUDIO_BLOCK_SIZE])
{
    uint32_t sum = 0;
    unsigned rail_count = 0;
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        const uint8_t sample = samples[i];
        sum += sample;
        if ((sample == 0 || sample == UINT8_MAX) && ++rail_count >= CLIP_RAIL_COUNT) {
            return false;
        }
    }
    const float mean = (float)sum / AUDIO_BLOCK_SIZE;
    unsigned reversed = 0;
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        fft->real[reversed] = (samples[i] - mean) * fft->window[i];
        fft->imag[reversed] = 0.0f;
        unsigned bit = AUDIO_BLOCK_SIZE / 2;
        while (reversed & bit) {
            reversed ^= bit;
            bit >>= 1;
        }
        reversed ^= bit;
    }

    for (unsigned width = 2; width <= AUDIO_BLOCK_SIZE; width *= 2) {
        const unsigned half = width / 2;
        const unsigned stride = AUDIO_BLOCK_SIZE / width;
        for (unsigned start = 0; start < AUDIO_BLOCK_SIZE; start += width) {
            for (unsigned j = 0; j < half; ++j) {
                const unsigned a = start + j;
                const unsigned b = a + half;
                const unsigned w = j * stride;
                const float re = fft->real[b] * fft->twiddle_re[w] - fft->imag[b] * fft->twiddle_im[w];
                const float im = fft->real[b] * fft->twiddle_im[w] + fft->imag[b] * fft->twiddle_re[w];
                fft->real[b] = fft->real[a] - re;
                fft->imag[b] = fft->imag[a] - im;
                fft->real[a] += re;
                fft->imag[a] += im;
            }
        }
    }
    return true;
}

static float power_at(const AudioFft *fft, unsigned bin)
{
    const float re = fft->real[bin];
    const float im = fft->imag[bin];
    return re * re + im * im;
}

ToneResult audio_find_tone(AudioFft *fft, const uint8_t samples[AUDIO_BLOCK_SIZE], Tone *tone)
{
    if (!fft_transform(fft, samples)) {
        return TONE_CLIPPED;
    }
    const unsigned first = (unsigned)(minimum_hz / bin_hz);
    const unsigned last = (unsigned)ceilf(maximum_hz / bin_hz);
    unsigned peak = first;
    float peak_power = 0.0f;
    /* Include nearby out-of-band peaks so their leakage cannot be mistaken for an edge tone. */
    for (unsigned bin = first - EDGE_GUARD_BINS; bin <= last + EDGE_GUARD_BINS; ++bin) {
        const float power = power_at(fft, bin);
        if (power > peak_power) {
            peak = bin;
            peak_power = power;
        }
    }

    const float left = sqrtf(power_at(fft, peak - 1));
    const float right = sqrtf(power_at(fft, peak + 1));
    const float center = sqrtf(peak_power);
    const float curvature = left - 2.0f * center + right;
    if (curvature >= 0.0f || center < left || center < right) {
        return TONE_ABSENT;
    }
    const float offset = 0.5f * (left - right) / curvature;
    const float hz = (peak + offset) * bin_hz;
    if (hz < minimum_hz - edge_tolerance_hz || hz > maximum_hz + edge_tolerance_hz) {
        return TONE_ABSENT;
    }

    float background_power = 0.0f;
    unsigned background_bins = 0;
    for (unsigned bin = first; bin <= last; ++bin) {
        if (bin + PEAK_GUARD_BINS < peak || bin > peak + PEAK_GUARD_BINS) {
            background_power += power_at(fft, bin);
            ++background_bins;
        }
    }
    const float peak_magnitude = center - 0.25f * (left - right) * offset;
    const float amplitude = 2.0f * peak_magnitude / fft->window_sum;
    if (amplitude < minimum_amplitude || peak_power < minimum_prominence * (background_power / background_bins)) {
        return TONE_ABSENT;
    }
    tone->hz = fminf(maximum_hz, fmaxf(minimum_hz, hz));
    tone->amplitude = amplitude;
    return TONE_DETECTED;
}

bool audio_notch_coefficients(float hz, float radius, int16_t coeff[NOTCH_COEFF_COUNT])
{
    if (!(hz >= minimum_hz && hz <= maximum_hz && radius > 0.0f && radius < 1.0f)) {
        return false;
    }
    const float middle = -2.0f * cosf(two_pi * hz / AUDIO_SAMPLE_RATE);
    const float values[NOTCH_COEFF_COUNT] = {1.0f, middle, 1.0f, radius * middle, radius * radius};
    int16_t quantized[NOTCH_COEFF_COUNT];
    for (unsigned i = 0; i < NOTCH_COEFF_COUNT; ++i) {
        const long scaled = lroundf(values[i] * 16384.0f);
        if (scaled < INT16_MIN || scaled > INT16_MAX) {
            return false;
        }
        quantized[i] = (int16_t)scaled;
    }
    const int32_t a1 = quantized[3];
    const int32_t a2 = quantized[4];
    if (a2 >= 16384 || 16384 + a1 + a2 <= 0 || 16384 - a1 + a2 <= 0) {
        return false;
    }
    for (unsigned i = 0; i < NOTCH_COEFF_COUNT; ++i) {
        coeff[i] = quantized[i];
    }
    return true;
}
