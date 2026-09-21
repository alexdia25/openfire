"""Builds tools/data/water_tables.json (document 62): the tables FUN_0042f280 / FUN_0042f410 use to say whether a
position is on land (0), in shallow water (1) or in deep water (2), from the tile it stands on.

The values were read from RFIRE.BIN with DumpDwords.java and are transcribed here (16.16 fixed point unless noted):
  0x44de10 + art * 8   per terrain art id 4..23: byte flag, byte rotation (in 0x10000 = 1 step of 5.625 degrees), dword
                       pointer to one of four shapes (0x44dc70, 0x44dcf0, 0x44dd70, 0x44ddf0)
  0x44dc28 / 0x44dcb0 / 0x44dd30 / 0x44ddb0   the corner arrays of those shapes (x, y, 0 per corner)
  0x44ded0 + (art - 0x28) * 0x10   per art id 0x28..0x33: a box (x0, y0, x1, y1) around the tile centre
Usage: python extract_water_tables.py
"""
import json
import os

FIX = 65536.0

# (flag, rotation steps, shape) for art ids 4..23, from the dwords at 0x44de30..0x44decc
COAST = {
    4: (1, 0x30, "A"), 5: (1, 0x00, "A"), 6: (0, 0x30, "A"), 7: (0, 0x00, "A"),
    8: (0, 0x00, "B"), 9: (0, 0x10, "B"), 10: (1, 0x20, "A"), 11: (1, 0x10, "A"),
    12: (0, 0x20, "A"), 13: (0, 0x10, "A"), 14: (0, 0x30, "B"), 15: (0, 0x20, "B"),
    16: (1, 0x00, "C"), 17: (1, 0x10, "C"), 18: (0, 0x00, "D"), 19: (0, 0x10, "D"),
    20: (1, 0x30, "C"), 21: (1, 0x20, "C"), 22: (0, 0x30, "D"), 23: (0, 0x20, "D"),
}
# shape A = 0x44dc70 (corners 0x44dc28), B = 0x44dcf0 (0x44dcb0), C = 0x44dd70 (0x44dd30), D = 0x44ddf0 (0x44ddb0)
SHAPES = {
    "A": [(-16, -16), (15, -16), (15, 12), (8, 8), (-8, 8), (-16, 12)],
    "B": [(15, 15), (-16, 15), (-16, 12), (12, -16), (15, -16)],
    "C": [(-16, -16), (11, -16), (4, -8), (4, 4), (-16, 12)],
    "D": [(15, 15), (-16, 16), (-12, -5), (-4, -12), (15, -15)],
}
# boxes for art ids 0x28..0x33 (x0, y0, x1, y1): inside = shallow (1), outside = deep (2)
BOXES = {
    0x28: (-16, -16, 8, 16), 0x29: (-16, -16, 16, 8), 0x2A: (-16, -8, 16, 16), 0x2B: (-8, -16, 16, 16),
    0x2C: (-8, -8, 16, 16), 0x2D: (-16, -8, 8, 16), 0x2E: (-8, -16, 16, 8), 0x2F: (-16, -16, 8, 8),
    0x30: (-8, -8, 16, 16), 0x31: (-16, -8, 8, 16), 0x32: (-8, -16, 16, 8), 0x33: (-16, -16, 8, 8),
}
out = {
    "_source": "RFIRE.BIN 0x44de10 (coast table), 0x44dc28.. (shapes), 0x44ded0 (boxes); document 62; see extract_water_tables.py",
    "coast": {str(a): {"flag": f, "rot_steps": r, "shape": s} for a, (f, r, s) in COAST.items()},
    "shapes": {k: [list(map(float, p)) for p in v] for k, v in SHAPES.items()},
    "boxes": {str(a): list(map(float, b)) for a, b in BOXES.items()},
}
# rot_steps is the table's byte: 0x10 = 16 steps of 5.625 degrees = 90 degrees
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "water_tables.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
