/*=====================================================================
 *  start.S -- Reset vector cho ISR demo (PicoRV32 / Tang Nano 4K)
 *
 *  picorv32 duoc cau hinh PROGADDR_RESET = 0x0000_0000, nen nhan
 *  _start BAT BUOC phai nam o dia chi 0. Section .text.start duoc
 *  link.ld dat len dau tien de bao dam dieu do.
 *
 *  .option norvc: chan tuyet doi lenh nen 16-bit. isr_decoder lam viec
 *  theo word 32-bit -- chi can mot lenh nen la toan bo can chinh
 *  giai ma hong.
 *===================================================================*/

    .option norvc
    .option nopic

/*---------------------------------------------------------------------
 *  Reset vector -- PHAI o 0x00000000
 *-------------------------------------------------------------------*/
    .section .text.start, "ax"
    .global _start
    .type   _start, @function

_start:
    /* 1. Stack pointer -> dinh RAM (0x2000) */
    la      sp, _stack_top

    /* 2. Xoa .bss (linker khong nap vung nay vao .bin) */
    la      t0, _sbss
    la      t1, _ebss
1:  bgeu    t0, t1, 2f
    sw      zero, 0(t0)
    addi    t0, t0, 4
    j       1b
2:

    /* 3. Khong can copy .data: LMA == VMA, chuong trinh chay thang
     *    tu RAM da duoc $readmemh khoi tao san.                     */

    /* 4. Vao main */
    call    main

    /* main khong bao gio return. Neu co thi treo tai cho -- watchdog
     * trong isr_top se tat LED sau ~1.24 s.                         */
3:  j       3b

    .size _start, .-_start


/*---------------------------------------------------------------------
 *  delay_loops(uint32_t n) -- vong lap tre CHINH XAC 11 chu ky/vong
 *
 *  Viet bang assembly de trinh bien dich khong toi uu mat, va de
 *  so chu ky la mot con so co dinh, do duoc.
 *
 *  Con so 11 chu ky/vong DA DUOC DO bang mo phong iverilog voi:
 *      - picorv32 cau hinh nhu trong isr_top.v
 *      - isr_ram tra ready sau 2 chu ky moi lan truy cap
 *  Do tuyen tinh: 30 vong -> 346 ck, 130 vong -> 1446 ck,
 *                 230 vong -> 2546 ck   =>  (2546-346)/200 = 11.0
 *
 *  Neu ban doi RAM (vd dung look-ahead de con 1 chu ky/truy cap) thi
 *  con so nay se doi -- sua CYCLES_PER_LOOP trong main.c cho khop.
 *-------------------------------------------------------------------*/
    .section .text, "ax"
    .global delay_loops
    .type   delay_loops, @function

delay_loops:
    beq     a0, zero, 2f
1:  addi    a0, a0, -1          /* 2 lenh nay = 11 chu ky */
    bne     a0, zero, 1b
2:  ret

    .size delay_loops, .-delay_loops
