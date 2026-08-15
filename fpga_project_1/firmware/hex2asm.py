#!/usr/bin/env python3
"""
hex2asm.py -- Disassembly nguoc tu file .hex (hoac .bin) RV32 ra assembly.

    python hex2asm.py firmware.hex
    python hex2asm.py firm_full.hex --end 0x0AA8      # chi disasm .text
    python hex2asm.py firmware.bin --bin --base 0x0 > out.asm

Doc duoc ca 2 kieu .hex: co dong '@' (chi so word) lan kieu phang 1 word/dong.
Dia chi in ra = chi_so_word * 4 (dung quy uoc cua project nay).

Can: pip install capstone
"""
import sys
import argparse
import capstone as cs

M = 0xFFFFFFFF


def read_words(path, is_bin):
    """Tra ve list (byte_addr, word32). Bin: dia chi lien tuc tu --base."""
    out = []
    if is_bin:
        data = open(path, "rb").read()
        data += b"\x00" * (-len(data) % 4)
        for i in range(0, len(data), 4):
            out.append((i, int.from_bytes(data[i:i + 4], "little") & M))
        return out
    cur = 0
    for raw in open(path):
        s = raw.strip()
        if not s or s.startswith(("//", "#")):
            continue
        if s.startswith("@"):
            cur = int(s[1:], 16)
            continue
        for t in s.split():
            out.append((cur * 4, int(t, 16) & M))
            cur += 1
    return out


def main():
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("infile", help="file .hex hoac .bin")
    p.add_argument("--bin", action="store_true", help="dau vao la .bin thuan")
    p.add_argument("--base", type=lambda s: int(s, 0), default=0,
                   help="dia chi bat dau (chi cho --bin), mac dinh 0x0")
    p.add_argument("--start", type=lambda s: int(s, 0), default=None,
                   help="chi disasm tu dia chi byte nay")
    p.add_argument("--end", type=lambda s: int(s, 0), default=None,
                   help="dung o dia chi byte nay (vd --end 0x0AA8 = het .text)")
    a = p.parse_args()

    words = read_words(a.infile, a.bin)
    if a.bin and a.base:
        words = [(addr + a.base, w) for addr, w in words]

    md = cs.Cs(cs.CS_ARCH_RISCV, cs.CS_MODE_RISCV32)
    md.detail = False

    for addr, w in words:
        if a.start is not None and addr < a.start:
            continue
        if a.end is not None and addr >= a.end:
            break
        code = w.to_bytes(4, "little")
        ins = list(md.disasm(code, addr))
        if ins:
            i = ins[0]
            print("%8x:  %08x    %-8s %s"
                  % (addr, w, i.mnemonic, i.op_str))
        else:
            print("%8x:  %08x    .word 0x%08x   (khong phai lenh RV32I)"
                  % (addr, w, w))


if __name__ == "__main__":
    main()
