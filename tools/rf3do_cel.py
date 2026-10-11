"""Decode the 3DO version's Art.carr cels, and line them up against the PC's ART.CAR (issue #97, Phase 7).

Art.carr uses the same "CCBA" container as the PC's ART/ART.CAR (tools/convert_car.py), but big-endian, and its
cels are real 3DO cels rather than the PC's flattened 8 bpp ones:

    0x00  "CCBA", u32 file size, u32 cel count, u32 (not the CCB array's end, unlike the PC)
    0x10  CCB[count], 17 x u32 BE: Flags, Next, SourcePtr, PLUTPtr, X, Y, HDX, HDY, VDX, VDY, HDDX, HDDY,
          PIXC, PRE0, PRE1, Width, Height. SourcePtr and PLUTPtr are file offsets, as on the PC.
    Flags 0x200 = CCB_PACKED, 0x20 = CCB_BGND
    PRE0  bits 0-2 = bpp code (1,2,3,4,5,6 -> 1,2,4,6,8,16 bpp), 0x10 = linear (no PLUT), bits 6-15 = rows - 1
    PRE1  bits 0-10 = width - 1; unpacked row stride = (WOFFSET + 2) words, WOFFSET8 = bits 24-31 below 8 bpp,
          WOFFSET10 = bits 16-25 at 8/16 bpp
    PLUT  32 x u16 BE RGB555, one per cel (not the PC's shared RGBQUAD palette)
    packed rows: row offset (8 bits below 8 bpp, else 10 bits + 6 pad) -> next row at (offset + 2) words;
          then packets of 2-bit type + 6-bit count-1: 0 end of row, 1 literal, 2 transparent, 3 repeat one pixel

Unverified assumptions, from the 3DO hardware documentation rather than traced in the game:
  - a pixel is transparent when its PLUT output is 0 and BGND is clear;
  - the PIXC blend is ignored, so shadows and glows draw as plain colour.
The PC side reads only the CCB headers (sizes), for the alignment report; it does not decode PC pixels.

    python tools/rf3do_cel.py <Art.carr> --sheet [first] [count]   contact sheet -> build/3do/cels_<first>.png
    python tools/rf3do_cel.py <Art.carr> --align                   3DO vs PC cel order, by size (RF_GAME_DIR)
    python tools/rf3do_cel.py <Art.carr> --stats                   PRE0 / flag histogram
"""
import difflib
import os
import struct
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
BPP = {1: 1, 2: 2, 3: 4, 4: 6, 5: 8, 6: 16}
CCB_SIZE = 68


def load(path, endian=">"):
    data = open(path, "rb").read()
    if data[:4] != b"CCBA":
        raise ValueError("%s is not a CCBA cel array" % path)
    count = struct.unpack_from(endian + "I", data, 8)[0]
    return data, [struct.unpack_from(endian + "17I", data, 16 + n * CCB_SIZE) for n in range(count)]


class _Bits:
    def __init__(self, data, pos):
        self.data, self.bit = data, pos * 8

    def get(self, n):
        v = 0
        for _ in range(n):
            v = (v << 1) | ((self.data[self.bit >> 3] >> (7 - (self.bit & 7))) & 1)
            self.bit += 1
        return v


def rgb555(v):
    return ((v >> 10) & 31) * 255 // 31, ((v >> 5) & 31) * 255 // 31, (v & 31) * 255 // 31


def decode(data, ccb):
    """One cel -> (width, height, RGBA bytes)."""
    flags, _next, src, plut = ccb[:4]
    pre0, pre1, w, h = ccb[13], ccb[14], ccb[15], ccb[16]
    bpp = BPP.get(pre0 & 7)
    if bpp is None:
        raise ValueError("unknown bpp code %d" % (pre0 & 7))
    packed, linear, bgnd = bool(flags & 0x200), bool(pre0 & 0x10), bool(flags & 0x20)
    pal = [struct.unpack_from(">H", data, plut + 2 * i)[0] for i in range(32)] if plut + 64 <= len(data) else [0] * 32
    out = bytearray(w * h * 4)

    def put(x, y, v):
        if x >= w:
            return
        col = (v if (bpp == 16 or linear) else pal[v & 31]) & 0x7fff
        if col == 0 and not bgnd:
            return
        o = (y * w + x) * 4
        out[o:o + 4] = bytes(rgb555(col) + (255,))

    pos = src
    for y in range(h):
        bits = _Bits(data, pos)
        if not packed:
            for x in range(w):
                put(x, y, bits.get(bpp))
            woff = ((pre1 >> 16) & 0x3ff) if bpp >= 8 else ((pre1 >> 24) & 0xff)
            pos += (woff + 2) * 4
            continue
        offset = bits.get(10 if bpp >= 8 else 8)
        if bpp >= 8:
            bits.get(6)
        x = 0
        while x < w:
            kind = bits.get(2)
            if kind == 0:
                break
            n = bits.get(6) + 1
            if kind == 1:
                for _ in range(n):
                    put(x, y, bits.get(bpp))
                    x += 1
            elif kind == 2:
                x += n
            else:
                v = bits.get(bpp)
                for _ in range(n):
                    put(x, y, v)
                    x += 1
        pos += (offset + 2) * 4
    return w, h, bytes(out)


def sheet(data, ccbs, first, count, path, cell=72, cols=16):
    from PIL import Image  # only the contact sheet needs Pillow
    rows = (count + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell, rows * cell), (48, 48, 72, 255))
    for k, n in enumerate(range(first, min(first + count, len(ccbs)))):
        w, h, rgba = decode(data, ccbs[n])
        cel = Image.frombytes("RGBA", (w, h), rgba)
        cel.thumbnail((cell - 4, cell - 4))
        img.alpha_composite(cel, ((k % cols) * cell + 2, (k // cols) * cell + 2))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(path)
    return path


def align(ccbs_3do, ccbs_pc):
    """Line the two cel sequences up by (width, height). A size match is a lead, not an identity: the real
    3DO cel -> sprite id table has to be traced in the 3DO rfire (issue #97)."""
    a = [(c[15], c[16]) for c in ccbs_3do]
    b = [(c[15], c[16]) for c in ccbs_pc]
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            print("%-7s 3DO %4d-%-4d PC %4d-%-4d  %s | %s" % (tag, i1, i2, j1, j2, a[i1:i2][:4], b[j1:j2][:4]))
    print("%d of %d 3DO cels line up by size with the PC's %d" % (sum(m.size for m in sm.get_matching_blocks()),
                                                                 len(a), len(b)))


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    data, ccbs = load(argv[0])
    if "--stats" in argv:
        print("%d cels" % len(ccbs))
        print("flags", [(hex(k), v) for k, v in Counter(c[0] for c in ccbs).most_common()])
        print("bpp", sorted(Counter(BPP.get(c[13] & 7) for c in ccbs).items(), key=str))
        print("packed", sum(1 for c in ccbs if c[0] & 0x200))
    if "--align" in argv:
        _pc_data, pc = load(os.path.join(GAME_DIR, "ART", "ART.CAR"), "<")
        align(ccbs, pc)
    if "--sheet" in argv:
        rest = [int(x) for x in argv[argv.index("--sheet") + 1:] if x.isdigit()]
        first = rest[0] if rest else 0
        count = rest[1] if len(rest) > 1 else 128
        print(sheet(data, ccbs, first, count, os.path.join(REPO, "build", "3do", "cels_%04d.png" % first)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
