"""Draws each level's preview picture the way the original's Level Selector does (document 125, issue #83).

Dialog procedure FUN_00425490 / FUN_00426130: when a level is picked in the list the game reads the .RFM's 128 x 128 tile bytes (at the offset the u32 at 0x48 gives) and
draws each tile as the 2 x 2 pixel pattern `ART\2X2.RFA` holds for that byte (a 40 x 24 bitmap: 20 x 12 patterns, byte b at column b % 20, row b // 20; its own palette),
a 256 x 256 picture. The spawn and candidate markers (tile bytes 0x39, 0x4D, 0xB4, 0xDC) are drawn too. Writes <pack>/levels/<NAME>/preview.png for every level in WORLDS.
Usage: python extract_level_previews.py [pack_dir]      (game install from RF_GAME_DIR, default C:/Users/Alex/Documents/returnfire)
"""
import io
import os
import struct
import sys

from PIL import Image

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")


def main():
    with open(os.path.join(GAME_DIR, "ART", "2X2.RFA"), "rb") as f:
        pat = Image.open(io.BytesIO(f.read())).convert("RGB")
    n = 0
    for root, _dirs, files in os.walk(os.path.join(GAME_DIR, "WORLDS")):
        for name in files:
            if not name.upper().endswith(".RFM"):
                continue
            with open(os.path.join(root, name), "rb") as f:
                data = f.read()
            off = struct.unpack_from("<I", data, 0x48)[0]
            tiles = data[off:off + 128 * 128]
            if len(tiles) < 128 * 128:
                continue
            out_dir = os.path.join(PACK_DIR, "levels", os.path.splitext(name)[0])
            if not os.path.isdir(out_dir):
                continue
            img = Image.new("RGB", (256, 256))
            for y in range(128):
                for x in range(128):
                    b = tiles[y * 128 + x]
                    bx, by = (b % 20) * 2, (b // 20) * 2
                    for dy in (0, 1):
                        for dx in (0, 1):
                            img.putpixel((x * 2 + dx, y * 2 + dy), pat.getpixel((bx + dx, by + dy)))
            img.save(os.path.join(out_dir, "preview.png"))
            n += 1
    print("level previews:", n)


main()
