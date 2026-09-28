"""Builds tools/data/radar.json (document 69): the radar bitmap's palette indices and the flag blip, read from RFIRE.BIN.

Transcribed from the decompiled painter FUN_00412dc0 and DumpDwords.java dumps:
  land 0x87 (also a coastal id whose entry colour is 0), water 0x91 (plain terrain for which FUN_0042f6d0 is non-zero:
  terrain art 1, 2 or 4..0x33 and a coastal id other than 0x4a / 0x4b), a tile with bit 31 set 0xc9 (NOT reproduced: bit 31
  of the tile word is not read yet). A coastal id's entry dword at 0x447064 + id * 0x38: 0 = land colour; otherwise the low
  byte for a tile with no pool bits (0xc000) and the high half for one with them.
  The flag blip: descriptor 0x4404b0 = 8 points {dx, dy, colour_team_0, colour_team_1} at 0x440490; 0x4404c0 = none.
  The grid overlay is per vehicle type, not one shared cel -- see tools/extract_hud_panels.py's own docstring (document
  108's addendum) for that trace; only the ping stays here, since it is genuinely shared (any vehicle type pings the
  same way).
  The ping (documents 68, 71, 103): FUN_004122d0's kind-6 radar callback draws one of cels 1947-1962 (celtable + 0x2052c),
  a 16-frame growing-ring animation, over the panel's own tracked vehicle whenever `DAT_00480d38 (now) - state+0x4c` is in
  (-10, 64) -- state+0x4c is the same "hit until" deadline document 47/59 already traced (set to now + 10 on a successful
  hit), so the window is the 74 ticks starting at the hit itself. The ring's own growth curve (state+0x20, read through
  FUN_00410b70's fixed-point multiply against a per-panel constant at slot+0x14) did not resolve in the time this session
  had: state+0x20 is written in the same hit handler (FUN_0040c460) but as a debounce/count field whose exact role past
  that is still open, not confirmed to be a clean elapsed-time fraction. The port instead spreads the 16 frames evenly
  across the confirmed 74-tick window (RADAR_PING_TICKS below) -- a marked approximation of the growth curve, not the
  trigger, which is traced.
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
    "ping": {
        "cels": list(range(1947, 1963)),        # the 16 growing-ring frames, in order (FUN_004122d0: celtable + 0x2052c)
        "window_ticks": 74,                       # (-10, 64) around now - state+0x4c: the full span from the hit to the end of the check
    },
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "radar.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
