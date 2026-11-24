#include <stdint.h>

#define MLKEM_BASE      0x40000000UL
#define UART_BASE       0x40010000UL

#define MLKEM_CONTROL   (*(volatile uint32_t *)(MLKEM_BASE + 0x00))
#define MLKEM_STATUS    (*(volatile uint32_t *)(MLKEM_BASE + 0x04))
#define MLKEM_CYCLES    (*(volatile uint32_t *)(MLKEM_BASE + 0x08))
#define MLKEM_ADDR_PTR  (*(volatile uint32_t *)(MLKEM_BASE + 0x0C))
#define MLKEM_COEFF_F   (*(volatile uint32_t *)(MLKEM_BASE + 0x10))
#define MLKEM_COEFF_G   (*(volatile uint32_t *)(MLKEM_BASE + 0x14))
#define MLKEM_COEFF_OUT (*(volatile uint32_t *)(MLKEM_BASE + 0x18))
#define MLKEM_VERSION   (*(volatile uint32_t *)(MLKEM_BASE + 0x1C))

#define CTRL_START      (1u << 0)
#define CTRL_IE         (1u << 1)
#define CTRL_SOFT_RST   (1u << 2)

#define STAT_DONE       (1u << 1)

#define UART_DIV        (*(volatile uint32_t *)(UART_BASE + 0x04))
#define UART_DATA       (*(volatile uint32_t *)(UART_BASE + 0x08))

#define POLY_N          256u
#define PROTO_MAGIC0    0xA5u
#define PROTO_MAGIC1    0x5Au

/* Dynamic vector slot populated inside firmware.hex at 0x00002000..0x00002C0F */
#define TV_SLOT_ADDR    0x00002000UL
#define TV_MAGIC        0x54563031UL
#define TV_FLAG_VERIFY  (1u << 0)

typedef struct {
    uint32_t magic;
    uint32_t count;
    uint32_t flags;
    uint32_t reserved;
    uint32_t f[POLY_N];
    uint32_t g[POLY_N];
    uint32_t h[POLY_N];
} tv_slot_t;

#define TV_SLOT ((const volatile tv_slot_t *)TV_SLOT_ADDR)

static volatile int irq_done_flag = 0;

void irq_handler(void)
{
    irq_done_flag = 1;
    MLKEM_CONTROL = 0;
}

static inline uint32_t rdcycle(void)
{
    uint32_t c;
    __asm__ volatile (
        ".option push\n"
        ".option arch, +zicsr\n"
        "rdcycle %0\n"
        ".option pop\n"
        : "=r"(c)
    );
    return c;
}

static void delay_cycles(uint32_t cycles)
{
    uint32_t start = rdcycle();
    while ((uint32_t)(rdcycle() - start) < cycles) {}
}

static void uart_tx_byte(uint8_t b)
{
    UART_DATA = (uint32_t)b;
    /* simpleuart drops writes made while send_bitcnt != 0 (~8680 cyc @ 115200 baud) */
    delay_cycles(9200u);
}

static uint8_t uart_rx_byte(void)
{
    uint32_t v;
    do {
        v = UART_DATA;
    } while (v == 0xFFFFFFFFUL);
    return (uint8_t)(v & 0xFFu);
}

static void mlkem_soft_reset(void)
{
    MLKEM_CONTROL = CTRL_SOFT_RST;
    (void)MLKEM_STATUS;
    MLKEM_CONTROL = 0;
}

static void mlkem_execute(void)
{
    irq_done_flag = 0;
    MLKEM_CONTROL = CTRL_START | CTRL_IE;
    while (!irq_done_flag && !(MLKEM_STATUS & STAT_DONE)) {}
}

static void bram_load_poly(volatile uint32_t *dst_reg, const volatile uint32_t *src)
{
    uint32_t i;
    MLKEM_ADDR_PTR = 0;
    for (i = 0; i < POLY_N; i++) {
        *dst_reg = src[i] & 0x0FFFu;
    }
}

static void uart_rx_poly(volatile uint32_t *dst_reg)
{
    uint32_t i;
    MLKEM_ADDR_PTR = 0;
    for (i = 0; i < POLY_N; i++) {
        uint32_t lo = uart_rx_byte();
        uint32_t hi = uart_rx_byte();
        *dst_reg = ((hi & 0x0Fu) << 8) | lo;
    }
}

static int run_bram_test(void)
{
    const volatile tv_slot_t *tv = TV_SLOT;
    uint32_t i;
    int mismatches = 0;

    if (tv->magic != TV_MAGIC || tv->count != POLY_N) {
        return 0;
    }

    mlkem_soft_reset();
    bram_load_poly(&MLKEM_COEFF_F, tv->f);
    bram_load_poly(&MLKEM_COEFF_G, tv->g);
    mlkem_execute();

    MLKEM_ADDR_PTR = 0;
    for (i = 0; i < POLY_N; i++) {
        uint16_t val = (uint16_t)(MLKEM_COEFF_OUT & 0x0FFFu);
        if ((tv->flags & TV_FLAG_VERIFY) && val != (uint16_t)(tv->h[i] & 0x0FFFu)) {
            mismatches++;
        }
    }

    return mismatches;
}

static void service_uart_packet(void)
{
    uint8_t b = uart_rx_byte();
    uint32_t i;
    uint32_t cycles;

    while (b == PROTO_MAGIC0) {
        b = uart_rx_byte();
    }
    if (b != PROTO_MAGIC1) {
        return;
    }

    mlkem_soft_reset();
    uart_rx_poly(&MLKEM_COEFF_F);
    uart_rx_poly(&MLKEM_COEFF_G);
    mlkem_execute();

    cycles = MLKEM_CYCLES;
    MLKEM_ADDR_PTR = 0;
    for (i = 0; i < POLY_N; i++) {
        uint16_t val = (uint16_t)(MLKEM_COEFF_OUT & 0x0FFFu);
        uart_tx_byte((uint8_t)(val & 0xFFu));
        uart_tx_byte((uint8_t)(val >> 8));
    }

    uart_tx_byte((uint8_t)(cycles & 0xFFu));
    uart_tx_byte((uint8_t)((cycles >> 8) & 0xFFu));
    uart_tx_byte((uint8_t)((cycles >> 16) & 0xFFu));
    uart_tx_byte((uint8_t)((cycles >> 24) & 0xFFu));
    uart_tx_byte(0x00u);
}

int main(void)
{
    uint32_t idle_ticks = 0;

    UART_DIV = 866;
    /* Wait out simpleuart 15-bit dummy TX frame triggered by divider write */
    delay_cycles(14000u);

    if (MLKEM_VERSION != 0x4D4C4B31UL) {
        uart_tx_byte(0xEEu);
        while (1) {}
    }

    if (run_bram_test() > 0) {
        uart_tx_byte(0xEEu);
        __asm__ volatile ("ebreak");
    }

    while (1) {
        uint32_t rx = UART_DATA;
        if (rx != 0xFFFFFFFFUL) {
            if ((uint8_t)(rx & 0xFFu) == PROTO_MAGIC0) {
                service_uart_packet();
            }
            idle_ticks = 0;
            continue;
        }

        if (++idle_ticks >= 15000000u) {
            idle_ticks = 0;
            if (run_bram_test() > 0) {
                uart_tx_byte(0xEEu);
                __asm__ volatile ("ebreak");
            }
        }
    }

    return 0;
}
