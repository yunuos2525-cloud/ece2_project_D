#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "audio_control.h"

typedef struct {
    bool selected;
    bool ready;
    bool corrupt;
    bool fail_read;
    bool valid;
    bool queued;
    uint16_t block_id;
    uint8_t seq;
    uint8_t queued_seq;
    uint8_t mode;
    size_t length;
    unsigned writes;
    uint8_t last_write[13];
    uint8_t command;
    uint8_t samples[AUDIO_BLOCK_SIZE];
} FakeFpga;

static uint8_t test_crc(const uint8_t *data, size_t length)
{
    unsigned remainder = 0;
    for (size_t i = 0; i < length; ++i) {
        remainder ^= (unsigned)data[i] << 8;
        for (unsigned b = 0; b < 8; ++b) {
            remainder <<= 1;
            if (remainder & 0x10000u) {
                remainder ^= 0x10700u;
            }
        }
    }
    return (uint8_t)(remainder >> 8);
}

static void make_signal(uint8_t samples[AUDIO_BLOCK_SIZE], float hz, double normal_amplitude, double tone_amplitude)
{
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        const double t = 6.283185307179586 * i / AUDIO_SAMPLE_RATE;
        const double value = 128.0 + normal_amplitude * sin(t * 500.0) + tone_amplitude * sin(t * hz);
        samples[i] = (uint8_t)lround(fmin(255.0, fmax(0.0, value)));
    }
}

static void fake_select(void *context, bool selected)
{
    FakeFpga *fake = context;
    assert(fake->selected != selected);
    fake->selected = selected;
    if (selected) {
        fake->length = 0;
        fake->command = 0;
    } else if (fake->command == 0x10 && fake->length == 517) {
        fake->ready = false;
    }
}

static bool fake_transfer(void *context, const uint8_t *tx, uint8_t *rx, size_t length)
{
    FakeFpga *fake = context;
    assert(fake->selected && length > 0);
    const bool first = fake->length == 0;
    if (first) {
        fake->command = tx[0];
    }
    memset(rx, 0, length);
    switch (fake->command) {
        case 0x10:
            if (first) {
                assert(length == 2 && tx[1] == 0);
                rx[1] = (uint8_t)fake->ready;
            } else {
                assert(fake->ready && length == 515);
                for (size_t i = 0; i < length; ++i) {
                    assert(tx[i] == 0);
                }
                if (fake->fail_read) {
                    return false;
                }
                rx[0] = (uint8_t)fake->block_id;
                rx[1] = (uint8_t)(fake->block_id >> 8);
                memcpy(rx + 2, fake->samples, sizeof fake->samples);
                rx[length - 1] = test_crc(rx, length - 1) ^ (uint8_t)fake->corrupt;
            }
            break;
        case 0x20:
            assert(first && length == 13 && tx[12] == test_crc(tx + 1, 11));
            memcpy(fake->last_write, tx, length);
            fake->queued_seq = tx[1];
            fake->queued = true;
            ++fake->writes;
            break;
        case 0x21:
            assert(first && length == 4 && tx[1] == 0 && tx[2] == 0 && tx[3] == 0);
            rx[1] = fake->mode;
            rx[2] = fake->valid ? fake->seq : 0xff;
            rx[3] = (uint8_t)fake->valid;
            break;
        default:
            assert(first && length == 1);
            assert(tx[0] == FPGA_BYPASS || tx[0] == FPGA_FIXED || (tx[0] == FPGA_AUTO && fake->valid));
            fake->mode = tx[0];
            break;
    }
    fake->length += length;
    return true;
}

static void load_block(FakeFpga *fake, uint16_t id, float hz)
{
    fake->ready = true;
    fake->block_id = id;
    make_signal(fake->samples, hz, 38, 36);
}

static double filter_gain_db(const int16_t coeff[NOTCH_COEFF_COUNT], double hz)
{
    const double w = 6.283185307179586 * hz / AUDIO_SAMPLE_RATE;
    const double nr = coeff[0] + coeff[1] * cos(w) + coeff[2] * cos(2 * w);
    const double ni = coeff[1] * sin(w) + coeff[2] * sin(2 * w);
    const double dr = 16384 + coeff[3] * cos(w) + coeff[4] * cos(2 * w);
    const double di = coeff[3] * sin(w) + coeff[4] * sin(2 * w);
    return 10 * log10((nr * nr + ni * ni) / (dr * dr + di * di));
}

