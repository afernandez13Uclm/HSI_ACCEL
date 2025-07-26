/* hsi_accel_regs.h
 *
 * Definición de offsets y rutinas inline para acceder a los registros
 * de hsi_vector_core_wrapper vía OBI (mapeado en 0x1000_0000).
 */

#ifndef HSI_ACCEL_REGS_H
#define HSI_ACCEL_REGS_H

#include <stdint.h>
#include <stdbool.h>

/* Base del periférico (tal como lo configuras en gr-heep-cfg.hjson) */
#define HSI_ACCEL_PERIPH_BASE   0x10000000UL

/* Offsets de registro (bytes) */
#define HSI_ACCEL_OPCODE_OFFSET      0x00  /* OP_CODE [RW] */
#define HSI_ACCEL_NUM_BANDS_OFFSET   0x04  /* NUM_BANDS [RW] */
#define HSI_ACCEL_COMMAND_OFFSET     0x08  /* COMMAND [WO]: START, CLEAR_DONE, CLEAR_ERROR */
#define HSI_ACCEL_STATUS_OFFSET      0x0C  /* STATUS  [RO]: DONE, ERROR_CODE, BUSY */
#define HSI_ACCEL_FIFO_STATUS_OFFSET 0x10  /* FIFO_STATUS [RO] (si EXPOSE_FIFO_STATUS=1) */

/* Bits del registro COMMAND */
#define HSI_ACCEL_CMD_START_BIT        0  /* al escribir 1 dispara la operación */
#define HSI_ACCEL_CMD_CLEAR_DONE_BIT   1  /* limpia la bandera DONE */
#define HSI_ACCEL_CMD_CLEAR_ERROR_BIT  2  /* limpia los bits de ERROR */

/* Bits del registro STATUS */
#define HSI_ACCEL_STATUS_DONE_BIT        0
#define HSI_ACCEL_STATUS_ERROR_SHIFT     1
#define HSI_ACCEL_STATUS_ERROR_WIDTH     4  /* ERR_WIDTH = 4 */
#define HSI_ACCEL_STATUS_ERROR_MASK      (((1u<<HSI_ACCEL_STATUS_ERROR_WIDTH)-1) << HSI_ACCEL_STATUS_ERROR_SHIFT)
#define HSI_ACCEL_STATUS_BUSY_BIT        8

/* Accesos de bajo nivel */
static inline void   hsi_accel_write_reg(uint32_t off, uint32_t v) {
    *(volatile uint32_t*)(HSI_ACCEL_PERIPH_BASE + off) = v;
}
static inline uint32_t hsi_accel_read_reg(uint32_t off) {
    return *(volatile uint32_t*)(HSI_ACCEL_PERIPH_BASE + off);
}

/* Funciones de acceso */
static inline void hsi_accel_set_opcode(uint32_t code) {
    hsi_accel_write_reg(HSI_ACCEL_OPCODE_OFFSET, code);
}
static inline uint32_t hsi_accel_get_opcode(void) {
    return hsi_accel_read_reg(HSI_ACCEL_OPCODE_OFFSET);
}

static inline void hsi_accel_set_num_bands(uint32_t nb) {
    hsi_accel_write_reg(HSI_ACCEL_NUM_BANDS_OFFSET, nb);
}
static inline uint32_t hsi_accel_get_num_bands(void) {
    return hsi_accel_read_reg(HSI_ACCEL_NUM_BANDS_OFFSET);
}

/* COMMAND */
static inline void hsi_accel_start(void) {
    hsi_accel_write_reg(HSI_ACCEL_COMMAND_OFFSET, 1u << HSI_ACCEL_CMD_START_BIT);
}
static inline void hsi_accel_clear_done(void) {
    hsi_accel_write_reg(HSI_ACCEL_COMMAND_OFFSET, 1u << HSI_ACCEL_CMD_CLEAR_DONE_BIT);
}
static inline void hsi_accel_clear_error(void) {
    hsi_accel_write_reg(HSI_ACCEL_COMMAND_OFFSET, 1u << HSI_ACCEL_CMD_CLEAR_ERROR_BIT);
}

/* STATUS */
static inline uint32_t hsi_accel_get_status(void) {
    return hsi_accel_read_reg(HSI_ACCEL_STATUS_OFFSET);
}
static inline bool hsi_accel_is_done(void) {
    return (hsi_accel_get_status() >> HSI_ACCEL_STATUS_DONE_BIT) & 1;
}
static inline uint32_t hsi_accel_get_error(void) {
    return (hsi_accel_get_status() & HSI_ACCEL_STATUS_ERROR_MASK) >> HSI_ACCEL_STATUS_ERROR_SHIFT;
}
static inline bool hsi_accel_is_busy(void) {
    return (hsi_accel_get_status() >> HSI_ACCEL_STATUS_BUSY_BIT) & 1;
}

#endif /* HSI_ACCEL_REGS_H */
