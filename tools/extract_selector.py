"""Builds tools/data/selector.json (document 78): the docked vehicle-choice screen ("the hangar"), read from RFIRE.BIN.

Transcribed from DumpDwords.java dumps and the decompiled FUN_00417d60 (draw), FUN_00417500 (backdrop), FUN_004116a0 (counts) and the confirm scripts:
  table 0x4491c0, 0x28 bytes per vehicle type: eight 16.16 pairs -> picture, pointer, highlight and box positions (relative to the hangar cel),
    then a pointer to the type's confirm script (+0x20) and four neighbour bytes (+0x24..0x27 = up, down, left, right; document 78 corrects document 76's order)
  hangar cel 0x2272c / 0x44 = 2075 (132 x 123), centred on the screen; the y comes from FUN_00417500.
  cels = offset / 0x44: box 0x227f8 = 2078, highlight 0x227b4 = 2077, pointer 0x22b6c + n * 0x44 = 2091 + n, pictures 0x22c38 + (type * 2 + team) * 0x44 = 2094 + ...,
    platform cap 0x22770 = 2076, platform body 0x2283c = 2079, backdrop strips 0x22990 = 2084, 0x229d4 = 2085 / 2086, clouds 0x22a5c = 2087..2089, dirt 0x22880 = 2080..2083,
    the map frame 0x22b28 = 2090, the radar bitmap cel 0x7bd / 0x7be = 1981 / 1982, panel interior 0x203d8 = 1942.
  confirm scripts: steps {callback, p1, p2, p3, continue}: 0x417810 a sound (p1 = index into table 0x449260, p2 pitch, p3 length),
    0x417a90 platform up (state +0xd0 -= p1 * dt until <= p2), 0x417a40 the picture slides sideways (state +0xd4 += p1 * dt until it passes p2),
    0x4179f0 platform and picture up together (+0xd0, +0xd8 -= p1 * dt until +0xd0 <= p2), 0x417990 both go on up while the fade (+0xbc) falls by p2 * dt, then the vehicle is released,
    0x417900 clears the panel elements.
Usage: python extract_selector.py
"""
import json
import os

# per type index (Tank, Jeep, MSV, Heli): positions in whole pixels, relative to the hangar cel
entries = {
    0: {"name": "Tank", "picture": [85, 54], "pointer": [87, 73], "highlight": [85, 52], "box": [87, 45], "script": "0x449108", "up": 0, "down": 1, "left": 3, "right": 0},
    1: {"name": "Jeep", "picture": [85, 92], "pointer": [87, 112], "highlight": [85, 90], "box": [87, 83], "script": "0x448fc0", "up": 0, "down": 1, "left": 2, "right": 1},
    2: {"name": "MSV", "picture": [13, 92], "pointer": [12, 112], "highlight": [13, 90], "box": [15, 83], "script": "0x448f30", "up": 3, "down": 2, "left": 2, "right": 1},
    3: {"name": "Heli", "picture": [13, 54], "pointer": [12, 73], "highlight": [13, 52], "box": [15, 45], "script": "0x449050", "up": 3, "down": 2, "left": 3, "right": 0},
}

# the four scripts, decoded step by step from the dumps (fixed point 16.16 shown as floats)
scripts = {
    "Tank": [["sound", 0, -1.0, 66], ["platform_up", 0.5, 72.0], ["sound", 0, -0.75, 46], ["slide", -0.5, -35.0], ["sound", 1, -0.85, 240], ["clear_panel"],
             ["rise_with_picture", 0.5, 60.0], ["rise_and_fade", 0.5, 0.0702]],
    "Jeep": [["sound", 0, -0.75, 46], ["slide", -0.5, -35.0], ["sound", 1, -0.85, 240], ["clear_panel"], ["rise_with_picture", 0.5, 80.0], ["rise_and_fade", 0.5, 0.0702]],
    "MSV": [["sound", 0, -0.75, 46], ["slide", 0.5, 36.0], ["sound", 1, -0.85, 240], ["clear_panel"], ["rise_with_picture", 0.5, 80.0], ["rise_and_fade", 0.5, 0.0702]],
    "Heli": [["sound", 0, -1.0, 66], ["platform_up", 0.5, 72.0], ["sound", 0, -0.75, 46], ["slide", 0.5, 36.0], ["sound", 1, -0.85, 240], ["clear_panel"],
             ["rise_with_picture", 0.5, 60.0], ["rise_and_fade", 0.5, 0.0702]],
}

out = {
    "_source": "RFIRE.BIN table 0x4491c0, FUN_00417d60 / 00417500 / 004116a0 / 00417810..00417a90, scripts 0x448f30 0x448fc0 0x449050 0x449108; document 78",
    "screen": [320, 240],
    "hangar": {"cel": 2075, "size": [132, 123], "y": 22},
    "entries": {str(k): v for k, v in entries.items()},
    "scripts": scripts,
    "cels": {"box": 2078, "highlight": 2077, "pointer": 2091, "picture_base": 2094, "platform_cap": 2076, "platform_body": 2079,
             "strip_centre": 2084, "strip": [2085, 2086], "cloud": 2087, "dirt": 2080, "map_frame": 2090, "radar": 1981, "panel_frame": 1940, "panel_interior": 1942,
             "digit_base": 2146, "icon": [2163, 2161, 2164, 2162], "weapon_icon": [2160, 2156, 2157, 2160], "second_icon": [0, 0, 2158, 2159]},
    "platform": {"x": 51.5, "start_y": 110.0, "top_row_y": 72.0, "ride_y": 80.0},
    "backdrop": {"seed_base": 0x1ABFAC, "strip_rows": [0, 16], "cloud_y": 4, "dirt_y": 42, "dirt_step": [32, 32]},
    "fade_per_tick": 0x11EB / 65536,
    "panel": {"pos": [87, 168], "offset": [15, 5]},
    # FUN_004116a0 for the cursor's type: icon, first weapon icon and the counts (cel numbers above, ammo capacities from the constant table)
    "ammo_capacity": [150, 16, 100, 100],
    "second_capacity": [0, 0, 0, 50],   # MSV: the mine reserve, shown only with two players
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "selector.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
