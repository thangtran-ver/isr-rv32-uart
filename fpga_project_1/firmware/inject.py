#!/usr/bin/env python3
"""
inject.py — mo phong attacker tiem ma (Buoc 7 cua de tai)
Ghi de mot so word trong file hex DA MA HOA bang lenh PLAINTEXT
(chua qua encoder), dung nhu tinh huong tran bo dem ghi shellcode vao .text.
"""
import argparse, sys

p = argparse.ArgumentParser()
p.add_argument("input"); p.add_argument("output")
p.add_argument("--at", type=lambda s: int(s, 0), required=True,
               help="dia chi BYTE bat dau tiem")
p.add_argument("--n", type=int, default=4, help="so lenh tiem vao")
a = p.parse_args()


PAYLOAD = [
    0x00002083,   # lw   x1, 0(x0)
    0x00102023,   # sw   x1, 0(x0)
    0x001080b3,   # add  x1, x1, x1
    0x0000006f]

out, cur, n_inj = [], 0, 0
for raw in open(a.input):
    s = raw.strip()
    if not s:
        continue
    if s.startswith("@"):
        cur = int(s[1:], 16); out.append(s); continue
    toks = []
    for t in s.split():
        addr = cur * 4
        if a.at <= addr < a.at + a.n * 4:
            toks.append("%08x" % PAYLOAD[((addr - a.at) // 4) % len(PAYLOAD)])
            n_inj += 1
        else:
            toks.append(t)
        cur += 1
    out.append(" ".join(toks))

open(a.output, "w").write("\n".join(out) + "\n")
print(f"[INFO] Tiem {n_inj} lenh plaintext tai 0x{a.at:08X} -> '{a.output}'")
if n_inj == 0:
    sys.exit("[FAIL] Khong tiem duoc word nao — kiem tra lai --at")
