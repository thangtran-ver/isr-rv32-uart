#!/usr/bin/env python3
"""
attack_mode2_full.py — Known-plaintext len MODE 2, KHOI PHUC BAN CHAY DUOC
==========================================================================
Khac attack_mode2.py o cho: khong chi doc duoc phan CODE ma dung lai duoc
CA BAN FIRMWARE HOAN CHINH (text + data), khong can KEY, khong can file ELF.

Vi sao ban attack cu lam hong .rodata?
--------------------------------------
Mode 2 CHI ma hoa .text; .rodata (chuoi ky tu) van la ban goc. Ban attack
cu ap phep giai ma len TOAN BO word -> vung .text ra dung, nhung vung
.rodata (von chua ma hoa) bi XOR them keystream mot lan -> thanh rac.

Cach lay lai ban hoan chinh
---------------------------
Attacker tu DO RANH GIOI text/data bang diem cat (changepoint):
  - Truoc ranh gioi: word GIAI MA ra lenh RV32I hop le  (day la .text).
  - Sau ranh gioi : word DE NGUYEN doc ra ASCII         (day la .rodata).
Chon diem cat B toi da hoa tong hai dau hieu tren. Sau do:
  - word < B : xuat ban GIAI MA
  - word >= B: xuat ban GOC (khong dung toi)
=> Ghep lai = firmware chay duoc y het ban goc.

Chay:
  python attack_mode2_full.py firm_isr_m2.hex --known 0x0:0x00002117 \
         --out firm_full.hex

Voi file MODE 3 (phi tuyen) buoc khoi phuc CONST se that bai (cac cap known
cho CONST khac nhau) -> script bao va dung, dung nhu ky vong.
"""
import argparse
import sys

M = 0xFFFFFFFF
RV32I = {0x37, 0x17, 0x6F, 0x67, 0x63, 0x03, 0x23, 0x13, 0x33, 0x0F, 0x73}


def xorshift32(x):
    x &= M
    a = (x ^ (x << 13)) & M
    b = a ^ (a >> 17)
    return (b ^ (b << 5)) & M


def is_legal_rv32(w):
    if w & 3 != 3:
        return False
    op = w & 0x7F
    if op not in RV32I:
        return False
    f3, f7 = (w >> 12) & 7, (w >> 25) & 0x7F
    if op == 0x63 and f3 in (2, 3):
        return False
    if op == 0x03 and f3 in (3, 6, 7):
        return False
    if op == 0x23 and f3 > 2:
        return False
    if op == 0x33 and f7 not in (0, 0x20, 1):
        return False
    if op == 0x13 and f3 in (1, 5) and f7 not in (0, 0x20):
        return False
    return True


def looks_like_data(w):
    """So byte 'giong du lieu' (ASCII in duoc hoac 0x00 padding) trong 1 word."""
    b = w.to_bytes(4, "little")
    return sum(1 for c in b if c == 0 or 0x20 <= c < 0x7F)


def read_hex(path):
    words, cur = [], 0
    for raw in open(path):
        s = raw.strip()
        if not s or s.startswith(("//", "#")):
            continue
        if s.startswith("@"):
            cur = int(s[1:], 16)
            continue
        for t in s.split():
            words.append((cur * 4, int(t, 16) & M))
            cur += 1
    return words


def write_hex(path, words):
    with open(path, "w") as f:
        f.write("@00000000\n")
        for i, w in enumerate(words):
            f.write("%08x" % w + (" " if i % 4 != 3 else "\n"))
        if len(words) % 4:
            f.write("\n")


