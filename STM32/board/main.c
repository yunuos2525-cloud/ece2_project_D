#include "audio_control.h"
#if defined(STM32G474xx)
#include "stm32g4xx_hal.h"
#else
#include "stm32h5xx_hal.h"
#endif

#include <math.h>
#include <stdio.h>
#include <string.h>

static SPI_HandleTypeDef spi;
static UART_HandleTypeDef uart;
static AudioControl control;
static uint32_t max_control_step_ms;

void SysTick_Handler(void)
{
    HAL_IncTick();
}

static void setup_pins(void)
{
    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, GPIO_PIN_SET);

    GPIO_InitTypeDef gpio = {0};
    gpio.Pin = GPIO_PIN_6;
    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Speed = GPIO_SPEED_FREQ_LOW;
    HAL_GPIO_Init(GPIOB, &gpio);

    gpio.Mode = GPIO_MODE_AF_PP;
    gpio.Alternate = GPIO_AF5_SPI1;
    gpio.Pin = GPIO_PIN_3;
    gpio.Pull = GPIO_PULLDOWN;
    HAL_GPIO_Init(GPIOB, &gpio);
    gpio.Pin = GPIO_PIN_6 | GPIO_PIN_7;
    gpio.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(GPIOA, &gpio);

    gpio.Pin = GPIO_PIN_2 | GPIO_PIN_3;
#if defined(STM32G474xx)
    gpio.Alternate = GPIO_AF12_LPUART1;
#else
    gpio.Alternate = GPIO_AF7_USART2;
#endif
    HAL_GPIO_Init(GPIOA, &gpio);
}

static HAL_StatusTypeDef setup_spi(void)
{
#if defined(STM32H533xx)
    /* HSI64 divided by 128 gives a nominal 500 kHz on H533. */
    __HAL_RCC_CLKP_CONFIG(RCC_CLKPSOURCE_HSI);
    __HAL_RCC_SPI1_CONFIG(RCC_SPI1CLKSOURCE_CLKP);
#endif
    __HAL_RCC_SPI1_CLK_ENABLE();
    spi.Instance = SPI1;
    spi.Init.Mode = SPI_MODE_MASTER;
    spi.Init.Direction = SPI_DIRECTION_2LINES;
    spi.Init.DataSize = SPI_DATASIZE_8BIT;
    spi.Init.CLKPolarity = SPI_POLARITY_LOW;
    spi.Init.CLKPhase = SPI_PHASE_1EDGE;
    spi.Init.NSS = SPI_NSS_SOFT;
    spi.Init.FirstBit = SPI_FIRSTBIT_MSB;
    spi.Init.TIMode = SPI_TIMODE_DISABLE;
    spi.Init.CRCCalculation = SPI_CRCCALCULATION_DISABLE;
    spi.Init.NSSPMode = SPI_NSS_PULSE_DISABLE;
#if defined(STM32G474xx)
    /* SPI1 uses PCLK2, which is HSI16 with reset prescalers. */
    spi.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_32;
#else
    spi.Init.BaudRatePrescaler = SPI_BAUDRATEPRESCALER_128;
    spi.Init.NSSPolarity = SPI_NSS_POLARITY_LOW;
    spi.Init.FifoThreshold = SPI_FIFO_THRESHOLD_01DATA;
    spi.Init.MasterKeepIOState = SPI_MASTER_KEEP_IO_STATE_ENABLE;
#endif
    return HAL_SPI_Init(&spi);
}

static HAL_StatusTypeDef setup_uart(void)
{
#if defined(STM32G474xx)
    __HAL_RCC_LPUART1_CONFIG(RCC_LPUART1CLKSOURCE_PCLK1);
    __HAL_RCC_LPUART1_CLK_ENABLE();
    uart.Instance = LPUART1;
#else
    __HAL_RCC_USART2_CONFIG(RCC_USART2CLKSOURCE_PCLK1);
    __HAL_RCC_USART2_CLK_ENABLE();
    uart.Instance = USART2;
#endif
    uart.Init.BaudRate = 115200;
    uart.Init.WordLength = UART_WORDLENGTH_8B;
    uart.Init.StopBits = UART_STOPBITS_1;
    uart.Init.Parity = UART_PARITY_NONE;
    uart.Init.Mode = UART_MODE_TX_RX;
    uart.Init.HwFlowCtl = UART_HWCONTROL_NONE;
    uart.Init.OverSampling = UART_OVERSAMPLING_16;
    uart.Init.ClockPrescaler = UART_PRESCALER_DIV1;
    return HAL_UART_Init(&uart);
}

static void console_write(const char *line)
{
    HAL_UART_Transmit(&uart, (const uint8_t *)line, (uint16_t)strlen(line), 25);
}

static void spi_select(void *context, bool selected)
{
    (void)context;
    HAL_GPIO_WritePin(GPIOB, GPIO_PIN_6, selected ? GPIO_PIN_RESET : GPIO_PIN_SET);
    /* Leave a visible frame boundary for the FPGA's 50 MHz synchronizers. */
    for (unsigned i = 0; i < 32; ++i) {
        __NOP();
    }
}

