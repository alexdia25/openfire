"""Builds tools/data/hud_panels.json (document 70): the four vehicles' HUD panel layouts, read from the vehicle records at 0x4456b8 (stride 0x2e8).

Transcribed from `DumpDwords.java 0x4456b8 2980` (rectangles are whole pixels relative to the panel; the records store them 16.16):
  fuel bar   = element kind 5, block at record +0x1fc: max (+0x210), top/bottom (+0x218/+0x21c), left/right (+0x220/+0x224)
  radar      = element kind 6 at record +0x270: position (+0x274/+0x278), size (+0x27c/+0x280) ... (Jeep: kind 8, its compass)
  base cel   = 1943 + vehicle index (kind 2's init adds 0x797)
Ammunition bars (record +0x194 / +0x1c8 blocks) are left out: ammunition is not modelled yet.
Usage: python extract_hud_panels.py
"""
import json
import os

# vehicle index -> values transcribed from the dump
panels = {
    "0": {"name": "Tank", "base_cel": 1943, "fuel": {"max": 400, "rect": [88, 12, 127, 15]},
          "slot9": {"kind": 6, "pos": [19, 11], "size": [32, 32]}},
    "1": {"name": "Jeep", "base_cel": 1944, "fuel": {"max": 500, "rect": [15, 10, 50, 12]},
          "slot9": {"kind": 8, "pos": [69, 6], "size": [16, 16]}},
    "2": {"name": "MSV", "base_cel": 1945, "fuel": {"max": 320, "rect": [19, 26, 63, 28]},
          "slot9": {"kind": 6, "pos": [89, 9], "size": [39, 34]}},
    "3": {"name": "Heli", "base_cel": 1946, "fuel": {"max": 400, "rect": [9, 25, 33, 27]},
          "slot9": {"kind": 6, "pos": [56, 5], "size": [32, 32]}},
}
out = {
    "_source": "RFIRE.BIN vehicle records 0x4456b8 (+0x1fc, +0x210..+0x228, +0x270), FUN_00411b70/00411f80/004122d0; documents 68, 70",
    "panel_size": [144, 56],
    # fuel colour words at 0x446760 + colour * 2 (the second word of each pair), the empty part at 0x446758: UNVERIFIED format (document 70)
    "fuel_colour_words": {"6": 0x7F40, "4": 0x7E20, "2": 0x7D20, "0": 0x7C00, "8": 0x4000, "empty": 0x0884},
    "panels": panels,
    # kind 8 (FUN_00412960): cel celtable + 0x20b04 = 1969 for a flag target (negative value), + 0x20b8c = 1971 for home; document 71
    "compass": {"flag_cel": 1969, "home_cel": 1971},
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "hud_panels.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
