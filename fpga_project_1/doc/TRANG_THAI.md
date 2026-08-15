# fpga_project_1 — trang thai sau khi don thu muc

## 1. Da lam

### Chuyen file tu `temp/` ve dung cho
| Tu | Toi |
|---|---|
| `temp/uart_tx.v`      | `src/uart_tx.v`  (file MOI) |
| `temp/isr_top.v`      | `src/isr_top.v` |
| `temp/isr.cst`        | `src/isr.cst` |
| `temp/main.c`         | `firmware/main.c` |
| `temp/tb_uart.v`      | `sim/tb_uart.v` |
| `temp/README_UART.md` | `doc/README_UART.md` |

`temp/` gio da rong.

### Bo sung file thieu (chep tu `D:\New folder (19)\isr`)
- `firmware/start.S`   — reset vector + `delay_loops()` (main.c goi ham nay, thieu la loi link)
- `firmware/link.ld`   — tach `.text` / `.rodata`, bat buoc phai co
- `firmware/Makefile`
- `firmware/bin2hex.py`
- `src/isr.sdc`        — rang buoc timing 27 MHz

### Sua loi
1. **KEY khong khop** — `isr_top.v` de `ISR_KEY = 32'h5A5A5A5A`, trong khi
   Makefile va testbench dung `0xA5A5A5A5`. Sai key = CPU trap, khong ra chu nao.
   -> da doi thanh `32'hA5A5A5A5`.
2. **RAM_INIT tro vao file khong ton tai**
   (`D:/New folder (19)/isr/temp/firmware_uart_enc.hex`)
   -> da doi thanh `D:/New folder (19)/isr_uart/fpga_project_1/firmware/firmware_enc.hex`
3. **`fpga_project_1.gprj` rong** — khong co device, FileList trong.
   -> da dien `GW1NSR-LV4CQN48PC6/I5` va day du 9 file nguon (co ca `uart_tx.v`).

### Firmware da build san
`firmware/firmware_enc.hex` (key dung) va `firmware/firmware_wrong.hex`
(key `0xDEADBEEF`, de demo) da co san — synthesize duoc ngay, khong can gcc.

### Da mo phong kiem chung (iverilog)
- key DUNG : **283 ky tu, trap=0, alive=1** — in ra banner + "tick 00000000"
- key SAI  : **0 ky tu, trap=1, alive=0** — im lang hoan toan

## 2. Con can gi de chay that

### Bat buoc
- [ ] **Gowin IDE** — dong project neu dang mo, roi mo lai `fpga_project_1.gprj`
      (file da bi ghi de). Kiem tra Design tree co du 9 file, top module = `isr_top`.
- [ ] **Gowin Programmer** + cap USB-C cua Tang Nano 4K.
- [ ] **Module USB-UART CP2102** (hoac CH340/FT232) — board Tang Nano 4K
      KHONG co san UART tren cong USB.
- [ ] **Dau day**: chan 40 FPGA -> RX cua CP2102; GND <-> GND.
      **KHONG noi VCC.** Jumper CP2102 phai o **3.3 V** (5 V se hong GW1NSR-4C).
- [ ] **Terminal** 115200 8N1, khong flow control (PuTTY / TeraTerm / picocom).

### Toolchain — DA CAU HINH SAN
Toolchain xPack tren may nay:

```
D:\xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64\xpack-riscv-none-elf-gcc-15.2.0-1\bin
```

Prefix la `riscv-none-elf-` (KHONG phai `riscv64-unknown-elf-`). Duong dan nay
da duoc ghi thang vao `firmware/Makefile` (bien `TOOLCHAIN`) va
`firmware/build.bat` (bien `TC`) — **khong can them vao PATH**.

**Cach build (khong can cai `make`):**
```
cd firmware
build.bat            :: -> firmware_enc.hex    (key DUNG)
build.bat wrong      :: -> firmware_wrong.hex  (key SAI, de demo)
build.bat check      :: kiem tra RVC / entry / section / size
build.bat dump       :: xem disassembly
build.bat clean
```

