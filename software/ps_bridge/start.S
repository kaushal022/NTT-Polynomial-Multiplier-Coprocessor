.section .text.boot, "ax"
.global _start
.syntax unified
.arm

_start:
    cpsid   if
    ldr     sp, =_stack_top

    ldr     r0, =_sbss
    ldr     r1, =_ebss
    mov     r2, #0
bss_clear_loop:
    cmp     r0, r1
    bhs     bss_clear_done
    str     r2, [r0], #4
    b       bss_clear_loop
bss_clear_done:

    bl      main

halt_loop:
    wfi
    b       halt_loop
