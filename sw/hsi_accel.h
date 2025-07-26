/* hsi_accel.h
 *
 * High‑level API para el acelerador HSI
 */
#ifndef HSI_ACCEL_H
#define HSI_ACCEL_H

#include <stdint.h>
#include <stdbool.h>
#include "hsi_accel_regs.h"

/**
 * @brief Inicializa el acelerador (borra flags previos).
 */
static inline void hsi_accel_init(void) {
    hsi_accel_clear_done();
    hsi_accel_clear_error();
}

/**
 * @brief Configura opcode y número de bandas.
 */
static inline void hsi_accel_configure(uint32_t opcode, uint32_t num_bands) {
    hsi_accel_set_opcode(opcode);
    hsi_accel_set_num_bands(num_bands);
}

/**
 * @brief Lanza la operación (dot- o cross-product).
 */
static inline void hsi_accel_launch(void) {
    hsi_accel_start();
}

/**
 * @brief Espera a DONE o timeout (polling).
 * @param timeout_ciclos Número máximo de iteraciones de polling.
 * @return true si completó con DONE, false si timeout.
 */
bool hsi_accel_wait_done(uint32_t timeout_ciclos);

/**
 * @brief Devuelve código de error (0 = sin error).
 */
static inline uint32_t hsi_accel_error(void) {
    return hsi_accel_get_error();
}

#endif /* HSI_ACCEL_H */
