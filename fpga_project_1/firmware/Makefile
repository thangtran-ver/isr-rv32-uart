#======================================================================
#  Makefile -- firmware cho ISR demo (PicoRV32 / Tang Nano 4K)
#
#  Dung:
#     make              -> firmware_enc.hex   (ma hoa DUNG key)
#     make wrong        -> firmware_wrong.hex (ma hoa SAI key, de demo)
#     make check        -> kiem tra RVC / kich thuoc / section
#     make dump         -> xem disassembly
#     make clean
#
#  Doi MODE / KEY:
#     make MODE=1 KEY=0x12345678
#  ==> PHAI sua ISR_MODE / ISR_KEY trong ../src/isr_top.v cho TRUNG,
#      neu khong LED se khong bao gio nhay.
#======================================================================

# Toolchain xPack tren may nay. Doi 1 dong nay neu chuyen sang may khac.
# Dung dau '/', KHONG dung '\'. Nho dau '/' o cuoi.
TOOLCHAIN ?= D:/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin/
CROSS   ?= $(TOOLCHAIN)riscv-none-elf-
CC       = $(CROSS)gcc
OBJCOPY  = $(CROSS)objcopy
OBJDUMP  = $(CROSS)objdump
READELF  = $(CROSS)readelf
SIZE     = $(CROSS)size

PYTHON  ?= python
ENCODER ?= $(firstword $(wildcard isr_encoder.py ../isr_encoder.py))

# ---- Phai trung voi isr_top.v --------------------------------------
MODE    ?= 3
KEY     ?= 0x5A5A5A5A
WRONGKEY ?= 0xDEADBEEF
RAM_WORDS ?= 2048

#----------------------------------------------------------------------
#  -march=rv32i  : KHONG co 'c'. Lenh nen 16-bit se pha vo can chinh
#                  word 32-bit cua isr_decoder.
#  -mno-relax    : tat relaxation gp-relative. Ta khong nap thanh ghi
#                  gp trong start.S nen phai tat, khong thi truy cap
#                  .sdata se sai dia chi.
#----------------------------------------------------------------------
ARCH     = -march=rv32i -mabi=ilp32 -mno-relax

CFLAGS   = $(ARCH) -Os -g -ffreestanding -nostdlib -nostartfiles \
           -fno-builtin -fno-pic -fomit-frame-pointer \
           -ffunction-sections -fdata-sections -Wall -Wextra

LDFLAGS  = $(ARCH) -nostdlib -nostartfiles -T link.ld \
           -Wl,--gc-sections -Wl,-Map,firmware.map

SRCS     = start.S main.c

.PHONY: all wrong check dump clean
all: firmware_enc.hex

#---- 1. Bien dich --------------------------------------------------
firmware.elf: $(SRCS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS)
	@$(SIZE) $@

#---- 2. Trich ma may (khong gom .bss vi da NOLOAD) ------------------
firmware.bin: firmware.elf
	$(OBJCOPY) -O binary $< $@

#---- 3. Doi sang .hex 1 word/dong -----------------------------------
firmware.hex: firmware.bin bin2hex.py
	$(PYTHON) bin2hex.py $< $@ $(RAM_WORDS)

#---- 4. Ma hoa ISR ---------------------------------------------------
#  --from-elf: doc section co co SHF_EXECINSTR tu ELF, chi ma hoa
#  dung .text. .rodata/.data giu nguyen (vi CPU doc chung bang lw,
#  mem_instr = 0, khong di qua giai ma).
firmware_enc.hex: firmware.hex firmware.elf
	$(PYTHON) $(ENCODER) firmware.hex $@ \
		--mode $(MODE) --key $(KEY) --from-elf firmware.elf

#---- Ban SAI key: dung de demo "chuong trinh nap sai thi khong chay"
wrong: firmware.hex firmware.elf
	$(PYTHON) $(ENCODER) firmware.hex firmware_wrong.hex \
		--mode $(MODE) --key $(WRONGKEY) --from-elf firmware.elf
	@echo ""
	@echo ">>> firmware_wrong.hex: ma hoa bang key $(WRONGKEY)"
	@echo ">>> Doi RAM_INIT trong isr_top.v sang file nay, build lai"
	@echo ">>> Ket qua mong doi: LED TAT han."

#---- Kiem tra truoc khi nap ------------------------------------------
check: firmware.elf
	@echo "=== 1. Lenh nen 16-bit (RVC)? ==="
	@$(READELF) -h firmware.elf | grep -i "flags" \
	  | grep -qi "RVC" \
	  && echo "  *** LOI: ELF co RVC! Kiem tra lai -march=rv32i ***" \
	  || echo "  OK: khong co RVC"
	@echo ""
	@echo "=== 2. _start co o dia chi 0x00000000 khong? ==="
	@$(READELF) -h firmware.elf | grep -i "Entry point"
	@echo "  (phai la 0x0)"
	@echo ""
	@echo "=== 3. Section: chi cai co 'X' moi bi ma hoa ==="
	@$(READELF) -S firmware.elf | grep -E "\[ ?[0-9]+\] \." \
	  | grep -E "text|rodata|data|bss"
	@echo "  .text  phai co  X   -> se ma hoa"
	@echo "  .rodata/.data KHONG duoc co X -> giu nguyen"
	@echo ""
	@echo "=== 4. Kich thuoc ==="
	@$(SIZE) firmware.elf

dump: firmware.elf
	$(OBJDUMP) -d -S firmware.elf | head -80

clean:
	rm -f *.elf *.bin *.hex *.map
