#include "fpga_link.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { CAPTURE_CAPACITY = 1024 };

typedef struct {
    FILE *log;
    uint8_t captured[CAPTURE_CAPACITY];
    size_t captured_count;
    unsigned transfer_index;
    bool selected;
} VirtualSpi;

static uint8_t crc8_atm_reference(const uint8_t *bytes, size_t length)
{
    uint8_t crc = 0;
    for (size_t i = 0; i < length; ++i) {
        crc ^= bytes[i];
        for (unsigned bit = 0; bit < 8; ++bit) {
            crc = (uint8_t)((crc << 1) ^ ((crc & 0x80u) ? 0x07u : 0u));
        }
    }
    return crc;
}

static uint8_t sample_pattern(size_t index)
{
    return (uint8_t)(index * 37u + 13u);
}

static void virtual_select(void *context, bool selected)
{
    VirtualSpi *spi = context;
    spi->selected = selected;
    fprintf(spi->log, "CS %s\n", selected ? "LOW" : "HIGH");
}

static bool virtual_transfer(void *context, const uint8_t *tx, uint8_t *rx, size_t length)
{
    VirtualSpi *spi = context;
    if (!spi->selected || spi->captured_count + length > CAPTURE_CAPACITY) {
        return false;
    }

    const size_t offset = spi->captured_count;
    memcpy(&spi->captured[offset], tx, length);
    spi->captured_count += length;
    memset(rx, 0, length);

    /* Deterministic virtual FPGA replies let the unmodified C deserializers run. */
    if (length == 4 && tx[0] == 0x21) {
        rx[1] = FPGA_FIXED;
        rx[2] = 0xff;
        rx[3] = 0x00;
    } else if (length == 2 && tx[0] == 0x10) {
        rx[1] = 0x01;
    } else if (length == 2 + AUDIO_BLOCK_SIZE + 1) {
        rx[0] = 0x00;
        rx[1] = 0x00;
        for (size_t i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
            rx[2 + i] = sample_pattern(i);
        }
        rx[length - 1] = crc8_atm_reference(rx, length - 1);
    }

    fprintf(spi->log, "TRANSFER %u offset=%zu length=%zu TX=", ++spi->transfer_index, offset, length);
    if (length <= 16) {
        for (size_t i = 0; i < length; ++i) {
            fprintf(spi->log, "%s%02X", i ? " " : "", tx[i]);
        }
    } else {
        fprintf(spi->log, "%02X %02X ... %02X (%zu bytes)", tx[0], tx[1], tx[length - 1], length);
    }
    fputc('\n', spi->log);
    return true;
}

static void log_frame(FILE *log, const char *name, const VirtualSpi *spi, size_t start, LinkResult result)
{
    const size_t length = spi->captured_count - start;
    fprintf(log, "FRAME %-11s offset=%zu length=%zu result=%d TX=", name, start, length, (int)result);
    if (length <= 32) {
        for (size_t i = 0; i < length; ++i) {
            fprintf(log, "%s%02X", i ? " " : "", spi->captured[start + i]);
        }
    } else {
        fprintf(log, "%02X %02X ... %02X (%zu bytes)", spi->captured[start],
                spi->captured[start + 1], spi->captured[start + length - 1], length);
    }
    fputc('\n', log);
}

static bool write_hex(const char *path, const uint8_t *bytes, size_t length)
{
    FILE *file = fopen(path, "wb");
    if (!file) {
        return false;
    }
    for (size_t i = 0; i < length; ++i) {
        fprintf(file, "%02X\n", bytes[i]);
    }
    return fclose(file) == 0;
}

int main(int argc, char **argv)
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s frames.hex generation.log\n", argv[0]);
        return 2;
    }

    FILE *log = fopen(argv[2], "wb");
    if (!log) {
        perror("generation log");
        return 2;
    }

    VirtualSpi spi = {.log = log};
    FpgaLink link = {
        .context = &spi,
        .select = virtual_select,
        .transfer = virtual_transfer,
    };
    LinkResult result;
    size_t start;

    fprintf(log, "SOURCE=unmodified STM32/src/fpga_link.c executed on PC with virtual SPI callbacks\n");
    fprintf(log, "NOTE=This is host execution, not bytes captured from a physical STM32 board.\n");

    start = spi.captured_count;
    result = fpga_set_mode(&link, FPGA_FIXED);
    log_frame(log, "FIXED", &spi, start, result);
    if (result != LINK_OK) return 3;

    start = spi.captured_count;
    result = fpga_set_mode(&link, FPGA_BYPASS);
    log_frame(log, "BYPASS", &spi, start, result);
    if (result != LINK_OK) return 3;

    start = spi.captured_count;
    result = fpga_set_mode(&link, FPGA_AUTO);
    log_frame(log, "AUTO", &spi, start, result);
    if (result != LINK_OK) return 3;

    FpgaState state;
    start = spi.captured_count;
    result = fpga_read_state(&link, &state);
    log_frame(log, "READ_STATE", &spi, start, result);
    fprintf(log, "READ_STATE decoded mode=%02X seq=%02X coeff_valid=%u loss=%u\n",
            (unsigned)state.mode, state.seq, state.coeff_valid, state.loss);
    if (result != LINK_OK || state.mode != FPGA_FIXED || state.seq != 0xff || state.coeff_valid || state.loss) return 4;

    SampleBlock block;
    start = spi.captured_count;
    result = fpga_read_block(&link, &block);
    log_frame(log, "READ_BLOCK", &spi, start, result);
    fprintf(log, "READ_BLOCK decoded id=%04X first=%02X last=%02X loss=%u\n",
            block.id, block.samples[0], block.samples[AUDIO_BLOCK_SIZE - 1], block.loss);
    if (result != LINK_OK || block.id != 0 || block.loss) return 5;
    for (size_t i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        if (block.samples[i] != sample_pattern(i)) return 5;
    }

    int16_t coeff[NOTCH_COEFF_COUNT];
    if (!audio_notch_coefficients(1000.0f, 0.98f, coeff)) return 6;
    fprintf(log, "COEFF source=audio_notch_coefficients hz=1000.0 radius=0.98 q2.14=%d,%d,%d,%d,%d\n",
            coeff[0], coeff[1], coeff[2], coeff[3], coeff[4]);
    start = spi.captured_count;
    result = fpga_set_coeff(&link, 0x01, coeff);
    log_frame(log, "SET_COEFF", &spi, start, result);
    if (result != LINK_OK) return 6;

    static const int16_t expected_coeff[NOTCH_COEFF_COUNT] = {16384, -30274, 16384, -29668, 15735};
    if (memcmp(coeff, expected_coeff, sizeof coeff) != 0) return 7;
    if (spi.captured_count != 537) return 8;
    if (!write_hex(argv[1], spi.captured, spi.captured_count)) return 9;

    fprintf(log, "FRAME_LAYOUT fixed=0 bypass=1 auto=2 read_state=3:6 read_block=7:523 set_coeff=524:536\n");
    fprintf(log, "TOTAL_CAPTURED_BYTES=%zu\nPASS STM32_FRAME_GENERATION\n", spi.captured_count);
    fclose(log);
    printf("PASS STM32_FRAME_GENERATION bytes=%zu coeff=%d,%d,%d,%d,%d\n",
           spi.captured_count, coeff[0], coeff[1], coeff[2], coeff[3], coeff[4]);
    return 0;
}