static void verify_dsp(void)
{
    AudioFft fft;
    Tone tone;
    uint8_t samples[AUDIO_BLOCK_SIZE];
    audio_fft_init(&fft);
    make_signal(samples, 0, 38, 0);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 530, 38, 36);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 650, 38, 36);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 680, 38, 70);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 3030, 38, 36);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 0, 180, 0);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_CLIPPED);
    make_signal(samples, 1370, 38, 2);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_ABSENT);
    make_signal(samples, 1370, 38, 4);
    assert(audio_find_tone(&fft, samples, &tone) == TONE_DETECTED);
    assert(fabsf(tone.hz - 1370) < 3);

    int16_t coeff[NOTCH_COEFF_COUNT];
    const float inputs[] = {700.0f, 930.0f, 1370.0f, 1830.0f, 2460.0f, 2700.0f, 3000.0f};
    for (size_t i = 0; i < sizeof inputs / sizeof inputs[0]; ++i) {
        make_signal(samples, inputs[i], 38, 36);
        assert(audio_find_tone(&fft, samples, &tone) == TONE_DETECTED);
        assert(fabsf(tone.hz - inputs[i]) < 8.0f);
        assert(audio_notch_coefficients(tone.hz, 0.98f, coeff));
        const double interference_db = filter_gain_db(coeff, inputs[i]);
        const double normal_db = filter_gain_db(coeff, 500);
        assert(interference_db <= -10.0 && fabs(normal_db) <= 1.0);
        printf("Generated tone %.0f Hz -> %.2f Hz | model: tone %.2f dB, 500 Hz %+.2f dB\n",
               inputs[i], tone.hz, interference_db, normal_db);
    }
    const int16_t expected[] = {16384, -30274, 16384, -29668, 15735};
    assert(audio_notch_coefficients(1000, 0.98f, coeff));
    assert(memcmp(expected, coeff, sizeof expected) == 0);
    assert(!audio_notch_coefficients(500, 0.98f, coeff));
    assert(!audio_notch_coefficients(1000, 1.0f, coeff));
    FakeFpga fake = {.mode = FPGA_BYPASS};
    FpgaLink link = {.context = &fake, .select = fake_select, .transfer = fake_transfer};
    const uint8_t frame[] = {0x20, 0x01, 0x00, 0x40, 0xbe, 0x89, 0x00, 0x40, 0x1c, 0x8c, 0x77, 0x3d, 0x62};
    assert(fpga_set_coeff(&link, 1, expected) == LINK_OK);
    assert(memcmp(frame, fake.last_write, sizeof frame) == 0);
    puts("1 kHz Q2.14 and SPI frame match the golden vector");
}

static void verify_small_retunes(void)
{
    FakeFpga fake = {.mode = FPGA_BYPASS};
    FpgaLink link = {.context = &fake, .select = fake_select, .transfer = fake_transfer};
    AudioControl control;
    audio_control_init(&control, &link, 0);
    audio_control_request(&control, FPGA_AUTO, 0);
    const float tones[] = {1370, 1395, 1405};
    uint16_t id = 0;
    for (unsigned group = 0; group < sizeof tones / sizeof tones[0]; ++group) {
        for (unsigned block = 0; block < TONE_CONFIRM_BLOCKS; ++block, ++id) {
            const uint32_t now = id * 32u;
            load_block(&fake, id, tones[group]);
            audio_control_step(&control, now);
            if (fake.queued) {
                fake.valid = true;
                fake.seq = fake.queued_seq;
                fake.queued = false;
                audio_control_step(&control, now + 2);
            }
        }
        assert(fake.writes == group + 1 && control.applied_updates == group + 1);
        assert(fabsf(control.applied_hz - tones[group]) < 3.0f);
        int16_t coeff[NOTCH_COEFF_COUNT];
        for (unsigned i = 0; i < NOTCH_COEFF_COUNT; ++i) {
            const uint16_t word = (uint16_t)(fake.last_write[2 + 2 * i] | (fake.last_write[3 + 2 * i] << 8));
            coeff[i] = (int16_t)(word <= INT16_MAX ? (int32_t)word : (int32_t)word - 65536);
        }
        assert(filter_gain_db(coeff, tones[group]) <= -10.0);
        printf("Retune %.0f Hz -> %.2f Hz, model %.2f dB\n",
               tones[group], control.applied_hz, filter_gain_db(coeff, tones[group]));
    }

    for (unsigned block = 0; block < TONE_CONFIRM_BLOCKS; ++block, ++id) {
        load_block(&fake, id, 0);
        make_signal(fake.samples, 0, 180, 0);
        audio_control_step(&control, id * 32u);
    }
    assert(control.clipped_blocks == TONE_CONFIRM_BLOCKS && fake.writes == 3 && fake.mode == FPGA_AUTO);
    puts("Clipped blocks do not replace the last valid AUTO coefficients");
}

