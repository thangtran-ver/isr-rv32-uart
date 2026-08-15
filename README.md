# ISR-RV32 — PicoRV32 + Instruction Set Randomization (UART demo)

Đồ án minh hoạ **Instruction Set Randomization (ISR)** trên lõi RISC-V
[PicoRV32], tổng hợp cho FPGA và xuất kết quả ra PC qua UART.

Mã lệnh trong bộ nhớ được **mã hoá**; một khối `isr_decoder` nằm ngay trước
tầng decode của CPU sẽ giải mã theo khoá bí mật khi và chỉ khi đang **nạp lệnh**
(`is_instr = 1`). Dữ liệu (`.rodata`) đọc bằng `lw/lb` thì cho qua nguyên.

## Bốn chế độ (ISR_MODE)

| MODE | key_eff | Ghi chú |
|------|---------|---------|
| 0 | `0` | tắt ISR (bypass) |
| 1 | `KEY` | XOR khoá cố định |
| 2 | `xorshift32(pc^KEY) ^ KEY` | phụ thuộc PC — **tuyến tính** |
| 3 | `PRF3(pc^KEY, KEY)` | 3 vòng S-box + khuếch tán — phi tuyến |

## Cấu trúc

```
fpga_project_1/
├── src/        RTL: isr_top, isr_decoder, isr_prf_round, isr_sbox4,
│               isr_ram, uart_tx, picorv32.v (gốc), ràng buộc .cst/.sdc
├── sim/        testbench UART
├── firmware/   mã C + toolchain script (build.bat / Makefile),
│               isr_encoder.py (mã hoá), và bộ công cụ tấn công/phân tích
└── doc/        README_UART.md, TRANG_THAI.md
```

## Luồng build firmware

```
main.c + start.S --gcc--> .elf --objcopy--> .bin --bin2hex.py--> .hex
                                   --isr_encoder.py (mode/key)--> firmware_enc.hex
```



## Công cụ phân tích / tấn công (mục đích học thuật)

- `isr_encoder.py` — mã hoá `.text` theo mode & key (phía phòng thủ).
- `attack_mode2.py` / `attack_mode2_full.py` — tấn công known-plaintext lên
  MODE 2 (tuyến tính): khôi phục code, và khôi phục **cả firmware chạy được**
  chỉ từ 1 lệnh đoán, không cần khoá. Thất bại trên MODE 3 (đúng như kỳ vọng).
- `hex2asm.py` — disassembly `.hex`/`.bin` ra assembly (RV32I).
- `bin2hex.py` — `.bin` → `.hex` (kèm dấu `@` ranh giới section).

> Toàn bộ mã tấn công chỉ dùng để chứng minh điểm yếu của sơ đồ mã hoá tuyến
> tính (MODE 2) so với phi tuyến (MODE 3), phục vụ báo cáo học thuật.

[PicoRV32]: https://github.com/YosysHQ/picorv32
