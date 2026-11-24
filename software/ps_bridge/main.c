#include <stdint.h>

#define UART1_BASE        0xE0001000U
#define UART1_CR          (*(volatile uint32_t *)(UART1_BASE + 0x00U))
#define UART1_MR          (*(volatile uint32_t *)(UART1_BASE + 0x04U))
#define UART1_IER         (*(volatile uint32_t *)(UART1_BASE + 0x08U))
#define UART1_IDR         (*(volatile uint32_t *)(UART1_BASE + 0x0CU))
#define UART1_BAUDGEN     (*(volatile uint32_t *)(UART1_BASE + 0x18U))
#define UART1_RXTOUT      (*(volatile uint32_t *)(UART1_BASE + 0x1CU))
#define UART1_RXWM        (*(volatile uint32_t *)(UART1_BASE + 0x20U))
#define UART1_SR          (*(volatile uint32_t *)(UART1_BASE + 0x2CU))
#define UART1_FIFO        (*(volatile uint32_t *)(UART1_BASE + 0x30U))
#define UART1_BAUDDIV     (*(volatile uint32_t *)(UART1_BASE + 0x34U))

#define UART_SR_RXEMPTY   (1U << 1)
#define UART_SR_TXEMPTY   (1U << 3)
#define UART_SR_TXFULL    (1U << 4)

#ifndef AXI_MAILBOX_BASE
#define AXI_MAILBOX_BASE  0x43C00000U
#endif

#define MB_MAGIC          (*(volatile uint32_t *)(AXI_MAILBOX_BASE + 0x000U))
#define MB_CMD            (*(volatile uint32_t *)(AXI_MAILBOX_BASE + 0x004U))
#define MB_RESP_STATUS    (*(volatile uint32_t *)(AXI_MAILBOX_BASE + 0x008U))
#define MB_CYCLES         (*(volatile uint32_t *)(AXI_MAILBOX_BASE + 0x00CU))
#define MB_HEARTBEAT      (*(volatile uint32_t *)(AXI_MAILBOX_BASE + 0x010U))

#define MB_F_BUF          ((volatile uint32_t *)(AXI_MAILBOX_BASE + 0x100U))
#define MB_G_BUF          ((volatile uint32_t *)(AXI_MAILBOX_BASE + 0x500U))
#define MB_H_BUF          ((volatile uint32_t *)(AXI_MAILBOX_BASE + 0x900U))

#define MB_CMD_REQ        (1U << 0)
#define MB_CMD_UART_OK    (1U << 1)
#define MB_ST_RESP_READY  (1U << 0)
#define MB_ST_RV_RUNNING  (1U << 1)

#define N_COEFF           256U

static inline void dsb_barrier(void) {
    __asm__ volatile ("dsb" ::: "memory");
}

static void uart1_init_115200(void) {
    UART1_IDR = 0xFFFFFFFFU;
    UART1_CR = 0x00000003U;
    while ((UART1_CR & 0x00000003U) != 0U) {
    }
    UART1_MR      = 0x00000020U;
    UART1_BAUDGEN = 124U;
    UART1_BAUDDIV = 6U;
    UART1_RXWM    = 1U;
    UART1_RXTOUT  = 0U;
    UART1_CR      = 0x00000114U;
}

static uint8_t uart1_rx_byte(void) {
    while ((UART1_SR & UART_SR_RXEMPTY) != 0U) {
    }
    return (uint8_t)(UART1_FIFO & 0xFFU);
}

static void uart1_tx_byte(uint8_t b) {
    while ((UART1_SR & UART_SR_TXFULL) != 0U) {
    }
    UART1_FIFO = (uint32_t)b;
}

static void uart1_tx_flush(void) {
    while ((UART1_SR & UART_SR_TXEMPTY) == 0U) {
    }
}

static uint16_t uart1_rx_u16_le(void) {
    uint16_t lo = (uint16_t)uart1_rx_byte();
    uint16_t hi = (uint16_t)uart1_rx_byte();
    return (uint16_t)(lo | (hi << 8));
}

static void uart1_tx_u16_le(uint16_t v) {
    uart1_tx_byte((uint8_t)(v & 0xFFU));
    uart1_tx_byte((uint8_t)((v >> 8) & 0xFFU));
}

static void uart1_tx_u32_le(uint32_t v) {
    uart1_tx_byte((uint8_t)(v & 0xFFU));
    uart1_tx_byte((uint8_t)((v >> 8) & 0xFFU));
    uart1_tx_byte((uint8_t)((v >> 16) & 0xFFU));
    uart1_tx_byte((uint8_t)((v >> 24) & 0xFFU));
}

int main(void) {
    uint16_t f_local[N_COEFF];
    uint16_t g_local[N_COEFF];
    uint16_t seq_id = 0U;

    uart1_init_115200();

    while (MB_MAGIC != 0x4D4C4B4DU) {
    }

    while (1) {
        while (uart1_rx_byte() != 0xA5U) {
        }
        if (uart1_rx_byte() != 0x5AU) {
            continue;
        }

        for (uint32_t i = 0U; i < N_COEFF; i++) {
            f_local[i] = uart1_rx_u16_le();
        }
        for (uint32_t i = 0U; i < N_COEFF; i++) {
            g_local[i] = uart1_rx_u16_le();
        }

        seq_id++;

        MB_RESP_STATUS = 0U;
        for (uint32_t i = 0U; i < N_COEFF; i++) {
            MB_F_BUF[i] = (uint32_t)(f_local[i] & 0x0FFFU);
            MB_G_BUF[i] = (uint32_t)(g_local[i] & 0x0FFFU);
        }
        dsb_barrier();
        MB_CMD = (((uint32_t)seq_id) << 16) | MB_CMD_UART_OK | MB_CMD_REQ;
        dsb_barrier();

        uint32_t timeout = 0U;
        uint32_t resp_st = 0U;
        while (1) {
            resp_st = MB_RESP_STATUS;
            if ((resp_st & MB_ST_RESP_READY) != 0U) {
                break;
            }
            if (++timeout > 20000000U) {
                break;
            }
        }

        uint32_t hw_cycles = MB_CYCLES;
        for (uint32_t i = 0U; i < N_COEFF; i++) {
            uint16_t coeff = (uint16_t)(MB_H_BUF[i] & 0x0FFFU);
            uart1_tx_u16_le(coeff);
        }
        uart1_tx_u32_le(hw_cycles);
        uart1_tx_byte((uint8_t)(resp_st & 0xFFU));
        uart1_tx_flush();
    }

    return 0;
}