static void verify_control(void)
{
    FakeFpga fake = {.mode = FPGA_BYPASS};
    FpgaLink link = {.context = &fake, .select = fake_select, .transfer = fake_transfer};
    AudioControl control;
    audio_control_init(&control, &link, 0);
    audio_control_step(&control, 0);
    assert(fake.mode == FPGA_BYPASS && control.have_state);
    audio_control_request(&control, FPGA_FIXED, 1);
    audio_control_step(&control, 1);
    assert(fake.mode == FPGA_FIXED);
    audio_control_request(&control, FPGA_AUTO, 4);
    audio_control_step(&control, 4);
    assert(fake.mode == FPGA_BYPASS && fake.length == 2 && !fake.selected);

    load_block(&fake, 65534, 930);
    fake.fail_read = true;
    audio_control_step(&control, 6);
    assert(fake.ready && !fake.selected && control.link_errors == 1);
    fake.fail_read = false;
    audio_control_step(&control, 8);
    load_block(&fake, 65534, 930);
    audio_control_step(&control, 10);
    assert(control.valid_blocks == 1);
    load_block(&fake, 65535, 930);
    audio_control_step(&control, 12);
    load_block(&fake, 0, 930);
    audio_control_step(&control, 14);
    assert(fake.writes == 1 && fake.queued && control.pending && control.discontinuities == 0);
    audio_control_step(&control, 16);
    assert(fake.mode == FPGA_BYPASS && control.pending);
    fake.valid = true;
    fake.seq = fake.queued_seq;
    audio_control_step(&control, 18);
    assert(fake.mode == FPGA_AUTO && control.applied_updates == 1);
    assert(fabsf(control.applied_hz - 930.0f) < 8.0f);

    load_block(&fake, 1, 2460);
    fake.corrupt = true;
    audio_control_step(&control, 20);
    assert(control.crc_errors == 1 && fake.writes == 1 && fake.mode == FPGA_AUTO);
    fake.corrupt = false;
    for (uint16_t id = 2; id <= 4; ++id) {
        load_block(&fake, id, 2460);
        audio_control_step(&control, 22u + 2u * (id - 2u));
    }
    assert(control.discontinuities == 1 && fake.writes == 2 && fake.seq != fake.queued_seq);
    fake.seq = fake.queued_seq;
    audio_control_step(&control, 28);
    assert(control.applied_updates == 2 && fabsf(control.applied_hz - 2460.0f) < 8.0f);

    audio_control_init(&control, &link, 100);
    audio_control_step(&control, 100);
    assert(control.requested == FPGA_AUTO && fake.mode == FPGA_AUTO && fake.writes == 2);
    fake.mode = FPGA_BYPASS;
    fake.valid = false;
    audio_control_step(&control, 164);
    assert(!control.remote.coeff_valid && fake.mode == FPGA_BYPASS);
    for (uint16_t id = 0; id < 3; ++id) {
        load_block(&fake, id, 1370);
        audio_control_step(&control, 166u + 2u * id);
    }
    assert(fake.writes == 3 && control.pending);
    fake.valid = true;
    fake.seq = fake.queued_seq;
    audio_control_step(&control, 172);
    assert(fake.mode == FPGA_AUTO && fabsf(control.applied_hz - 1370.0f) < 8.0f);
    puts("Mock FPGA: frame lengths, CRC, duplicates, ID wrap, delayed apply, retracking and restart passed");
}

int main(void)
{
    verify_dsp();
    verify_control();
    verify_small_retunes();
    return 0;
}
