#include "mlkem_coprocessor.h"

static volatile uintptr_t s_coproc_base = 0;

#define REG32(offset) (*((volatile uint32_t *)(s_coproc_base + (offset))))

void mlkem_coproc_init(uintptr_t base_addr) {
    s_coproc_base = base_addr;
}

uint32_t mlkem_coproc_get_version(void) {
    return REG32(MLKEM_REG_VERSION);
}

void mlkem_coproc_reset(void) {
    REG32(MLKEM_REG_CONTROL) = MLKEM_CTRL_RESET;
}

void mlkem_coproc_load_f(const uint16_t *poly_f) {
    REG32(MLKEM_REG_ADDR_PTR) = 0;
    for (int i = 0; i < MLKEM_N; i++) {
        REG32(MLKEM_REG_COEFF_F) = (uint32_t)(poly_f[i] & 0x0FFF);
    }
}

void mlkem_coproc_load_g(const uint16_t *poly_g) {
    REG32(MLKEM_REG_ADDR_PTR) = 0;
    for (int i = 0; i < MLKEM_N; i++) {
        REG32(MLKEM_REG_COEFF_G) = (uint32_t)(poly_g[i] & 0x0FFF);
    }
}

void mlkem_coproc_start(int enable_irq) {
    uint32_t ctrl = MLKEM_CTRL_START;
    if (enable_irq) {
        ctrl |= MLKEM_CTRL_IE;
    }
    REG32(MLKEM_REG_CONTROL) = ctrl;
}

int mlkem_coproc_is_busy(void) {
    return (REG32(MLKEM_REG_STATUS) & MLKEM_STATUS_BUSY) ? 1 : 0;
}

void mlkem_coproc_wait_done(void) {
    while (mlkem_coproc_is_busy()) {
    }
}

uint32_t mlkem_coproc_get_cycles(void) {
    return (REG32(MLKEM_REG_CYCLES) & 0xFFFF);
}

void mlkem_coproc_read_h(uint16_t *poly_h) {
    for (int i = 0; i < MLKEM_N; i++) {
        REG32(MLKEM_REG_ADDR_PTR) = (uint32_t)i;
        poly_h[i] = (uint16_t)(REG32(MLKEM_REG_COEFF_OUT) & 0x0FFF);
    }
}

uint32_t mlkem_coproc_polymul(const uint16_t *poly_f, const uint16_t *poly_g, uint16_t *poly_h) {
    mlkem_coproc_load_f(poly_f);
    mlkem_coproc_load_g(poly_g);
    mlkem_coproc_start(0);
    mlkem_coproc_wait_done();
    mlkem_coproc_read_h(poly_h);
    return mlkem_coproc_get_cycles();
}