**Neu ban co `make`** thi Makefile cung chay thang, khong can tham so gi them:
```
cd firmware
make PYTHON=python
make PYTHON=python wrong
make PYTHON=python check
```

Van can **Python 3** trong PATH (cho `bin2hex.py` va `isr_encoder.py`).
Neu lenh `python` khong chay, sua bien `PY` o dau `build.bat` thanh `py -3`.

Doi toolchain sang may khac: sua dung 1 dong `TC=` trong `build.bat`
va 1 dong `TOOLCHAIN ?=` trong `Makefile`.

### Tuy chon
- [ ] **iverilog** neu muon mo phong lai:
      ```
      iverilog -g2012 -o sim -DHEXFILE='"firmware/firmware_enc.hex"' \
        sim/tb_uart.v src/isr_top.v src/picorv32.v src/isr_ram.v \
        src/isr_decoder.v src/isr_prf_round.v src/isr_sbox4.v src/uart_tx.v
      vvp sim
      ```

## 3. Hai cho co the phai chinh tren board that

**`LED_ACTIVE_LOW`** trong `src/isr_top.v` dang de `1'b1`. Theo ghi chu cua ban
truoc day, LED tren board thuc te co ve la **active-HIGH** — neu thay LED sang
khi le ra phai tat, doi tham so nay ve `1'b0`.

**Doi sang key sai de demo**: sua `RAM_INIT` trong `src/isr_top.v` sang
`.../firmware/firmware_wrong.hex` roi Synthesize + P&R lai. Ket qua mong doi:
terminal khong nhan duoc gi, LED tat.

## 4. Nhat quan MODE / KEY — phai giu 3 cho trung nhau
| Cho | Gia tri hien tai |
|---|---|
| `src/isr_top.v` : `ISR_MODE` / `ISR_KEY` | `3` / `0xA5A5A5A5` |
| `firmware/Makefile` : `MODE` / `KEY`     | `3` / `0xA5A5A5A5` |
| `sim/tb_uart.v` : `MODE` / `ISR_KEY`     | `3` / `0xA5A5A5A5` |

Doi mot cho ma quen hai cho kia = CPU trap, khong co dau hieu nao khac.

---

## 5. Chot lai: KEY = 0x5A5A5A5A

Theo yeu cau, toan bo project dung **`0x5A5A5A5A`** (KHONG phai `0xA5A5A5A5`).
`firmware_enc.hex` da duoc khoi phuc ve dung ban goc — doi chieu byte-by-byte
voi file ban tu build: **giong het 100%**.

### KEY / MODE — da dong bo ca 4 cho
| Cho | MODE | KEY |
|---|---|---|
| `src/isr_top.v`      | 3 | `32'h5A5A5A5A` |
| `sim/tb_uart.v`      | 3 | `32'h5A5A5A5A` |
| `firmware/Makefile`  | 3 | `0x5A5A5A5A` |
| `firmware/build.bat` | 3 | `0x5A5A5A5A` |

### Firmware (gcc 15.2, 179 word = 716 byte, 8.7% RAM)
| File | Key | Mo phong |
|---|---|---|
| `firmware_enc.hex`   | `0x5A5A5A5A` | **283 ky tu, trap=0, alive=1** |
| `firmware_wrong.hex` | `0xDEADBEEF` | 0 ky tu, trap=1, alive=0 |

ELF kiem tra dat:
```
.text    0x00000000 .. 0x000001BC  AX   (444 B)   <- co co X, se ma hoa
.rodata  0x000001BC .. 0x000002CC  A    (272 B)   <- KHONG co X, giu nguyen
Entry point: 0x0        Flags: 0x0  (khong co RVC)
```

Lenh tai tao neu can:
```
python isr_encoder.py firmware.hex firmware_enc.hex   --mode 3 --key 0x5A5A5A5A --from-elf firmware.elf
python isr_encoder.py firmware.hex firmware_wrong.hex --mode 3 --key 0xDEADBEEF --from-elf firmware.elf
```
Hoac: `build.bat` va `build.bat wrong` (key 0x5A5A5A5A da cai san).

