#ifndef MLKEM_COPROCESSOR_H
#define MLKEM_COPROCESSOR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MLKEM_N 256
#define MLKEM_Q 3329

#define MLKEM_REG_CONTROL    0x00
#define MLKEM_REG_STATUS     0x04
#define MLKEM_REG_CYCLES     0x08
#define MLKEM_REG_ADDR_PTR   0x0C
#define MLKEM_REG_COEFF_F    0x10
#define MLKEM_REG_COEFF_G    0x14
#define MLKEM_REG_COEFF_OUT  0x18
#define MLKEM_REG_VERSION    0x1C

#define MLKEM_CTRL_START     (1U << 0)
#define MLKEM_CTRL_IE        (1U << 1)
#define MLKEM_CTRL_RESET     (1U << 2)

#define MLKEM_STATUS_BUSY    (1U << 0)
#define MLKEM_STATUS_DONE    (1U << 1)
#define MLKEM_STATUS_IRQ     (1U << 2)

#define MLKEM_VERSION_MAGIC  0x4D4C4B31

void mlkem_coproc_init(uintptr_t base_addr);

uint32_t mlkem_coproc_get_version(void);

void mlkem_coproc_reset(void);

void mlkem_coproc_load_f(const uint16_t *poly_f);

void mlkem_coproc_load_g(const uint16_t *poly_g);

void mlkem_coproc_start(int enable_irq);

int mlkem_coproc_is_busy(void);

void mlkem_coproc_wait_done(void);

uint32_t mlkem_coproc_get_cycles(void);

void mlkem_coproc_read_h(uint16_t *poly_h);

uint32_t mlkem_coproc_polymul(const uint16_t *poly_f, const uint16_t *poly_g, uint16_t *poly_h);

#ifdef __cplusplus
}
#endif

#endif
