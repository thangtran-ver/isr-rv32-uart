#!/usr/bin/env python3
"""
attack_mode2.py — Demo tan cong known-plaintext len MODE 2 (Buoc 7.3)
=====================================================================
Chung minh diem yeu cua MODE 2: xorshift32 TUYEN TINH tren GF(2), nen
  key_eff(addr) = xorshift32(addr ^ KEY) ^ KEY
                = xorshift32(addr) ^ [xorshift32(KEY) ^ KEY]
                = xorshift32(addr) ^ CONST

Toan bo anh huong cua KHOA gom vao mot hang so CONST duy nhat. Attacker
chi can DOAN DUNG 1 lenh goc (vi du 'auipc sp' luon o dau _start) la
khoi phuc CONST, roi giai ma sach ca chuong trinh — KHONG can biet KEY.

Chay:
  python attack_mode2.py firm_isr_m2.hex --known 0x0:0x00002117
  python attack_mode2.py firm_isr_m3.hex --known 0x0:0x00002117   # -> that bai
"""
import argparse, sys

M = 0xFFFFFFFF

def xorshift32(x):
    x &= M
    a = (x ^ (x << 13)) & M
    b = a ^ (a >> 17)
    return (b ^ (b << 5)) & M

def read_hex(path):
    words, cur = [], 0
    for raw in open(path):
        s = raw.strip()
        if not s or s.startswith(("//", "#")): continue
        if s.startswith("@"):
            cur = int(s[1:], 16); continue
        for t in s.split():
            words.append((cur * 4, int(t, 16) & M)); cur += 1
    return words

def is_legal_rv32(w):
    RV32I = {0x37,0x17,0x6F,0x67,0x63,0x03,0x23,0x13,0x33,0x0F,0x73}
    if w & 3 != 3: return False
    op = w & 0x7F
    if op not in RV32I: return False
    f3, f7 = (w >> 12) & 7, (w >> 25) & 0x7F
    if op == 0x63 and f3 in (2, 3): return False
    if op == 0x03 and f3 in (3, 6, 7): return False
    if op == 0x23 and f3 > 2: return False
    if op == 0x33 and f7 not in (0, 0x20, 1): return False
    if op == 0x13 and f3 in (1, 5) and f7 not in (0, 0x20): return False
    return True

def main():
    p = argparse.ArgumentParser()
    p.add_argument("enchex", help="file hex da ma hoa (mode 2) attacker lay duoc")
    p.add_argument("--known", action="append", required=True,
                   help="cap addr:plaintext attacker DOAN, vd 0x0:0x00002117")
    p.add_argument("--out", default=None, help="ghi ra file da giai ma")
    a = p.parse_args()

    enc = read_hex(a.enchex)
    emap = dict(enc)

    # ---- Attacker khoi phuc CONST tu MOI cap da biet ----
    consts = []
    for k in a.known:
        sa, sp = k.split(":")
        addr, plain = int(sa, 0), int(sp, 0)
        if addr not in emap:
            sys.exit(f"[FAIL] Dia chi 0x{addr:X} khong co trong file")
        keff = plain ^ emap[addr]              # key_eff that su tai addr
        const = keff ^ xorshift32(addr)        # <-- suy CONST, khong can KEY
        consts.append(const)
        print(f"[ATK] Doan lenh 0x{addr:08X} = 0x{plain:08X}  "
              f"->  CONST = 0x{const:08X}")

    if len(set(consts)) == 1:
        print(f"[ATK] Tat ca cap cho CUNG CONST = 0x{consts[0]:08X}  "
              f"=> mo hinh tuyen tinh DUNG, khoa da lo hoan toan.\n")
    else:
        print(f"[ATK] Cac cap cho CONST KHAC NHAU: "
              f"{[hex(c) for c in consts]}")
        print("[ATK] => mo hinh tuyen tinh SAI, khong khoi phuc duoc khoa.\n")

    const = consts[0]

    # ---- Attacker giai ma sach ca chuong trinh chi bang CONST ----
    recovered = [(addr, (c ^ xorshift32(addr) ^ const) & M) for addr, c in enc]

    # Kiem chung bang ty le lenh hop le (attacker khong co ban goc that)
    n_legal = sum(1 for _, w in recovered if is_legal_rv32(w))
    print(f"[ATK] Giai ma {len(recovered)} word bang CONST duy nhat")
    print(f"[ATK] {n_legal}/{len(recovered)} word ra lenh RV32I HOP LE "
          f"({100*n_legal/len(recovered):.1f}%)")
    if n_legal > 0.5 * len(recovered):
        print("[ATK] => Chuong trinh da bi giai ma thanh cong. MODE 2 BI PHA.\n")
    else:
        print("[ATK] => Ket qua toan rac. Tan cong THAT BAI (mode phi tuyen).\n")

    if a.out:
        with open(a.out, "w") as f:
            f.write("@00000000\n")
            for i, (_, w) in enumerate(recovered):
                f.write(f"{w:08x}" + (" " if (i % 4 != 3) else "\n"))
            if len(recovered) % 4: f.write("\n")
        print(f"[ATK] Ghi ban giai ma ra '{a.out}'")

if __name__ == "__main__":
    main()
