#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#include "dma.h"
#include "core_v_mini_mcu.h"
#include "csr.h"
#include "x-heep.h"
#include "hsi_accel_regs.h"

// --- Direcciones de los registros FIFO ---
#define HSI_ACCEL_FIFO_IN1_OFFSET 0x20  // FIFO IN1

// --- Parámetros de la prueba ---
#define TEST_DATA_SIZE 1                // 3 componentes de 16 bits
#define DMA_CHANNEL_TX  0
#define DMA_CHANNEL_RX  1

// --- Datos de prueba ---
static uint16_t fifo_in1_data[TEST_DATA_SIZE] __attribute__((aligned(4))) =
                                   {0xAB};
static uint16_t verify_buffer[TEST_DATA_SIZE] __attribute__((aligned(4))) = {0};

// ---------------------------------------------------------------------------
// Rutina principal
// ---------------------------------------------------------------------------
int main(void)
{
    dma_config_flags_t res;
    uint32_t errors = 0;

    dma_init(NULL);  // inicializa el DMA interno

    //-------------------------------------------------------------------- TX
    // Copia fifo_in1_data --> FIFO IN1 (0x20)  (inc_dest = 0)
    //--------------------------------------------------------------------
    dma_target_t tx_src = {
        .ptr       = (uint8_t *)fifo_in1_data,
        .inc_d1_du = 1,
        .trig      = DMA_TRIG_MEMORY,
        .type      = DMA_DATA_TYPE_HALF_WORD,
    };

    dma_target_t tx_dst = {
        .ptr       = (uint8_t *)(HSI_ACCEL_PERIPH_BASE + HSI_ACCEL_FIFO_IN1_OFFSET),
        .inc_d1_du = 0,          // no autoincremento en destino
        .trig      = DMA_TRIG_MEMORY,
        .type      = DMA_DATA_TYPE_HALF_WORD,
    };

    dma_trans_t tx = {
        .src       = &tx_src,
        .dst       = &tx_dst,
        .size_d1_du= TEST_DATA_SIZE,
        .mode      = DMA_TRANS_MODE_SINGLE,
        .win_du    = 0,
        .end       = DMA_TRANS_END_INTR,
    };

    printf("\n-- TX DMA --> FIFO IN1 --\n\r");
    res = dma_validate_transaction(&tx, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    printf("validate: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res = dma_load_transaction(&tx);
    printf("load: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res = dma_launch(&tx);
    printf("launch: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");

    while (!dma_is_ready(DMA_CHANNEL_TX)) {
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        wait_for_interrupt();
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }
    printf("TX done\n\r");

    //-------------------------------------------------------------------- RX
    // Copia FIFO IN1 (0x20) --> verify_buffer  (inc_src = 0)
    //--------------------------------------------------------------------
    dma_target_t rx_src = {
        .ptr       = (uint8_t *)(HSI_ACCEL_PERIPH_BASE + HSI_ACCEL_FIFO_IN1_OFFSET),
        .inc_d1_du = 0,          // origen fijo
        .trig      = DMA_TRIG_MEMORY,
        .type      = DMA_DATA_TYPE_HALF_WORD,
    };

    dma_target_t rx_dst = {
        .ptr       = (uint8_t *)verify_buffer,
        .inc_d1_du = 1,
        .trig      = DMA_TRIG_MEMORY,
        .type      = DMA_DATA_TYPE_HALF_WORD,
    };

    dma_trans_t rx = {
        .src       = &rx_src,
        .dst       = &rx_dst,
        .size_d1_du= TEST_DATA_SIZE,
        .mode      = DMA_TRANS_MODE_SINGLE,
        .win_du    = 0,
        .end       = DMA_TRANS_END_INTR,
    };

    printf("\n-- RX DMA <-- FIFO IN1 --\n\r");
    res = dma_validate_transaction(&rx, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    printf("validate: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res = dma_load_transaction(&rx);
    printf("load: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");
    res = dma_launch(&rx);
    printf("launch: %u \t%s\n\r", res, res == DMA_CONFIG_OK ?  "Ok!" : "Error!");

    while (!dma_is_ready(DMA_CHANNEL_RX)) {
        CSR_CLEAR_BITS(CSR_REG_MSTATUS, 0x8);
        wait_for_interrupt();
        CSR_SET_BITS(CSR_REG_MSTATUS, 0x8);
    }
    printf("RX done\n\r");

    //-------------------------------------------------------------------- Check
    for (size_t i = 0; i < TEST_DATA_SIZE; ++i) {
        if (verify_buffer[i] != fifo_in1_data[i]) {
            printf("Mismatch [%d] 0x%04x != 0x%04x\n\r",
                   (int)i, verify_buffer[i], fifo_in1_data[i]);
            ++errors;
        }
    }

    if (errors == 0)
        printf("SUCCESS: all %u half-words verified OK\n\r", TEST_DATA_SIZE);
    else
        printf("FAIL: %u / %u words wrong\n\r", errors, TEST_DATA_SIZE);

    return errors ? EXIT_FAILURE : EXIT_SUCCESS;
}
