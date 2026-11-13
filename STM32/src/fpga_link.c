#include "fpga_link.h"

#include <string.h>

static uint8_t crc8_atm(const uint8_t *bytes, size_t length)
{
    uint8_t crc = 0;
    for (size_t i = 0; i < length; ++i) {
        crc ^= bytes[i];
        for (unsigned bit = 0; bit < 8; ++bit) {
            const uint8_t polynomial = (crc & 0x80u) ? 0x07u : 0u;
            crc = (uint8_t)((crc << 1) ^ polynomial);
        }
    }
    return crc;
}

static LinkResult transact(FpgaLink *link, const uint8_t *tx, uint8_t *rx, size_t length)
{
    link->select(link->context, true);
    const bool ok = link->transfer(link->context, tx, rx, length);
    link->select(link->context, false);
    return ok ? LINK_OK : LINK_IO_ERROR;
}

LinkResult fpga_read_block(FpgaLink *link, SampleBlock *block)
{
    const uint8_t command[] = {0x10, 0};
    uint8_t header[sizeof command];
    link->select(link->context, true);
    const bool header_ok = link->transfer(link->context, command, header, sizeof header);
    LinkResult result = LINK_IO_ERROR;
    if (header_ok) {
        const uint8_t status = header[1];
        if (status & 0xfcu) {
            result = LINK_INVALID_REPLY;
        } else if (!(status & 1u)) {
            result = LINK_NO_BLOCK;
            block->loss = (status & 2u) != 0;
        } else if (link->transfer(link->context, link->zeros, link->reply, sizeof link->reply)) {
            const size_t crc_index = sizeof link->reply - 1;
            result = LINK_CRC_ERROR;
            if (link->reply[crc_index] == crc8_atm(link->reply, crc_index)) {
                block->id = (uint16_t)(link->reply[0] | ((uint16_t)link->reply[1] << 8));
                memcpy(block->samples, &link->reply[2], AUDIO_BLOCK_SIZE);
                block->loss = (status & 2u) != 0;
                result = LINK_OK;
            }
        }
    }
    link->select(link->context, false);
    return result;
}

static bool valid_mode(uint8_t mode)
{
    return mode == FPGA_BYPASS || mode == FPGA_FIXED || mode == FPGA_AUTO;
}

LinkResult fpga_read_state(FpgaLink *link, FpgaState *state)
{
    const uint8_t tx[] = {0x21, 0, 0, 0};
    uint8_t rx[sizeof tx];
    const LinkResult result = transact(link, tx, rx, sizeof tx);
    if (result != LINK_OK) {
        return result;
    }
    if (!valid_mode(rx[1]) || (rx[3] & 0xfcu) || (!(rx[3] & 1u) && rx[2] != 0xffu)) {
        return LINK_INVALID_REPLY;
    }
    *state = (FpgaState){(FpgaMode)rx[1], rx[2], (rx[3] & 1u) != 0, (rx[3] & 2u) != 0};
    return LINK_OK;
}

LinkResult fpga_set_coeff(FpgaLink *link, uint8_t seq, const int16_t coeff[NOTCH_COEFF_COUNT])
{
    uint8_t tx[2 + 2 * NOTCH_COEFF_COUNT + 1] = {0x20, seq};
    uint8_t rx[sizeof tx];
    for (unsigned i = 0; i < NOTCH_COEFF_COUNT; ++i) {
        const uint16_t value = (uint16_t)coeff[i];
        tx[2 + 2 * i] = (uint8_t)value;
        tx[3 + 2 * i] = (uint8_t)(value >> 8);
    }
    tx[sizeof tx - 1] = crc8_atm(&tx[1], sizeof tx - 2);
    return transact(link, tx, rx, sizeof tx);
}

LinkResult fpga_set_mode(FpgaLink *link, FpgaMode mode)
{
    const uint8_t tx = (uint8_t)mode;
    uint8_t rx;
    return valid_mode(tx) ? transact(link, &tx, &rx, 1) : LINK_INVALID_REPLY;
}
