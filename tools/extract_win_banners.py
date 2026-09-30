"""Extracts the four victory ribbons the end-of-match sequence shows (document 92) from the game install's TITLE folder into the pack.

FUN_004306b0 / FUN_00430870 load `TITLE/Ban{B,G}{L,H}.bmp`: the index is `winner + (2 if the display mode DAT_00448d5c is 5 or 1 else 0)` into the pointer
table at 0x44e148 = BanBL (winner 0, low), BanGL (winner 1, low), BanBH (0, high), BanGH (1, high). B = the brown/tan ribbon, G = green; L is 180 x 52 (320 x 240
display), H is 360 x 104 (640 x 480).
The BMP itself is a plain opaque rectangle: everything outside the ribbon shape is a solid black fill (confirmed: (0,0,0) is both every sampled corner and the
single most common colour in the file, with no near-black pixels anywhere in the ribbon graphic itself to be caught by an exact match). PORT CHOICE, not traced:
FUN_004306b0's own Blt call (document 92) was read only as "a Blt of the bitmap at x, y", not far enough to confirm whether the original's blit uses a colour-key
(common for DirectDraw sprites of this era) or genuinely paints the black rectangle -- with the video backdrop of issue #60 now behind this ribbon, an opaque
black rectangle would visibly block it, which the reference footage's own look (the ribbon reads as a shield-shaped cutout, not a black box) argues against, so
the black is treated as a colour-key and made transparent.
Writes <pack>/hud/win_banner_{tan,green}_{low,high}.png (the pack is gitignored, like every extracted file).
Usage: python extract_win_banners.py [pack_dir]      (game install from RF_GAME_DIR, default C:/Users/Alex/Documents/returnfire)
"""
import os
import sys

from PIL import Image

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

FILES = {"BANBL.BMP": "win_banner_tan_low", "BANGL.BMP": "win_banner_green_low", "BANBH.BMP": "win_banner_tan_high", "BANGH.BMP": "win_banner_green_high"}

out_dir = os.path.join(PACK_DIR, "hud")
os.makedirs(out_dir, exist_ok=True)
for src, name in FILES.items():
    im = Image.open(os.path.join(GAME_DIR, "TITLE", src)).convert("RGBA")
    pixels = im.getdata()
    im.putdata([(0, 0, 0, 0) if p[:3] == (0, 0, 0) else p for p in pixels])
    im.save(os.path.join(out_dir, name + ".png"))
    print(name, im.size)
