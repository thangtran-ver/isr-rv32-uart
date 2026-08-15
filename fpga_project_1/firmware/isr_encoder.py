
import argparse
import struct
import sys

DEFAULT_KEY = 0xA5A5A5A5
WORD_MASK = 0xFFFFFFFF
SHF_ALLOC = 0x2
SHF_EXECINSTR = 0x4
# ==========================================================
#  Sinh khoa — PHAI khop bit-exact voi rtl/isr_decoder.v
# ==========================================================
def xorshift32(x):
    x &= WORD_MASK
    a = (x ^ (x << 13)) & WORD_MASK
    b = (a ^ (a >> 17)) & WORD_MASK
    c = (b ^ (b << 5)) & WORD_MASK
    return c
# ---- MODE 3: ham gia ngau nhien PHI TUYEN (S-box PRESENT) ----
SBOX = [0xC,0x5,0x6,0xB,0x9,0x0,0xA,0xD,0x3,0xE,0xF,0x8,0x4,0x7,0x1,0x2]

def sbox_layer(x):
    r = 0
    for i in range(8):
        r |= SBOX[(x >> (4 * i)) & 0xF] << (4 * i)
    return r

def rotl(x, n):
    return ((x << n) | (x >> (32 - n))) & WORD_MASK

def prf3(x, key):
    """3 vong: S-box -> khuech tan tuyen tinh -> tron khoa."""
    for _ in range(3):  
        x = sbox_layer(x)
        x = (x ^ rotl(x, 7) ^ rotl(x, 19)) & WORD_MASK
        x ^= key
    return x & WORD_MASK

def key_eff(mode, key, byte_addr):
    key &= WORD_MASK
    if mode == 0:
        return 0
    if mode == 1:
        return key
    if mode == 2:
        pc_word = byte_addr & 0xFFFFFFFC
        return (xorshift32(pc_word ^ key) ^ key) & WORD_MASK
    if mode == 3:
        pc_word = byte_addr & 0xFFFFFFFC
        return prf3(pc_word ^ key, key)
    raise ValueError("mode phai la 0, 1, 2 hoac 3")

def elf_exec_ranges(path):
    with open(path, "rb") as f:
        data = f.read()

    if data[:4] != b"\x7fELF":
        sys.exit(f"[FAIL] '{path}' khong phai file ELF")
    if data[4] != 1:
        sys.exit("[FAIL] Chi ho tro ELF32 (rv32).")
    if data[5] != 1:
        sys.exit("[FAIL] Chi ho tro little-endian.")

    e_shoff, = struct.unpack_from("<I", data, 0x20)
    e_shentsize, = struct.unpack_from("<H", data, 0x2E)
    e_shnum, = struct.unpack_from("<H", data, 0x30)
    e_shstrndx, = struct.unpack_from("<H", data, 0x32)

    def sh(i):
        off = e_shoff + i * e_shentsize
        (name, stype, flags, addr, offset,
         size, link, info, align, entsize) = struct.unpack_from("<10I", data, off)
        return dict(name=name, type=stype, flags=flags, addr=addr,
                    offset=offset, size=size)

    strtab = sh(e_shstrndx)
    def sname(off):
        base = strtab["offset"] + off
        end = data.index(b"\0", base)
        return data[base:end].decode()

    ranges = []
    allsecs = []
    for i in range(e_shnum):
        s = sh(i)
        nm = sname(s["name"])
        if s["size"] == 0 or not (s["flags"] & SHF_ALLOC):
            continue
        execflag = bool(s["flags"] & SHF_EXECINSTR)
        allsecs.append((nm, s["addr"], s["size"], execflag))
        if execflag:
            end = (s["addr"] + s["size"] + 3) & ~3   # lam tron len bien word
            ranges.append((s["addr"] & ~3, end, nm))

    return sorted(ranges), allsecs

def merge_ranges(ranges):
    """Gop cac vung ke nhau / chong nhau, bo ten section."""
    out = []
    for start, end, _nm in sorted(ranges):
        if out and start <= out[-1][1]:
            out[-1][1] = max(out[-1][1], end)
        else:
            out.append([start, end])
    return [(a, b) for a, b in out]

def in_ranges(addr, ranges):
    for a, b in ranges:
        if a <= addr < b:
            return True
    return False


def read_hex_file(path):
    
    words, addr_lines, byte_addrs = [], [], []
    cur_word_index = 0

    with open(path, "r") as f:
        for line_num, raw in enumerate(f, start=1):
            line = raw.strip()
            if not line or line.startswith("//") or line.startswith("#"):
                continue

            if line.startswith("@"):
                try:
                    addr_val = int(line[1:].strip(), 16)
                except ValueError:
                    print(f"[WARN] Dong {line_num}: dia chi khong hop le '{line}'",
                          file=sys.stderr)
                    continue
                addr_lines.append((len(words), addr_val))
                cur_word_index = addr_val
                continue

            for token in line.split():
                if len(token) <= 2:
                    sys.exit(f"[FAIL] Dong {line_num}: token '{token}' qua ngan — "
                             f"file xuat theo byte.\n"
                             f"       Dung: objcopy -O verilog --verilog-data-width=4")
                try:
                    value = int(token, 16) & WORD_MASK
                except ValueError:
                    print(f"[WARN] Dong {line_num}: bo qua token '{token}'",
                          file=sys.stderr)
                    continue
                words.append(value)
                byte_addrs.append(cur_word_index * 4)
                cur_word_index += 1

    return words, addr_lines, byte_addrs

