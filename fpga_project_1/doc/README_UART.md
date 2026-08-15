# Bản UART cho ISR demo — file tạm để thử

Các file trong `temp/` là **bản đã thêm UART**, chưa đụng gì tới `src/` và
`firmware/` của bạn. Thử xong thấy ổn thì tự copy đè.

## File trong thư mục này

| File | Chép tới | Ghi chú |
|---|---|---|
| `uart_tx.v` | `src/` | **File mới** — phải Add Files vào project Gowin |
| `isr_top.v` | `src/` | Thay bản cũ — thêm cổng `uart_tx_pin` + 2 thanh ghi MMIO |
| `isr.cst` | `src/` | Thay bản cũ — thêm chân 40 |
| `main.c` | `firmware/` | Thay bản cũ — thêm hàm in UART |
| `tb_uart.v` | (không cần) | Testbench, chỉ để mô phỏng |

`start.S`, `link.ld`, `Makefile`, `isr_encoder.py` **không đổi**.

## Kết quả mô phỏng

Testbench có bộ thu UART giải mã trực tiếp đường TX thành ký tự.

**Key đúng** — 456 ký tự, `trap=0`, `alive=1`:

```
=====================================
  ISR-RV32 tren Tang Nano 4K
  PicoRV32 + Instruction Set Random.
=====================================
Giai ma lenh THANH CONG - CPU dang chay.
Neu ban doc duoc dong nay, firmware da
duoc ma hoa dung KEY va dung MODE.

tick 00000000
tick 00000001
tick 00000002
...
```

**Key sai (`0xDEADBEEF`)** — `0 ký tự`, `trap=1`, `alive=0`. Im lặng hoàn toàn.

Tương phản này mạnh hơn LED nhiều khi trình bày: một bên đọc được chữ, một bên
không có gì.

## Đấu dây

```
CP2102 RX   <--  chân 40 của FPGA
CP2102 GND  <->  GND của board
CP2102 TX        (không nối — bản này chỉ có TX phía FPGA)
CP2102 VCC       (KHÔNG NỐI)
```

Terminal: **115200 8N1**, không flow control.

### Hai điều bắt buộc kiểm tra trước khi cắm

**Jumper CP2102 phải ở 3.3 V.** I/O của GW1NSR-4C không chịu được 5 V.

**Chân 40 thuộc bank 1 = 3.3 V.** Nếu muốn đổi chân khác, chỉ được chọn trong:

```
Bank 1:  39, 40, 41, 42, 43, 44, 46     <- 3.3 V, an toàn
Bank 0:  1                               <- 3.3 V
```

Tránh: 2,3,4,6,7,8,9 (JTAG), 47,48 (SPI flash), 10 (LED), 45 (clock),
và **toàn bộ 13–23 với 27–35 vì đó là bank 1.8 V — đưa 3.3 V vào là hỏng chip.**

## Bản đồ MMIO (đã mở rộng)

| Địa chỉ | Bit | Chức năng |
|---|---|---|
| `0x0200_0000` | [0] | LED (đọc/ghi) |
| `0x0200_0010` | [7:0] | UART TX data (ghi 1 byte) |
| `0x0200_0014` | [0] | UART busy (chỉ đọc) — đợi về 0 rồi mới ghi byte tiếp |

Baud: `27_000_000 / 115200 = 234.375` → làm tròn 234 → baud thực 115384.6,
sai số +0.16%. UART chịu được tới ~2–3% nên rất thoải mái.

## Các bước làm

1. Copy `uart_tx.v`, `isr_top.v`, `isr.cst` vào `src/`; `main.c` vào `firmware/`
2. Trong Gowin IDE: chuột phải project → **Add Files…** → chọn `src/uart_tx.v`
   (file mới, project chưa biết tới nó)
3. Build lại firmware:
   ```
   cd firmware
   riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -mno-relax -Os -g -ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-pic -ffunction-sections -fdata-sections -T link.ld -Wl,--gc-sections -o firmware.elf start.S main.c
   riscv-none-elf-objcopy -O binary firmware.elf firmware.bin
   python bin2hex.py firmware.bin firmware.hex 2048
   python isr_encoder.py firmware.hex firmware_uart_enc.hex --mode 3 --key 0xA5A5A5A5 --from-elf firmware.elf
   ```
4. Sửa `RAM_INIT` trong `isr_top.v` cho trỏ đúng file hex vừa tạo
   (bản trong `temp/` đang trỏ vào `D:/New folder (19)/isr/temp/firmware_uart_enc.hex`)
5. Synthesize → Place & Route → Program
6. Mở terminal 115200 8N1 trên cổng COM của CP2102

## Hai chỗ cần để ý

**`.rodata` giờ mới thật sự có dữ liệu.** Các chuỗi `"..."` nằm trong `.rodata`
và **không được mã hoá** — CPU đọc chúng bằng `lb`/`lw` (`mem_instr = 0`) nên
không đi qua bộ giải mã. `link.ld` đã tách sẵn từ đầu, và encoder xác nhận:

```
Da ma hoa : 110/178 word
Giu nguyen:  68 word (du lieu)
```

Nếu `.rodata` bị gộp vào `.text`, chương trình sẽ in ra ký tự rác mà **không
trap** — kiểu lỗi rất khó lần. Chạy `make check` để xác nhận `.text` có cờ `X`
còn `.rodata` thì không.

**`LED_ACTIVE_LOW` vẫn để `1'b1`** — tôi không tự đổi. Nhưng theo quan sát
trên board của bạn (trạng thái lỗi giữ chân 10 ở mức 1 mà LED lại sáng), LED
là **active-HIGH**, nên muốn "sai = LED tắt" thì đổi dòng đó thành `1'b0`.

**Firmware to lên 712 byte** (34.8% của RAM 8 KB trong mô phỏng, nhưng RAM thật
là 2048 word nên chỉ chiếm ~9%). Vẫn thoải mái.

## Muốn thêm RX

Bản này chỉ có TX (đủ cho demo in thông báo). Nếu sau muốn gõ lệnh từ PC xuống
thì cần thêm `uart_rx.v` và một thanh ghi MMIO nữa — nói tôi viết tiếp.
