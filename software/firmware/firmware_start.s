.section .text.reset
.global _start
_start:
    j      _startup

    .word  0
    .word  0
    .word  0

.section .text.irq
.global _irq_vector
_irq_vector:
    addi   sp, sp, -64
    sw     ra,   0(sp)
    sw     t0,   4(sp)
    sw     t1,   8(sp)
    sw     t2,  12(sp)
    sw     a0,  16(sp)
    sw     a1,  20(sp)
    sw     a2,  24(sp)
    sw     a3,  28(sp)
    sw     a4,  32(sp)
    sw     a5,  36(sp)
    sw     a6,  40(sp)
    sw     a7,  44(sp)
    sw     t3,  48(sp)
    sw     t4,  52(sp)
    sw     t5,  56(sp)
    sw     t6,  60(sp)

    call   irq_handler

    lw     ra,   0(sp)
    lw     t0,   4(sp)
    lw     t1,   8(sp)
    lw     t2,  12(sp)
    lw     a0,  16(sp)
    lw     a1,  20(sp)
    lw     a2,  24(sp)
    lw     a3,  28(sp)
    lw     a4,  32(sp)
    lw     a5,  36(sp)
    lw     a6,  40(sp)
    lw     a7,  44(sp)
    lw     t3,  48(sp)
    lw     t4,  52(sp)
    lw     t5,  56(sp)
    lw     t6,  60(sp)
    addi   sp, sp, 64

    .word  0x0400000b

.section .text
_startup:
    la     sp, _stack_top

    la     a0, _sbss
    la     a1, _ebss
    bge    a0, a1, _bss_done
_bss_loop:
    sw     zero, 0(a0)
    addi   a0, a0, 4
    blt    a0, a1, _bss_loop
_bss_done:
    li     a0, -2
    .word  0x0605000b

    call   main

_halt:
    j      _halt
