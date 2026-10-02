"""Builds tools/data/water_overlays.json (document 122, issue #25): what the original draws while a vehicle wades or sinks.

Transcribed from DumpDwords.java dumps of the vehicle records (stride 0x2e8 from 0x4456b8) and the decompiled water handlers
FUN_0040cef0 (dry), FUN_0040d150 (wading), FUN_0040cf90 (sinking) and the draw-object init callbacks FUN_00402b40, FUN_00402b80,
FUN_00402ca0, FUN_00403180 and the Jeep's draw callback FUN_00403220:

  record +0x148 the normal descriptor, +0x14c the WADING descriptor, +0x154 the SINKING descriptor, +0x158 the depth at which the
  vehicle is lost. The three handlers swap the object's descriptor (object +0x3c) to one of them.
  A wading descriptor chains (its +4) to the normal one: the spray quad is drawn, then the vehicle as usual. Its one part is a
  15 x 15 quad behind the vehicle (y +8.25..23.25 for the Jeep, +11.25..26.25 for the Tank and MSV; z 0) whose cel is base + the frame,
  the integer part of the splash counter (state +0x48; FUN_00402b40: `frame = counter >> 16`).
  A sinking descriptor chains to 0x43e370, a 32 x 32 ripple quad at the vehicle's feet (cel 1987 + the byte of table 0x43e2f0 at
  (clock & 0x1e) >> 1: FUN_00402ca0), and REPLACES the vehicle: two parts (a top view and a side view) whose cel is base + the
  depth `-(z >> 16)` + (depth limit when the player index is not 0) -- FUN_00402b80; nothing is drawn once the depth reaches the
  limit or while it is negative (it sets the skip flag 0x480d28).
  The Jeep's wading is special: FUN_00403180 (its descriptor 0x43feb0's init) counts frames the same way, but while the Jeep is in
  swim mode (state +0x80 not 0) it draws descriptor 0x43fe18 instead (two 24 x 24 quads of cels 2038 / 2056 + a frame remapped
  from the counter: above 4.0 and below 8.0 `4 + 1.5 * (counter - 4)`, from 8.0 `10 + 1.6 * (counter - 8)` capped at 17).

Usage: python extract_water_overlays.py
"""
import json
import os


def q(x0, y0, x1, y1, z=0.0):
    """The four corners of a flat quad in the order the descriptors' parts use: (x0,y0) (x1,y0) (x1,y1) (x0,y1)."""
    return [[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]]


out = {
    "_source": "RFIRE.BIN: vehicle records 0x4456b8 + type * 0x2e8 (+0x14c, +0x154, +0x158), descriptors 0x43eac8 / 0x43eb50 (Tank), "
               "0x43feb0 / 0x43fe18 / 0x440030 (Jeep), 0x43f408 / 0x43f490 (MSV), 0x43e370 (the ripple); handlers FUN_0040cef0 / 0040d150 / 0040cf90; "
               "document 122",
    "ripple": {"cel": 1987, "corners": q(-16, -16, 16, 16), "frames": [0, 0, 0, 1, 1, 2, 2, 2], "clock_mask": 0x1E,
               "_source": "descriptor 0x43e370 (flag 0x10: the object's height is ignored), FUN_00402ca0, bytes at 0x43e2f0"},
    "wading_counter": {"start": 4.0, "per_tick": 0.2, "wrap_at": 13.0, "wrap_moving": 5.0, "wrap_stopped": 13.0, "dry_after": 3.0,
                       "_source": "FUN_0040cef0 enters wading at counter 4.0 (0x40000); FUN_0040d150 adds 0x3333 (0.2) a tick; at 13.0 it subtracts 5.0 while "
                                  "the vehicle keeps wading (shallow water, moved, speed above 0) and 13.0 otherwise; below 13.0 it returns to the dry handler "
                                  "when the vehicle is not wading and the counter's integer part goes from 3 to 4"},
    "types": {
        "0": {"name": "Tank", "sink_depth": 14,
              "wading": {"cel": 2012, "frames": 13, "corners": q(-7.5, 11.25, 7.5, 26.25)},
              "sinking": [
                  {"cel": 218, "corners": q(-12, -12, 12, 12, 5.0)},
                  {"cel": 246, "corners": [[-6.75, 12.0, 5.0], [-6.75, -12.0, 5.0], [-6.75, -12.0, 0.0], [-6.75, 12.0, 0.0]]}]},
        "1": {"name": "Jeep", "sink_depth": 13,
              "wading": {"cel": 1999, "frames": 13, "corners": q(-7.5, 8.25, 7.5, 23.25)},
              "swim_wading": [
                  # the parts' corner order is idx [1, 2, 3, 0] and [2, 4, 5, 3] of the descriptor's six corners (which fixes the picture's orientation)
                  {"cel": 2038, "frames": 18, "corners": [[12, -12, 0.0], [12, 12, 0.0], [-12, 12, 0.0], [-12, -12, 0.0]]},
                  {"cel": 2056, "frames": 18, "corners": [[12, 12, 0.0], [12, 36, 0.0], [-12, 36, 0.0], [-12, 12, 0.0]]}],
              "swim_frame": {"low": 4.0, "mid": 8.0, "mid_gain": 1.5, "high_base": 10.0, "high_gain": 1.6, "cap": 17},
              "sinking": [
                  {"cel": 463, "corners": q(-6, -12, 6, 12, 2.0)},
                  {"cel": 491, "corners": q(-6, -0.75, 6, 12, 4.5)}]},
        "2": {"name": "MSV", "sink_depth": 14,
              "wading": {"cel": 2025, "frames": 13, "corners": q(-7.5, 11.25, 7.5, 26.25)},
              "sinking": [
                  {"cel": 328, "corners": q(-12, -12, 12, 12, 10.0)},
                  {"cel": 356, "corners": q(-8.25, -12, -4.5, 12, 5.0)}]},
    },
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "water_overlays.json")
json.dump(out, open(path, "w"), indent=1)
print("wrote", path)
