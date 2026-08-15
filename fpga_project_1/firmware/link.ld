/*=====================================================================
 *  link.ld -- Linker script cho ISR demo (PicoRV32 / Tang Nano 4K)
 *
 *  Khop voi isr_top.v:
 *      PROGADDR_RESET = 0x0000_0000
 *      STACKADDR      = 0x0000_2000
 *      RAM_AW = 11  ->  2048 word  =  8 KB
 *===================================================================*/

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* Toan bo .text + .rodata + .data + .bss + stack deu nam trong
       cung 8 KB BSRAM nay. */
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 8K
}

SECTIONS
{
    /*=================================================================
     *  .text -- CO SHF_EXECINSTR  =>  isr_encoder.py SE MA HOA
     *=================================================================*/
    .text : ALIGN(4)
    {
        KEEP(*(.text.start))        /* _start PHAI o dia chi 0x0 */
        *(.text .text.*)
        . = ALIGN(4);
    } > RAM
    _etext = .;

    /*=================================================================
     *  .rodata -- CHI CO SHF_ALLOC, KHONG co SHF_EXECINSTR
     *             =>  isr_encoder.py KHONG ma hoa
     *
     *  !!! DUNG GOP .rodata VAO TRONG .text !!!
     *
     *  Ly do: isr_decoder chi giai ma khi mem_instr = 1 (CPU fetch
     *  lenh). Hang so doc bang lw co mem_instr = 0 nen di THANG,
     *  khong qua giai ma. Neu .rodata bi ma hoa thi chuong trinh se
     *  doc ra rac -- ma van chay, khong trap, rat kho tim ra loi.
     *=================================================================*/
    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
    } > RAM

    /*=================================================================
     *  .data -- LMA == VMA, khong can copy luc khoi dong
     *=================================================================*/
    .data : ALIGN(4)
    {
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    /*=================================================================
     *  .bss -- NOLOAD: khong nam trong .bin, start.S tu xoa ve 0
     *=================================================================*/
    .bss (NOLOAD) : ALIGN(4)
    {
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack moc tu dinh RAM di xuong -- khop STACKADDR trong isr_top.v */
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);     /* = 0x00002000 */

    /* Canh bao neu code + du lieu tran ra ngoai 8 KB */
    ASSERT(_ebss <= ORIGIN(RAM) + LENGTH(RAM) - 256,
           "LOI: firmware + .bss chiem het RAM, khong con cho cho stack!")

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
    }
}
