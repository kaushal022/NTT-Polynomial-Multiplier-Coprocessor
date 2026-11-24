#include <stdint.h>

#define COPROC_BASE       0x40000000U
#define COPROC_CONTROL    (*(volatile uint32_t *)(COPROC_BASE + 0x00U))
#define COPROC_STATUS     (*(volatile uint32_t *)(COPROC_BASE + 0x04U))
#define COPROC_CYCLES     (*(volatile uint32_t *)(COPROC_BASE + 0x08U))

#define DMA_CTRL          (*(volatile uint32_t *)(COPROC_BASE + 0x20U))
#define DMA_STATUS        (*(volatile uint32_t *)(COPROC_BASE + 0x24U))
#define DMA_MEM_ADDR      (*(volatile uint32_t *)(COPROC_BASE + 0x28U))
#define DMA_XFER_COUNT    (*(volatile uint32_t *)(COPROC_BASE + 0x2CU))

#define IRQ_IER           (*(volatile uint32_t *)(COPROC_BASE + 0x30U))
#define IRQ_ISR_ICR       (*(volatile uint32_t *)(COPROC_BASE + 0x34U))
#define IRQ_STATE         (*(volatile uint32_t *)(COPROC_BASE + 0x38U))

#define CTRL_START        (1U << 0)
#define CTRL_IE           (1U << 1)
#define CTRL_SOFT_RST     (1U << 2)
#define STAT_DONE         (1U << 1)

#define DMA_CMD_LOAD_F    ((0U << 2) | (0U << 1) | 1U)
#define DMA_CMD_LOAD_G    ((1U << 2) | (0U << 1) | 1U)
#define DMA_CMD_STORE_H   ((2U << 2) | (1U << 1) | 1U)
#define DMA_STAT_BUSY     (1U << 0)
#define DMA_STAT_DONE     (1U << 1)

#define IRQ_SRC_COPROC    (1U << 0)
#define IRQ_SRC_DMA       (1U << 1)

#define UART_DIV          (*(volatile uint32_t *)0x40010004U)
#define UART_DAT          (*(volatile uint32_t *)0x40010008U)

#define MB_BASE           0x40020000U
#define MB_MAGIC          (*(volatile uint32_t *)(MB_BASE + 0x000U))
#define MB_CMD            (*(volatile uint32_t *)(MB_BASE + 0x004U))
#define MB_RESP_STATUS    (*(volatile uint32_t *)(MB_BASE + 0x008U))
#define MB_CYCLES         (*(volatile uint32_t *)(MB_BASE + 0x00CU))
#define MB_HEARTBEAT      (*(volatile uint32_t *)(MB_BASE + 0x010U))
#define MB_RV_ACK         (*(volatile uint32_t *)(MB_BASE + 0x014U))

#define MB_F_BUF          ((volatile uint32_t *)(MB_BASE + 0x100U))
#define MB_G_BUF          ((volatile uint32_t *)(MB_BASE + 0x500U))
#define MB_H_BUF          ((volatile uint32_t *)(MB_BASE + 0x900U))

#define MB_CMD_REQ        (1U << 0)
#define MB_CMD_UART_OK    (1U << 1)

#define MB_ST_RESP_READY  (1U << 0)
#define MB_ST_RV_RUNNING  (1U << 1)
#define MB_ST_DMA_DONE    (1U << 2)
#define MB_ST_COPROC_DONE (1U << 3)
#define MB_ST_IRQ_RECV    (1U << 4)
#define MB_ST_UART_OK     (1U << 5)

#define N_COEFF           256U

static volatile uint32_t dma_f_buf[N_COEFF];
static volatile uint32_t dma_g_buf[N_COEFF];
static volatile uint32_t dma_h_buf[N_COEFF];

static volatile uint32_t g_irq_received = 0;
static volatile uint32_t g_irq_cycles   = 0;

void irq_handler(void) {
    uint32_t pending = IRQ_ISR_ICR;

    if (pending & IRQ_SRC_COPROC) {
        g_irq_cycles   = COPROC_CYCLES & 0xFFFFU;
        g_irq_received = 1U;

        IRQ_ISR_ICR    = IRQ_SRC_COPROC;
        COPROC_STATUS  = STAT_DONE;
        COPROC_CONTROL = 0U;
    } else if (pending != 0U) {
        IRQ_ISR_ICR = pending;
    }
}

static void run_dma_transfer(uint32_t mem_addr, uint32_t ctrl_cmd) {
    DMA_STATUS   = DMA_STAT_DONE;
    DMA_MEM_ADDR = mem_addr;
    DMA_CTRL     = ctrl_cmd;

    while ((DMA_STATUS & DMA_STAT_DONE) == 0U) {
    }
    DMA_STATUS = DMA_STAT_DONE;
}

int main(void) {
    uint32_t hb_counter = 0U;

    COPROC_CONTROL = CTRL_SOFT_RST;
    COPROC_CONTROL = 0U;
    COPROC_STATUS  = STAT_DONE;
    IRQ_ISR_ICR    = 0x7U;
    IRQ_IER        = IRQ_SRC_COPROC;

    MB_HEARTBEAT   = 0xCAFE0000U;
    MB_RESP_STATUS = MB_ST_RV_RUNNING;

    while (1) {
        uint32_t cmd = MB_CMD;
        if ((cmd & MB_CMD_REQ) == 0U) {
            hb_counter++;
            if ((hb_counter & 0x3FFU) == 0U) {
                MB_HEARTBEAT = 0xCAFE0000U | ((hb_counter >> 10) & 0xFFFFU);
            }
            continue;
        }

        uint32_t seq_id  = (cmd >> 16) & 0xFFFFU;
        uint32_t uart_ok = (cmd & MB_CMD_UART_OK) ? MB_ST_UART_OK : 0U;

        MB_RESP_STATUS = MB_ST_RV_RUNNING | uart_ok;

        MB_RV_ACK = 1U;

        for (uint32_t i = 0U; i < N_COEFF; i++) {
            dma_f_buf[i] = MB_F_BUF[i] & 0x0FFFU;
            dma_g_buf[i] = MB_G_BUF[i] & 0x0FFFU;
        }

        run_dma_transfer((uint32_t)dma_f_buf, DMA_CMD_LOAD_F);
        run_dma_transfer((uint32_t)dma_g_buf, DMA_CMD_LOAD_G);

        g_irq_received = 0U;
        g_irq_cycles   = 0U;
        IRQ_ISR_ICR    = 0x7U;
        IRQ_IER        = IRQ_SRC_COPROC;
        COPROC_STATUS  = STAT_DONE;
        COPROC_CONTROL = CTRL_START | CTRL_IE;

        while (g_irq_received == 0U) {
        }

        run_dma_transfer((uint32_t)dma_h_buf, DMA_CMD_STORE_H);

        for (uint32_t i = 0U; i < N_COEFF; i++) {
            MB_H_BUF[i] = dma_h_buf[i] & 0x0FFFU;
        }
        MB_CYCLES      = g_irq_cycles;
        MB_HEARTBEAT   = 0xCAFE0000U | seq_id;
        MB_RESP_STATUS = MB_ST_RESP_READY |
                         MB_ST_RV_RUNNING |
                         MB_ST_DMA_DONE   |
                         MB_ST_COPROC_DONE|
                         MB_ST_IRQ_RECV   |
                         uart_ok;
    }

    return 0;
}