def write_hex_file(path, words, addr_lines, words_per_line=4):
    """Ghi lai, giu DUNG moi dong '@' ke ca dong lien tiep / dong cuoi file."""
    # gom nhieu '@' co cung vi tri thanh list
    pending = {}
    for idx, addr in addr_lines:
        pending.setdefault(idx, []).append(addr)

    with open(path, "w") as f:
        if not addr_lines:
            for w in words:
                f.write(f"{w & WORD_MASK:08x}\n")
            return

        buf = []
        def flush():
            nonlocal buf
            if buf:
                f.write(" ".join(buf) + "\n")
                buf = []

        for i, w in enumerate(words):
            if i in pending:
                flush()
                for a in pending.pop(i):
                    f.write(f"@{a:08x}\n")
            buf.append(f"{w & WORD_MASK:08x}")
            if len(buf) == words_per_line:
                flush()
        flush()
        # cac dong '@' nam sau word cuoi cung
        for i in sorted(pending):
            for a in pending[i]:
                f.write(f"@{a:08x}\n")



def isr_transform(words, byte_addrs, key, mode, ranges):
    out, n_enc = [], 0
    for w, addr in zip(words, byte_addrs):
        if in_ranges(addr, ranges):
            out.append((w ^ key_eff(mode, key, addr)) & WORD_MASK)
            n_enc += 1
        else:
            out.append(w & WORD_MASK)
    return out, n_enc


def parse_key(s):
    return int(s, 16) if s.lower().startswith("0x") else int(s)


def parse_range(s):
    if ":" not in s:
        raise argparse.ArgumentTypeError("dinh dang phai la START:END, vd 0x0:0x400")
    a, b = s.split(":", 1)
    return (int(a, 0), int(b, 0))


def resolve_ranges(args):
    """Uu tien: --text-range > --from-elf > --text-end > that bai."""
    if args.text_range:
        rs = merge_ranges([(a, b, "cli") for a, b in args.text_range])
        print("[INFO] Vung .text lay tu --text-range")
        return rs

    if args.from_elf:
        raw, allsecs = elf_exec_ranges(args.from_elf)
        print(f"[INFO] Section trong '{args.from_elf}':")
        for nm, addr, size, ex in allsecs:
            tag = "EXEC" if ex else "data"
            print(f"       {tag}  {nm:<16} 0x{addr:08X} .. 0x{addr+size:08X}"
                  f"  ({size} B)")
        if not raw:
            sys.exit("[FAIL] Khong tim thay section thuc thi nao trong ELF.")
        rs = merge_ranges(raw)
        print("[INFO] Vung se ma hoa (SHF_EXECINSTR):")
        for a, b in rs:
            print(f"       [0x{a:08X}, 0x{b:08X})")
        return rs

    if args.text_end is not None:
        return [(args.text_start, args.text_end)]

    sys.exit("[FAIL] Phai chi dinh --from-elf, hoac --text-range, hoac --text-end.\n"
             "       Khong doan ranh gioi nua — doan sai la CPU chay rac.")

def main():
    ap = argparse.ArgumentParser(
        description="ISR Encoder cho de tai ISR-RV32 (PicoRV32)")
    ap.add_argument("input", help="File .hex goc (chua ma hoa)")
    ap.add_argument("output", help="File .hex xuat ra (da ma hoa)")
    ap.add_argument("--key", default=hex(DEFAULT_KEY), help="vd 0x5A5A5A5A")
    ap.add_argument("--mode", type=int, default=1, choices=[0, 1, 2, 3],
                    help="0=bypass 1=XOR co dinh 2=phu thuoc PC 3=PRF phi tuyen")
    ap.add_argument("--from-elf", default=None,
                    help="Lay vung thuc thi tu file .elf (khuyen dung)")
    ap.add_argument("--text-range", type=parse_range, action="append",
                    help="START:END dia chi BYTE, lap lai duoc nhieu lan")
    ap.add_argument("--text-start", type=lambda s: int(s, 0), default=0)
    ap.add_argument("--text-end", type=lambda s: int(s, 0), default=None)
    ap.add_argument("--map", default=None, help="Ghi ban do word da ma hoa")
    args = ap.parse_args()

    key = parse_key(args.key)
    words, addr_lines, byte_addrs = read_hex_file(args.input)
    print(f"[INFO] Doc {len(words)} word tu '{args.input}' "
          f"({len(addr_lines)} dong '@')")

    ranges = resolve_ranges(args)
    encoded, n_enc = isr_transform(words, byte_addrs, key, args.mode, ranges)
    write_hex_file(args.output, encoded, addr_lines)

    print(f"[INFO] Da ma hoa : {n_enc}/{len(words)} word, "
          f"mode={args.mode}, key=0x{key:08X}")
    print(f"[INFO] Giu nguyen: {len(words)-n_enc} word (du lieu)")

    back, _ = isr_transform(encoded, byte_addrs, key, args.mode, ranges)
    if back != words:
        sys.exit("[FAIL] Giai ma nguoc KHONG khop ban goc!")
    print("[INFO] Self-check giai ma nguoc: OK")

    # doc lai file vua ghi de chac chan cau truc '@' khong bi mat
    rw, ral, rba = read_hex_file(args.output)
    if rw != encoded or rba != byte_addrs:
        sys.exit("[FAIL] Round-trip file: cau truc '@' bi sai khi ghi ra.")
    print("[INFO] Round-trip cau truc file  : OK")

    if args.map:
        with open(args.map, "w") as f:
            for w0, w1, a in zip(words, encoded, byte_addrs):
                tag = "TEXT" if in_ranges(a, ranges) else "data"
                f.write(f"0x{a:08X} {tag} {w0:08x} -> {w1:08x}\n")
        print(f"[INFO] Ghi ban do ma hoa ra '{args.map}'")


    print(f"[INFO] Ghi ket qua ra '{args.output}'")

if __name__ == "__main__":
    main()