def find_boundary(enc, dec):
    """Diem cat B toi da hoa: (#lenh hop le truoc B) + (#word data sau B)."""
    n = len(enc)
    pre = [0] * (n + 1)          # so word GIAI MA hop le trong [0, i)
    for i, (_, w) in enumerate(dec):
        pre[i + 1] = pre[i] + (1 if is_legal_rv32(w) else 0)
    suf = [0] * (n + 1)          # so word GOC giong data trong [i, n)
    for i in range(n - 1, -1, -1):
        st = enc[i][1]
        suf[i] = suf[i + 1] + (1 if looks_like_data(st) >= 3 else 0)
    best, B = -1, 0
    for b in range(n + 1):
        sc = pre[b] + suf[b]
        if sc > best:
            best, B = sc, b
    return B


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("enchex", help="file hex da ma hoa (mode 2) attacker lay duoc")
    p.add_argument("--known", action="append", required=True,
                   help="cap addr:plaintext DOAN, vd 0x0:0x00002117 (lap lai duoc)")
    p.add_argument("--out", default="firm_full.hex",
                   help="file firmware hoan chinh xuat ra")
    p.add_argument("--ref", default=None,
                   help="(tuy chon) firmware.hex GOC de tu kiem chung khop 100%%")
    a = p.parse_args()

    enc = read_hex(a.enchex)
    emap = dict(enc)

    # ---- Buoc 1: khoi phuc CONST tu cac cap known ----
    consts = []
    for k in a.known:
        sa, sp = k.split(":")
        addr, plain = int(sa, 0), int(sp, 0)
        if addr not in emap:
            sys.exit("[FAIL] Dia chi 0x%X khong co trong file" % addr)
        keff = plain ^ emap[addr]
        const = keff ^ xorshift32(addr)
        consts.append(const)
        print("[ATK] Doan 0x%08X = 0x%08X  ->  CONST = 0x%08X"
              % (addr, plain, const))

    if len(set(consts)) != 1:
        print("[ATK] CONST khac nhau giua cac cap: %s" % [hex(c) for c in consts])
        sys.exit("[ATK] => Mo hinh tuyen tinh SAI (co le la mode 3). Dung.")
    const = consts[0]
    print("[ATK] CONST duy nhat = 0x%08X  => khoa da lo, giai ma duoc ca file.\n"
          % const)

    # ---- Buoc 2: giai ma thu toan bo ----
    dec = [(addr, (c ^ xorshift32(addr) ^ const) & M) for addr, c in enc]

    # ---- Buoc 3: tu do ranh gioi text/data ----
    B = find_boundary(enc, dec)

    # Kiem tra tan cong co that su thanh cong khong. Voi mode 2, vung [0,B)
    # phai gan nhu 100%% lenh hop le. Voi mode 3 (phi tuyen), giai ma ra rac
    # nen B ~ 0 va ty le hop le thap -> bao that bai thay vi xuat file rac.
    n_text_legal = sum(1 for _, w in dec[:B] if is_legal_rv32(w))
    rate = n_text_legal / B if B else 0.0
    n_all_legal = sum(1 for _, w in dec if is_legal_rv32(w))
    if B < 0.2 * len(enc) or rate < 0.9:
        print("[ATK] Vung .text doan duoc qua nho / nhieu rac "
              "(B=%d, hop le %.0f%%, toan file %d/%d)."
              % (B, 100 * rate, n_all_legal, len(enc)))
        sys.exit("[ATK] => Tan cong THAT BAI. Day khong phai mode 2 tuyen tinh "
                 "(co le mode 3). Khong khoi phuc duoc.")

    print("[ATK] Ranh gioi text/data tu dong o word %d (0x%08X)" % (B, B * 4))
    print("[ATK]   word <  %d : giai ma (.text)" % B)
    print("[ATK]   word >= %d : giu nguyen (.rodata/.data)\n" % B)

    # ---- Buoc 4: ghep ban hoan chinh ----
    full = [dec[i][1] if i < B else enc[i][1] for i in range(len(enc))]
    write_hex(a.out, full)
    print("[ATK] Da ghi firmware hoan chinh ra '%s' (%d word)"
          % (a.out, len(full)))

    # ---- Kiem chung (neu co ban goc) ----
    if a.ref:
        ref = [w for _, w in read_hex(a.ref)]
        if full == ref:
            print("[ATK] TU KIEM CHUNG: khop ban goc 100%% -> ban chay duoc.")
        else:
            diff = [i for i in range(min(len(full), len(ref)))
                    if full[i] != ref[i]]
            print("[ATK] Lech %d word so ban goc, vi tri dau: %s"
                  % (len(diff), diff[:8]))
            print("[ATK] Chinh tay ranh gioi neu can, hoac them cap --known.")


if __name__ == "__main__":
    main()
