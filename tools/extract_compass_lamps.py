"""Builds the Jeep panel's compass lamp (document 103, kind 8 / FUN_00412960) in all 17 brightness steps and writes it into the pack.

The Jeep's compass is not a reticle: it is a 16 x 16 lamp. FUN_00412960 draws cel 1969 (a flag target, the value is negative) or cel 1971 (home, positive) with a palette taken from
a 17-entry table by |value| (0 to 16). Both tables are made once at start-up by FUN_00424950:

    DAT_00449654 = FUN_00424290(cel1970.PLUT, cel1969.PLUT, 16);     DAT_00449658 = FUN_00424290(cel1972.PLUT, cel1971.PLUT, 16);

FUN_00424290(a, b, 16) builds 17 palettes of 16 bytes; entry j (1..15) of palette k is the game palette's nearest colour (GetNearestPaletteIndex) to
`colour(a[j]) + (colour(b[j]) - colour(a[j])) * k >> 4` per channel, where `x[j]` is the game-palette index stored at byte j of the cel's own 16-byte PLUT (entry 0 stays 0: transparent).
So palette 0 is cel 1970's own PLUT (the dim state) and palette 16 is cel 1969's own PLUT (lit, with the halo pixels). Cels 1969 and 1971 share one PLUT (0x28ad0) and 1970 and 1972 the
other (0x28ae0), so both lamps use the same fade; they differ only in their pixels: 1969 is the green lamp (index 8, the centre, is bright green in the lit palette), 1971 the red one.

Writes <pack>/hud/compass_lamps.png: 17 columns of 16 x 16 (column k = |value| = k), row 0 the flag lamp (negative values), row 1 the home lamp (positive values).
The nearest-colour search is squared RGB distance, lowest palette index on a tie (GDI's exact tie rule is not verified). The pack is gitignored, like every extracted file.
Usage: python extract_compass_lamps.py [pack_dir]      (game install from RF_GAME_DIR, default C:/Users/Alex/Documents/returnfire)
"""
import os
import struct
import sys

from PIL import Image

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

CCB_SIZE = 68
STEPS = 16          # FUN_00424290's third argument: 17 palettes, 0 .. 16
CELS = ((1969, 1970), (1971, 1972))   # (the lamp, the cel whose PLUT is the dim end), flag row then home row
SIZE = 16

with open(os.path.join(GAME_DIR, "ART", "ART.CAR"), "rb") as f:
    data = f.read()


def cel(n):
    v = struct.unpack_from("<17I", data, 16 + n * CCB_SIZE)
    return {"src": v[2], "plut": v[3], "w": v[15], "h": v[16]}


# The game's 256-colour palette: a LOGPALETTE 0x400 bytes after cel 0's PLUT (FUN_00424420: `DAT_0046aa18 = *(cel0 + 0xc) + 0x400`); entries are (R, G, B, flags).
shared = cel(0)["plut"]
pal_at = shared + 0x400 + 4
assert data[pal_at - 4:pal_at - 2] == b"\x00\x03", "not a LOGPALETTE (version 0x300)"
master = [(data[pal_at + i * 4], data[pal_at + i * 4 + 1], data[pal_at + i * 4 + 2]) for i in range(256)]
# cross-check with the runtime palette the rest of the pack uses (document 20: runtime[10 + i] = shared PLUT[i])
for i in range(0, 246):
    o = shared + i * 4
    assert master[10 + i] == (data[o + 2], data[o + 1], data[o]), "palette differs at %d" % (10 + i)


def nearest(rgb):
    best = min(range(256), key=lambda i: (sum((a - b) ** 2 for a, b in zip(master[i], rgb)), i))
    return best


def palette(a_plut, b_plut, k):
    """FUN_00424290's palette k: from the first cel's PLUT (k = 0) to the second's (k = 16); entry 0 is transparent."""
    out = [None] * 16
    for j in range(1, 16):
        p1 = master[data[a_plut + j]]
        p2 = master[data[b_plut + j]]
        rgb = tuple((p1[c] + (((p2[c] - p1[c]) * k) >> 4)) & 0xFF for c in range(3))
        out[j] = nearest(rgb)
    return out


sheet = Image.new("RGBA", ((STEPS + 1) * SIZE, len(CELS) * SIZE), (0, 0, 0, 0))
for row, (lamp, dim) in enumerate(CELS):
    c = cel(lamp)
    assert (c["w"], c["h"]) == (SIZE, SIZE)
    a_plut, b_plut = cel(dim)["plut"], c["plut"]
    for k in range(STEPS + 1):
        pal = palette(a_plut, b_plut, k)
        for y in range(SIZE):
            for x in range(SIZE):
                idx = data[c["src"] + y * SIZE + x]
                if idx == 0:
                    continue   # transparent
                sheet.putpixel((k * SIZE + x, row * SIZE + y), master[pal[idx]] + (255,))

out_dir = os.path.join(PACK_DIR, "hud")
os.makedirs(out_dir, exist_ok=True)
sheet.save(os.path.join(out_dir, "compass_lamps.png"))
print("compass_lamps.png", sheet.size)
