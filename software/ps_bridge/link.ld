ENTRY(_start)

MEMORY
{
    OCM_HIGH (rwx) : ORIGIN = 0xFFFF0000, LENGTH = 0x0000FE00
}

SECTIONS
{
    .text : {
        KEEP(*(.text.boot))
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(8);
    } > OCM_HIGH

    .data : {
        . = ALIGN(8);
        _sdata = .;
        *(.data .data.*)
        . = ALIGN(8);
        _edata = .;
    } > OCM_HIGH

    .bss (NOLOAD) : {
        . = ALIGN(8);
        _sbss = .;
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(8);
        _ebss = .;
    } > OCM_HIGH

    _stack_top = 0xFFFFFE00;

    /DISCARD/ : {
        *(.ARM.exidx* .ARM.extab*)
    }
}
