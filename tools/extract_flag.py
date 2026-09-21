"""Builds tools/data/flag.json (document 65): the capture flag's drawing and behaviour constants, read from RFIRE.BIN.

Transcribed from DumpDwords.java dumps (16.16 fixed point; corners in units, y = minus forward, z up):
  class 12 at 0x44e3c0: init 0x4328c0, destroy 0x4328f0, update 0x432920, ground descriptor 0x440448, priority 201
  ground descriptor 0x440448 (draw callback 0x403300): corners 0x440360, parts 0x4403c0:
      part 0  cel 0x759 = 1881, flags 0, corners 4-7   the small base plate
      part 1  cel 0x725 = 1829, flags 8, corners 0-3   the cloth (variant = frame + 13 * team)
  carried descriptor 0x440318 (draw callback 0x4032a0): corners 0x440270, parts 0x4402d0:
      part 0  cel 0x73f = 1855, flags 8, corners 4-7   the cloth seen from above
      part 1  cel 0x70b = 1803, flags 8, corners 0-3   the cloth seen from the side
  Both draw callbacks set the variant to whole(obj+0x5c) + (team != 0 ? 13 : 0): 13 frames per team.
  carry offset 0x440260 = (3.75, 6.75, -2); update rates: frame counter 0x2aaa a tick, heading 0x4ccc a tick.
Usage: python extract_flag.py
"""
import json
import os

out = {
    "_source": "RFIRE.BIN class 12 (0x44e3c0), descriptors 0x440448 / 0x440318, update FUN_00432920; document 65; see extract_flag.py",
    "frames_per_team": 13,
    "ground": {
        "plate": {"cel": 1881, "corners": [[-1.5, -1.0, 0.0], [5.0, -1.0, 0.0], [5.0, 3.0, 0.0], [-1.5, 3.0, 0.0]]},
        "cloth": {"cel": 1829, "corners": [[-3.0, -2.0, 16.0], [17.0, -2.0, 16.0], [17.0, 2.0, 0.0], [-3.0, 2.0, 0.0]]},
    },
    "carried": {
        "top": {"cel": 1855, "corners": [[-2.25, 0.0, 10.5], [-2.25, 11.25, 10.5], [2.25, 11.25, 10.5], [2.25, 0.0, 10.5]]},
        "side": {"cel": 1803, "corners": [[0.0, 0.0, 12.5], [0.0, 11.25, 12.5], [0.0, 11.25, 4.5], [0.0, 0.0, 4.5]]},
    },
    "carry_offset": [3.75, 6.75, -2.0],
    "frame_rate_per_tick": 10922 / 65536,
    "heading_rate_steps_per_tick": 0x4CCC / 65536,
    "initial_heading_steps": 16,
    "carried_heading_clamp_deg": [25.0, 155.0, 205.0, 335.0],
    "drift": {"max_per_tick": 0x1999 / 65536, "accel_per_tick": 0x36 / 65536},
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "flag.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