static bool spi_transfer(void *context, const uint8_t *tx, uint8_t *rx, size_t length)
{
    SPI_HandleTypeDef *handle = context;
    const HAL_StatusTypeDef result = HAL_SPI_TransmitReceive(handle, tx, rx, (uint16_t)length, 20);
    if (result != HAL_OK) {
        HAL_SPI_Abort(handle);
    }
    return result == HAL_OK;
}

static FpgaLink link = {.context = &spi, .select = spi_select, .transfer = spi_transfer};

static void print_status(void)
{
    char line[192];
    snprintf(line, sizeof line,
             "request=%02X mode=%02X valid=%u seq=%u hz=%u id=%u ok=%lu gap=%lu crc=%lu link=%lu clip=%lu loss=%u max_step_ms=%lu\r\n",
             (unsigned)control.requested, control.have_state ? (unsigned)control.remote.mode : 0u,
             (unsigned)(control.have_state && control.remote.coeff_valid), (unsigned)control.remote.seq,
             (unsigned)(control.applied_hz + 0.5f), (unsigned)control.last_id, (unsigned long)control.valid_blocks,
             (unsigned long)control.discontinuities, (unsigned long)control.crc_errors,
             (unsigned long)control.link_errors, (unsigned long)control.clipped_blocks,
             (unsigned)control.block_loss, (unsigned long)max_control_step_ms);
    console_write(line);
}

static void run_dsp_self_test(void)
{
    if (control.requested == FPGA_AUTO) {
        console_write("Select b before running the local DSP test\r\n");
        return;
    }
    uint8_t samples[AUDIO_BLOCK_SIZE];
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        const float phase = 6.28318530718f * i / AUDIO_SAMPLE_RATE;
        samples[i] = (uint8_t)lroundf(128.0f + 38.0f * sinf(500.0f * phase));
    }
    Tone tone;
    const bool rejected_500 = audio_find_tone(&control.fft, samples, &tone) == TONE_ABSENT;
    for (unsigned i = 0; i < AUDIO_BLOCK_SIZE; ++i) {
        const float phase = 6.28318530718f * i / AUDIO_SAMPLE_RATE;
        samples[i] = (uint8_t)lroundf(128.0f + 38.0f * sinf(500.0f * phase) + 36.0f * sinf(2700.0f * phase));
    }
    const bool found = audio_find_tone(&control.fft, samples, &tone) == TONE_DETECTED;
    const int16_t expected[] = {16384, -30274, 16384, -29668, 15735};
    int16_t coeff[NOTCH_COEFF_COUNT];
    const bool coeff_ok = audio_notch_coefficients(1000.0f, 0.98f, coeff) &&
                          memcmp(coeff, expected, sizeof expected) == 0;
    const bool passed = rejected_500 && found && fabsf(tone.hz - 2700.0f) < 8.0f && coeff_ok;
    char line[96];
    snprintf(line, sizeof line, "DSP self-test %s | 500 rejected=%u | tone=%u Hz | Q2.14=%s\r\n",
             passed ? "PASS" : "FAIL", (unsigned)rejected_500, found ? (unsigned)(tone.hz + 0.5f) : 0u,
             coeff_ok ? "OK" : "FAIL");
    console_write(line);
}

int main(void)
{
    SystemCoreClockUpdate();
    HAL_Init();
    setup_pins();
    if (setup_uart() != HAL_OK) {
        for (;;) { __WFI(); }
    }
    if (setup_spi() != HAL_OK) {
        console_write("SPI1 initialization failed\r\n");
        for (;;) { __WFI(); }
    }

    audio_control_init(&control, &link, HAL_GetTick());
    console_write("Project D | b BYPASS | f FIXED | a AUTO | s status | t DSP test\r\n");
    uint32_t printed_updates = 0;
    for (;;) {
        uint8_t key;
        if (__HAL_UART_GET_FLAG(&uart, UART_FLAG_ORE)) {
            __HAL_UART_CLEAR_OREFLAG(&uart);
        }
        if (HAL_UART_Receive(&uart, &key, 1, 0) == HAL_OK) {
            const uint32_t now = HAL_GetTick();
            switch (key) {
                case 'b': audio_control_request(&control, FPGA_BYPASS, now); break;
                case 'f': audio_control_request(&control, FPGA_FIXED, now); break;
                case 'a': audio_control_request(&control, FPGA_AUTO, now); break;
                case 's': print_status(); break;
                case 't': run_dsp_self_test(); break;
                default: break;
            }
        }
        const uint32_t step_start = HAL_GetTick();
        audio_control_step(&control, step_start);
        const uint32_t step_ms = HAL_GetTick() - step_start;
        if (step_ms > max_control_step_ms) {
            max_control_step_ms = step_ms;
        }
        if (control.applied_updates != printed_updates) {
            printed_updates = control.applied_updates;
            print_status();
        }
        __WFI();
    }
}
