"""Builds tools/data/radar.json (document 69): the radar bitmap's palette indices and the flag blip, read from RFIRE.BIN.

Transcribed from the decompiled painter FUN_00412dc0 and DumpDwords.java dumps:
  land 0x87 (also a coastal id whose entry colour is 0), water 0x91 (plain terrain for which FUN_0042f6d0 is non-zero:
  terrain art 1, 2 or 4..0x33 and a coastal id other than 0x4a / 0x4b), a tile with bit 31 set 0xc9 (NOT reproduced: bit 31
  of the tile word is not read yet). A coastal id's entry dword at 0x447064 + id * 0x38: 0 = land colour; otherwise the low
  byte for a tile with no pool bits (0xc000) and the high half for one with them.
  The flag blip: descriptor 0x4404b0 = 8 points {dx, dy, colour_team_0, colour_team_1} at 0x440490; 0x4404c0 = none.
The game's runtime palette is runtime[10 + i] = shared_plut[i] (convert_car.py, document 20): tools/build_pack.py turns the
indices into RGB from ART.CAR (kept out of the repo).
Usage: python extract_radar.py
"""
import json
import os

coastal = {}
for i in (22, 62):
    coastal[i] = [0xCC, 0x67]
for i in (45, 46, 54, 55, 56, 57, 58, 59, 60):
    coastal[i] = [0xD3, 0x70]
for i in (49, 50, 68):
    coastal[i] = [0xCF, 0x6C]

out = {
    "_source": "RFIRE.BIN FUN_00412dc0 (painter), FUN_0042f6d0 (water test), table 0x447064, blip descriptors 0x4404b0/0x4404c0; document 69",
    "land": 0x87,
    "water": 0x91,
    "flagged_tile": 0xC9,
    "coastal_colours": {str(k): v for k, v in coastal.items()},   # [no pool bits, with pool bits]
    "window": [32, 32],
    "flag_blip": {
        "period_ticks": 15,
        "points": [[0, 0], [0, 1], [0, -1], [0, -2], [1, -1], [1, -2], [2, -1], [2, -2]],
        "colours": [0x45, 0x67],   # team 0 (tan), team 1 (green)
    },
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "radar.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
