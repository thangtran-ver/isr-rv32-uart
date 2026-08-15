#!/usr/bin/env python3
"""
bin2hex.py -- doi firmware.bin thanh .hex cho $readmemh / isr_encoder.py

    python bin2hex.py firmware.bin firmware.hex [so_word_toi_da] [tuy_chon]

Tuy chon:
    --elf FILE   Doc firmware.elf de chen them dong '@' o dau moi section
                 (vd '@0000006F' ngay cho .rodata bat dau). Chi de DE NHIN,
                 khong doi noi dung bo nho mot chut nao.
    --flat       Kieu cu: 1 word moi dong, KHONG co dong '@' nao.

Mac dinh xuat 1 dong '@00000000' roi 4 word 32-bit little-endian moi dong,
giong `objcopy -O verilog --verilog-data-width=4`.

LUU Y VE '@'
------------
Ca $readmemh cua Verilog LAN read_hex_file() cua isr_encoder.py deu hieu
'@' la CHI SO WORD, khong phai dia chi byte. Script nay xuat theo dung
quy uoc do: '@' = dia_chi_byte / 4. Dung nham 2 thu nay thi moi thu sau
dong '@' se nam sai cho -- trieu chung y het "ma hoa sai".
"""
import struct
import sys

WORDS_PER_LINE = 4
SHF_ALLOC = 0x2
SHF_EXECINSTR = 0x4


def elf_alloc_sections(path):
    """Tra ve [(ten, addr, size, la_exec)] cua cac section duoc nap, da sap xep."""
    with open(path, "rb") as f:
        data = f.read()

    if data[:4] != b"\x7fELF":
        sys.exit("[FAIL] '%s' khong phai file ELF" % path)
    if data[4] != 1 or data[5] != 1:
        sys.exit("[FAIL] Chi ho tro ELF32 little-endian (rv32).")

    e_shoff, = struct.unpack_from("<I", data, 0x20)
    e_shentsize, = struct.unpack_from("<H", data, 0x2E)
    e_shnum, = struct.unpack_from("<H", data, 0x30)
    e_shstrndx, = struct.unpack_from("<H", data, 0x32)

    def sh(i):
        off = e_shoff + i * e_shentsize
        name, stype, flags, addr, offset, size = struct.unpack_from(
            "<6I", data, off)
        return dict(name=name, type=stype, flags=flags, addr=addr, size=size)

    # offset cua bang ten section (.shstrtab) trong file
    off_shstr, = struct.unpack_from("<I", data,
                                    e_shoff + e_shstrndx * e_shentsize + 0x10)

    def name_of(off):
        base = off_shstr + off
        end = data.index(b"\0", base)
        return data[base:end].decode()

    secs = []
    for i in range(e_shnum):
        s = sh(i)
        if s["size"] == 0 or not (s["flags"] & SHF_ALLOC):
            continue
        if s["type"] == 8:            # SHT_NOBITS (.bss) -- khong nam trong .bin
            continue
        secs.append((name_of(s["name"]), s["addr"], s["size"],
                     bool(s["flags"] & SHF_EXECINSTR)))
    return sorted(secs, key=lambda t: t[1])


def section_marks(elf_path, n_words):
    """{chi_so_word_trong_file: chi_so_word_de_ghi_ra_dong_'@'}"""
    secs = elf_alloc_sections(elf_path)
    if not secs:
        sys.exit("[FAIL] Khong tim thay section nao duoc nap trong ELF.")

    base = secs[0][1]
    if base % 4:
        sys.exit("[FAIL] Section dau tien khong can chinh word: 0x%08X" % base)

    marks = {}
    print("[INFO] Section trong ELF:")
    for nm, addr, size, ex in secs:
        tag = "EXEC" if ex else "data"
        if addr % 4:
            sys.exit("[FAIL] Section '%s' o 0x%08X khong can chinh word.\n"
                     "       Them . = ALIGN(4); truoc no trong link.ld."
                     % (nm, addr))
        idx = (addr - base) // 4
        if idx >= n_words:
            print("[WARN] Section '%s' nam ngoai firmware.bin, bo qua" % nm)
            continue
        marks[idx] = addr // 4
        print("       %s  %-16s 0x%08X .. 0x%08X  (%d B)  -> word %d"
              % (tag, nm, addr, addr + size, size, idx))
    return marks


def main():
    args = [a for a in sys.argv[1:]]
    elf_path = None
    flat = False

    if "--flat" in args:
        flat = True
        args.remove("--flat")
    if "--elf" in args:
        i = args.index("--elf")
        if i + 1 >= len(args):
            sys.exit("[FAIL] --elf thieu ten file.")
        elf_path = args[i + 1]
        del args[i:i + 2]

    if len(args) < 2:
        sys.exit(__doc__)

    src, dst = args[0], args[1]
    max_words = int(args[2]) if len(args) > 2 else 2048

    try:
        data = open(src, "rb").read()
    except FileNotFoundError:
        sys.exit(
            "[FAIL] Khong tim thay '%s'.\n"
            "\n"
            "       File nay sinh ra o BUOC 2. Phai chay 2 buoc truoc da:\n"
            "\n"
            "       1) Bien dich:\n"
            "          riscv-none-elf-gcc -march=rv32i -mabi=ilp32 "
            "-mno-relax -Os -g -ffreestanding -nostdlib -nostartfiles "
            "-fno-builtin -fno-pic -ffunction-sections -fdata-sections "
            "-T link.ld -Wl,--gc-sections -o firmware.elf start.S main.c\n"
            "\n"
            "       2) Trich ma may:\n"
            "          riscv-none-elf-objcopy -O binary firmware.elf "
            "firmware.bin\n"
            "\n"
            "       Hoac chay mot phat:  build.bat\n" % src)

    pad = -len(data) % 4
    data += b"\x00" * pad

    words = struct.unpack("<%dI" % (len(data) // 4), data)

    if len(words) > max_words:
        sys.exit("[FAIL] firmware %d word > RAM %d word (%d KB).\n"
                 "       Tang RAM_AW trong isr_top.v hoac cat bot code."
                 % (len(words), max_words, max_words * 4 // 1024))

    marks = {}
    if elf_path and not flat:
        marks = section_marks(elf_path, len(words))
    if not flat and 0 not in marks:
        marks[0] = 0

    with open(dst, "w") as f:
        if flat:
            for w in words:
                f.write("%08x\n" % w)
        else:
            buf = []
            i = 0
            while i < len(words):
                if i in marks:
                    if buf:
                        f.write(" ".join(buf) + "\n")
                        buf = []
                    f.write("@%08x\n" % marks[i])
                buf.append("%08x" % words[i])
                if len(buf) == WORDS_PER_LINE:
                    f.write(" ".join(buf) + "\n")
                    buf = []
                i += 1
            if buf:
                f.write(" ".join(buf) + "\n")

    print("[INFO] %s : %d word (%d byte), %d dong '@', dung %.1f%% RAM"
          % (dst, len(words), len(data), len(marks) if not flat else 0,
             100.0 * len(words) / max_words))


if __name__ == "__main__":
    main()
