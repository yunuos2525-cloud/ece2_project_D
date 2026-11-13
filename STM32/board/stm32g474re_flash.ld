ENTRY(Reset_Handler)

MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 96K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);

PHDRS
{
    flash PT_LOAD FLAGS(5);
    ram PT_LOAD FLAGS(6);
}

SECTIONS
{
    .isr_vector : { KEEP(*(.isr_vector)) } > FLASH :flash
    .text :
    {
        *(.text .text.* .rodata .rodata.*)
        KEEP(*(.init))
        KEEP(*(.fini))
    } > FLASH
    .ARM.extab : { *(.ARM.extab* .gnu.linkonce.armextab.*) } > FLASH
    .ARM.exidx :
    {
        __exidx_start = .;
        *(.ARM.exidx* .gnu.linkonce.armexidx.*)
        __exidx_end = .;
    } > FLASH
    .preinit_array : ALIGN(4)
    {
        PROVIDE_HIDDEN(__preinit_array_start = .);
        KEEP(*(.preinit_array .preinit_array.*))
        PROVIDE_HIDDEN(__preinit_array_end = .);
    } > FLASH
    .init_array : ALIGN(4)
    {
        PROVIDE_HIDDEN(__init_array_start = .);
        KEEP(*(SORT_BY_INIT_PRIORITY(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE_HIDDEN(__init_array_end = .);
    } > FLASH
    .fini_array : ALIGN(4)
    {
        PROVIDE_HIDDEN(__fini_array_start = .);
        KEEP(*(SORT_BY_INIT_PRIORITY(.fini_array.*)))
        KEEP(*(.fini_array))
        PROVIDE_HIDDEN(__fini_array_end = .);
    } > FLASH

    _sidata = LOADADDR(.data);
    .data : ALIGN(4)
    {
        _sdata = .;
        *(.data .data.* .RamFunc .RamFunc.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM AT > FLASH :ram
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;
        *(.bss .bss.* COMMON)
        . = ALIGN(8);
        _ebss = .;
    } > RAM
    PROVIDE(end = _ebss);
    PROVIDE(_end = _ebss);
    ASSERT(_ebss + 2048 <= _estack, "Insufficient SRAM for the stack")
}
