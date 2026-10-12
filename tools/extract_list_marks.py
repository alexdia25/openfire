"""Extracts the Level Selector's three list marks (document 128, issue #102) from RFIRE.BIN's bitmap resources into the pack.

FUN_00425490 (the Level Selector's dialog procedure) builds the list's image list with `ImageList_Create(16, 16, ...)`, loads bitmap resource 0x7da (the picture, 4 bits a
pixel) and 0x7d9 (the mask, 1 bit) and adds them: three round 16 x 16 icons side by side. The icon a map shows is its state (FUN_00424f60, LVITEM.iImage): 0 not done,
1 won, 2 started 20 or more times (document 128). In the mask a set bit is transparent (ImageList_Add's convention); the output is one 48 x 16 RGBA strip.
Writes <pack>/ui/list_marks.png. Usage: python extract_list_marks.py [pack_dir]      (game install from RF_GAME_DIR)
"""
import os
import struct
import sys

from PIL import Image

import rfexe

PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")
IDS = [(0x7DA, 0x7D9), (0x418, 0x419)]   # the install's build, then the CD's (same bytes, renumbered; issue #122)


def dib(data):
    """A device-independent bitmap (as stored in a resource) as (width, height, [row of (r, g, b) per pixel], top row first)."""
    hs, w, h, _planes, bpp = struct.unpack_from("<IiiHH", data, 0)
    ncol = struct.unpack_from("<I", data, 32)[0] or (1 << bpp)
    pal = [(data[hs + i * 4 + 2], data[hs + i * 4 + 1], data[hs + i * 4]) for i in range(ncol)]
    stride = ((w * bpp + 31) // 32) * 4
    base = hs + ncol * 4
    rows = []
    for y in range(h - 1, -1, -1):   # bottom-up
        row = data[base + y * stride:base + (y + 1) * stride]
        px = []
        for x in range(w):
            if bpp == 4:
                v = (row[x // 2] >> (4 if x % 2 == 0 else 0)) & 15
            elif bpp == 1:
                v = (row[x // 8] >> (7 - x % 8)) & 1
            else:
                v = row[x]
            px.append(pal[v])
        rows.append(px)
    return w, h, rows


picture = mask = None
for pid, mid in IDS:
    picture, mask = rfexe.resource(2, pid), rfexe.resource(2, mid)
    if picture is not None and mask is not None:
        break
if picture is None or mask is None:
    print("RFIRE.BIN has no bitmap resources 0x7da / 0x7d9 or 0x418 / 0x419: no list marks (the engine draws its own)")
    sys.exit(0)
w, h, pic = dib(picture)
mw, mh, msk = dib(mask)
assert (w, h) == (mw, mh), "the picture and its mask differ in size"
img = Image.new("RGBA", (w, h))
for y in range(h):
    for x in range(w):
        r, g, b = pic[y][x]
        transparent = msk[y][x] == (255, 255, 255)
        img.putpixel((x, y), (0, 0, 0, 0) if transparent else (r, g, b, 255))
os.makedirs(os.path.join(PACK_DIR, "ui"), exist_ok=True)
img.save(os.path.join(PACK_DIR, "ui", "list_marks.png"))
print("list_marks", img.size)
