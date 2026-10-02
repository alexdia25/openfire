"""Extracts the one-player HUD backdrop strip (document 96) from the game install's ART folder into the pack.

`1PBSCRL.RFA` (320 x 88) and `1PBSCRH.RFA` (640 x 176) are plain BMPs (see convert_rfa.py): the bottom strip of the original's one-player screen, drawn below the 320 x 152
game view at y = 152 (the 240-high screen): the camouflage wallpaper, the metal rail across the top, and the frame with a black window where the vehicle's panel is drawn.
Which of the two the game uses depends on the display mode (the same DAT_00448d5c as the victory ribbons, document 92). The two-player strips (`2PBSCRL/H.RFA`) are not extracted.
Writes <pack>/hud/strip_1p_{low,high}.png (the pack is gitignored, like every extracted file).
Usage: python extract_hud_strip.py [pack_dir]      (game install from RF_GAME_DIR, default C:/Users/Alex/Documents/returnfire)
"""
import io
import os
import sys

from PIL import Image

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

# NEWREQLG.RFA (640 x 480) / NEWREQSM.RFA (320 x 240) are the front end's picture (document 122, issue #51): "PRESS 'F2' TO BEGIN".
FILES = {"1PBSCRL.RFA": "strip_1p_low", "1PBSCRH.RFA": "strip_1p_high", "NEWREQLG.RFA": "title_large", "NEWREQSM.RFA": "title_small"}

TITLE_BAR_TEXT_ROWS = {"title_large": (456, 475), "title_small": (229, 237)}   # the bottom bar's rows ("PRESS 'F2' TO BEGIN"): the text is painted out, the port writes its own

out_dir = os.path.join(PACK_DIR, "hud")
os.makedirs(out_dir, exist_ok=True)
for src, name in FILES.items():
    with open(os.path.join(GAME_DIR, "ART", src), "rb") as f:
        im = Image.open(io.BytesIO(f.read())).convert("RGB")
    if name in TITLE_BAR_TEXT_ROWS:
        y0, y1 = TITLE_BAR_TEXT_ROWS[name]
        for y in range(y0, y1 + 1):
            c = im.getpixel((2, y))
            for x in range(im.width):
                im.putpixel((x, y), c)
    im.save(os.path.join(out_dir, name + ".png"))
    print(name, im.size)
