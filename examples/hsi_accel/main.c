/* test_hsi_accel.c
 *
 * Pequeña aplicación de usuario para verificar el acceso a registros
 * del acelerador HSI en GR‑HEEP.
 */

#include <stdio.h>
#include <stdint.h>
#include "hsi_accel_regs.h"

#define TEST_OPCODE   0x1
#define TEST_NUM_BANDS 2

int main(void) {
    uint32_t r;

    printf("=== HSI_ACCEL Register R/W Test ===\n\n");

    /* 1) OP_CODE */
    printf("  * Escribiendo OP_CODE = 0x%02X ... ", TEST_OPCODE);
    hsi_accel_set_opcode(TEST_OPCODE);
    r = hsi_accel_get_opcode();
    printf("Leído = 0x%02X %s\n",
        r, (r == TEST_OPCODE) ? "[OK]" : "[ERROR]");

    /* 2) NUM_BANDS */
    printf("  * Escribiendo NUM_BANDS = %u ... ", TEST_NUM_BANDS);
    hsi_accel_set_num_bands(TEST_NUM_BANDS);
    r = hsi_accel_get_num_bands();
    printf("Leído = %u %s\n",
        r, (r == TEST_NUM_BANDS) ? "[OK]" : "[ERROR]");

    /* 3) START + STATUS */
    printf("  * Lanzando operación (START)...\n");
    hsi_accel_start();

    /* Espera activa por DONE (timeout simplificado) */
    for (int i = 0; i < 1000000; i++) {
        if (hsi_accel_is_done()) break;
    }
    r = hsi_accel_get_status();
    printf("    - STATUS = 0x%08X  [DONE=%u BUSY=%u ERR=0x%X]\n",
        r,
        hsi_accel_is_done(),
        hsi_accel_is_busy(),
        hsi_accel_get_error()
    );

    /* 4) Limpieza de flags */
    printf("  * Limpiando DONE y ERROR ...\n");
    hsi_accel_clear_done();
    hsi_accel_clear_error();
    r = hsi_accel_get_status();
    printf("    - STATUS post-clear = 0x%08X  [DONE=%u ERR=0x%X]\n",
        r,
        hsi_accel_is_done(),
        hsi_accel_get_error()
    );

    printf("\n== Test completado ==\n");
    return 0;
}
