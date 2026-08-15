

#include <stdint.h>

#define LED_REG         (*(volatile uint32_t *)0x02000000u)
#define UART_TX_REG     (*(volatile uint32_t *)0x02000010u)
#define UART_ST_REG     (*(volatile uint32_t *)0x02000014u)

#define UART_BUSY_BIT   0x1u

#define CPU_HZ          27000000u
#define CYCLES_PER_LOOP 11u              /* do bang iverilog */

#ifndef HALF_PERIOD_MS
#define HALF_PERIOD_MS  500u             /* < 1240 (gioi han watchdog) */
#endif

#ifndef DELAY_LOOPS
#define DELAY_LOOPS     (((CPU_HZ / 1000u) * HALF_PERIOD_MS) / CYCLES_PER_LOOP)
#endif

extern void delay_loops(uint32_t n);


/*---------------------------------------------------------------------
 *  UART
 *-------------------------------------------------------------------*/
static void uart_putc(char c)
{
    while (UART_ST_REG & UART_BUSY_BIT) {
        /* doi phan cung gui xong byte truoc */
    }
    UART_TX_REG = (uint32_t)(unsigned char)c;
}

static void uart_puts(const char *s)
{
    while (*s) {
        uart_putc(*s++);
    }
}

/* Giu lai de dung sau nay (in so hex). Hien chua goi toi nen danh dau
 * unused cho khoi bi -Wall -Wextra canh bao; --gc-sections se loai bo. */
static void uart_put_hex32(uint32_t v) __attribute__((unused));
static void uart_put_hex32(uint32_t v)
{
    static const char HEX[] = "0123456789ABCDEF";
    int i;
    for (i = 28; i >= 0; i -= 4) {
        uart_putc(HEX[(v >> i) & 0xFu]);
    }
}


int main(void)
{
    uint32_t on = 1u;

    uart_puts("\r\n");
    uart_puts("=====================================\r\n");
    uart_puts("  ISR-RV32\r\n");
    uart_puts("  PicoRV32 + Instruction Set Random.\r\n");
    uart_puts("=====================================\r\n");
    uart_puts("Giai ma lenh THANH CONG - CPU dang chay.\r\n");
    uart_puts("Neu ban doc duoc dong nay, firmware da\r\n");
    uart_puts("duoc ma hoa dung KEY va dung MODE.\r\n");
    uart_puts("\r\n");

    /* In xong thi im lang. Vong lap chi con nhay LED + vo watchdog. */
    for (;;) {
        LED_REG = on;
        on ^= 1u;
        delay_loops(DELAY_LOOPS);
    }

    return 0;
}
