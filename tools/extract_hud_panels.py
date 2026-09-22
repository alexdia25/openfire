"""Builds tools/data/hud_panels.json (document 70): the four vehicles' HUD panel layouts, read from the vehicle records at 0x4456b8 (stride 0x2e8).

Transcribed from `DumpDwords.java 0x4456b8 2980` (rectangles are whole pixels relative to the panel; the records store them 16.16):
  fuel bar   = element kind 5, block at record +0x1fc: max (+0x210), top/bottom (+0x218/+0x21c), left/right (+0x220/+0x224)
  radar      = element kind 6 at record +0x270: position (+0x274/+0x278), size (+0x27c/+0x280) ... (Jeep: kind 8, its compass)
  base cel   = 1943 + vehicle index (kind 2's init adds 0x797)
Ammunition bars (record +0x194 / +0x1c8 blocks) are left out: ammunition is not modelled yet.

`weapon_select` (document 83): the Heli's panel slot 8, element kind 9 (`FUN_00412a00`, disassembled since Ghidra never
marked it as code) -- Heli-only, per document 70's panel table. It draws two fixed icons, at panel-relative (91, 20) and
(36, 36), picked from a single flag: `obj+0xc & 0x10000000` (the exact weapon-select bit `FUN_0040e600`/`FUN_0040e7a0`,
document 63, already read/toggle). Bit set (bomb): (91,20)=bomb_lit, (36,36)=gun_dim. Bit clear (gun): (91,20)=bomb_dim,
(36,36)=gun_lit. No live object: both dim.
Usage: python extract_hud_panels.py
"""
import json
import os

# vehicle index -> values transcribed from the dump
panels = {
    "0": {"name": "Tank", "base_cel": 1943, "fuel": {"max": 400, "rect": [88, 12, 127, 15]},
          "weapons": [{"slot": 0, "kind": 4, "rect": [76, 31, 115, 34]}],
          "slot9": {"kind": 6, "pos": [19, 11], "size": [32, 32]}},
    "1": {"name": "Jeep", "base_cel": 1944, "fuel": {"max": 500, "rect": [15, 10, 50, 12]},
          "weapons": [{"slot": 0, "kind": 7}],
          "slot9": {"kind": 8, "pos": [69, 6], "size": [16, 16]}},
    "2": {"name": "MSV", "base_cel": 1945, "fuel": {"max": 320, "rect": [19, 26, 63, 28]},
          "weapons": [{"slot": 0, "kind": 4, "rect": [29, 11, 73, 13]}, {"slot": 1, "kind": 4, "rect": [29, 41, 73, 43]}],
          "slot9": {"kind": 6, "pos": [89, 9], "size": [39, 34]}},
    "3": {"name": "Heli", "base_cel": 1946, "fuel": {"max": 400, "rect": [9, 25, 33, 27]},
          "weapons": [{"slot": 0, "kind": 4, "rect": [55, 45, 103, 47]}, {"slot": 1, "kind": 4, "rect": [110, 25, 135, 27]}],
          "slot9": {"kind": 6, "pos": [56, 5], "size": [32, 32]}},
}
out = {
    "_source": "RFIRE.BIN vehicle records 0x4456b8 (+0x1fc, +0x210..+0x228, +0x270), FUN_00411b70/00411f80/004122d0; documents 68, 70",
    "panel_size": [144, 56],
    # fuel colour words at 0x446760 + colour * 2 (the second word of each pair), the empty part at 0x446758: UNVERIFIED format (document 70)
    "fuel_colour_words": {"6": 0x7F40, "4": 0x7E20, "2": 0x7D20, "0": 0x7C00, "8": 0x4000, "empty": 0x0884},
    # ammunition bars: kind 4 (FUN_00411da0) reads the colour words at 0x446778 + colour * 2, the same way as the fuel bar's (UNVERIFIED format)
    "ammo_colour_words": {"6": 0x41A0, "4": 0x4100, "2": 0x40A0, "0": 0x4000},
    # kind 7 (FUN_004127b0), the Jeep's 16 missile pips: pip i (1..16) at x = PIP_X[i], y = PIP_Y[i] (tables 0x446798 / 0x4467e0), cel 0x20ac0 = 1968 lit
    "pips": {"cel": 1968, "x": [62, 70, 78, 86, 94, 102, 110, 118, 62, 70, 78, 86, 94, 102, 110, 118],
             "y": [21.5] * 8 + [38.5] * 8},
    "panels": panels,
    # kind 9 (FUN_00412a00), Heli only (document 83): two icon positions, each shows a lit/dim cel by the weapon-select bit
    "weapon_select": {
        "bomb_pos": [91, 20], "gun_pos": [36, 36],
        "cels": {"bomb_lit": 1977, "bomb_dim": 1978, "gun_lit": 1979, "gun_dim": 1980},
    },
    # kind 8 (FUN_00412960): cel celtable + 0x20b04 = 1969 for a flag target (negative value), + 0x20b8c = 1971 for home; document 71
    # the vehicle-choice screen (documents 66, 76): mini icons by type index (FUN_004116a0: cels 0x873, 0x871, 0x874, 0x872) and the red digit cels 0x862 + n
    "select": {"icon_cels": [2163, 2161, 2164, 2162], "digit_base_cel": 2146},
    "compass": {"flag_cel": 1969, "home_cel": 1971},
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "hud_panels.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