### Checklist da xac nhan
- [x] `temp/` rong
- [x] `RAM_INIT` tro dung `firmware/firmware_enc.hex` (co that, 179 word)
- [x] Ca 9 file trong `fpga_project_1.gprj` deu ton tai
- [x] KEY `0x5A5A5A5A` trung nhau o ca 4 cho
- [x] Toolchain `riscv-none-elf-gcc.exe` co that o duong dan da cau hinh
- [x] Mo phong lai file hex CUOI CUNG tren dia: 283 ky tu, trap=0

**San sang Synthesize -> Place & Route -> Program.**

---

## 6. Loi PA2024 — "274 ports exceeds resource limit 30"

**Nguyen nhan: Gowin chon SAI top module.** Trong log tong hop:

```
NOTE (EX0101) : Current top module is "picorv32_wb"
```

File `picorv32.v` chua 8 module, trong do co 3 module KHONG bi module nao khac
goi: `isr_top`, `picorv32_axi`, `picorv32_wb`. Khong duoc chi dinh top, Gowin
tu doan va vo phai `picorv32_wb` — la wrapper Wishbone voi 274 chan. Con
GW1NSR-4C chi co 30 chan I/O thuong.

274 chan la dau hieu nhan dang: `isr_top` chi co **4** chan
(`sys_clk`, `sys_rst_n`, `led`, `uart_tx_pin`).

**So sanh voi project `isr` cu (chay duoc):**

| | TopModule |
|---|---|
| `isr/impl/isr_process_config.json` | `"isr_top"` |
| `fpga_project_1/.../process_config.json` | `""`  <- rong |

### Cach sua
Da dat san `"TopModule" : "isr_top"` trong
`impl/fpga_project_1_process_config.json`.

**NHUNG** neu Gowin IDE dang mo, no se ghi de file nay luc dong project.
Cach chac chan nhat la dat trong GUI:

```
Project  ->  Configuration  ->  General  ->  Top Module  =  isr_top
```

Roi Synthesize lai tu dau (Rerun All), khong dung ket qua cu.

### Cac WARN trong log co dang lo khong?
Khong. Toan bo `EX3826/EX3827` (full_case/parallel_case) va `EX3791`
(truncate) deu la canh bao co huu cua picorv32, project `isr` cu cung co y het
va van chay dung. Rieng `EX3073 Port 'mem_la_read' remains unconnected` o dong
2987 la nam TRONG `picorv32_wb` — sau khi doi top ve `isr_top` thi warning nay
se bien mat luon.

---

## 7. DA CHAY THANH CONG tren board that

Tera Term COM10 (CP210x, 115200 8N1) nhan duoc lien tuc:

```
tick 0000015D
tick 0000015E
...
tick 00000173
```

`0x173` = tick thu 371, moi tick ~500 ms => board da chay lien tuc ~3 phut
khong trap, khong treo.

### Xac nhan tu bao cao Gowin
| Muc | Ket qua |
|---|---|
| Top module | `isr_top` (da sua tu `picorv32_wb`) |
| `uart_tx_pin` | chan **40/1**, LVCMOS33, out |
| Fmax thuc te | **39.124 MHz** / yeu cau 27 MHz — du ~45% bien |
| Setup / Hold violations | **0 / 0** |
| BSRAM | 6/10 (60%) |
| Logic | 1661/4608 (37%) |
| I/O Port | 4/39 |

WARN `PR1014` ve `sys_clk_d` la vo hai — project `isr` cu cung co y het
va van chay dung.

### Khong thay dong banner dau tien?
Banner chi in **mot lan duy nhat** luc CPU khoi dong, roi bi cac dong `tick`
day troi len tren. Muon xem lai: nhan nut **S1** tren board de reset, CPU se
in lai tu dau.

### Buoc tiep theo: demo doi chieu key SAI
1. Sua `RAM_INIT` trong `src/isr_top.v`:
   `.../firmware/firmware_wrong.hex`
2. Synthesize -> Place & Route -> Program
3. Ket qua mong doi: terminal **im lang hoan toan (0 ky tu)**, LED tat.

Doi nguoc lai ve `firmware_enc.hex` de chay binh thuong.
