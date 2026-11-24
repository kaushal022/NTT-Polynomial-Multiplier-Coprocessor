MEMORY
{
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    .text.reset 0x00000000 :
    {
        KEEP(*(.text.reset))
    } > BRAM

    .text.irq 0x00000010 :
    {
        KEEP(*(.text.irq))
    } > BRAM

    .text :
    {
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
        _etext = .;
    } > BRAM

    .data :
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > BRAM

    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > BRAM

    ASSERT(_ebss <= 0x00002000, "Firmware exceeds 8KB slot before 0x2000 vector table")
    _vec_table_base = 0x00002000;
    _stack_top = 0x00008000;
}
