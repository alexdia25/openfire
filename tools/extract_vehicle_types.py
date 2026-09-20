"""Builds tools/data/vehicle_types.json (document 57): per vehicle type (Tank, Jeep, MSV, Heli) the traced
movement, armour, hit points, fuel and collision shape, plus the draw-descriptor parts of
tools/data/vehicle_type_parts.json with their corners in world units.

Inputs: a Ghidra dump of the four vehicle-type records (DumpDwords.java 0x4456b8 744; records are 0x2e8 bytes
apart) and, for the collision shapes, the output of DumpShapes.java for each type's draw descriptor
(0x43ea18, 0x43fd78, 0x43f358, 0x440b70), pasted below (see document 53 for the shape layout).
Usage: python extract_vehicle_types.py <records_dump.txt>
"""
import json, os, struct, sys

BASE = 0x4456B8
STRIDE = 0x2E8
mem = {}
for line in open(sys.argv[1]):
    p = line.split()
    if len(p) >= 2 and len(p[0]) == 8:
        try:
            mem[int(p[0], 16)] = int(p[1], 16)
        except ValueError:
            pass


def field(t, off):
    v = mem[BASE + t * STRIDE + off]
    return v - 2 ** 32 if v >= 2 ** 31 else v


# DumpShapes.java output, z 0..height, layer 2, mask 0x27 for all four (document 53)
SHAPES = {
    0: {"z": [0.0, 10.0], "poly": [[-7.5, -11.25], [7.5, -11.25], [7.5, 11.25], [-7.5, 11.25]]},
    1: {"z": [0.0, 10.0], "poly": [[-4.5, -7.5], [4.5, -7.5], [4.5, 7.5], [-4.5, 7.5]]},
    2: {"z": [0.0, 12.0], "poly": [[-7.5, -12.0], [7.5, -12.0], [7.5, 11.25], [-7.5, 11.25]]},
    3: {"z": [0.0, 10.0], "poly": [[0.0, 30.6], [-10.2, 0.0], [-10.2, -13.6], [10.2, -13.6], [10.2, 0.0]]},
}
parts = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "vehicle_type_parts.json")))
out = {}
for t in range(4):
    vt = parts["vehicle_types"][str(t)]
    out[str(t)] = {
        "name": vt["name"],
        "max_forward_per_tick": field(t, 0x168) / 65536,
        "max_reverse_per_tick": field(t, 0x16C) / 65536,
        "accel_per_tick2": field(t, 0x170) / 65536,
        "friction_per_tick2": field(t, 0x174) / 65536,
        "turn_steps_per_tick": field(t, 0x178) / 65536,
        "armor": field(t, 0x24) / 65536,
        "hit_points": field(t, 0x28) / 65536,
        "fuel": field(t, 0x210),  # a plain integer (the game shifts it into 16.16, FUN_0040b980)
        "shape": {"layer": 2, "mask": 0x27, **SHAPES[t]},
        "parts": [{"cel": p["cel"], "flags": int(p["flags"], 16), "corner_idx": p["corner_idx"],
                   "corners": [[c / 65536 for c in corner] for corner in p["corners_fixed16_16"]]}
                  for p in vt["parts"]],
    }
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "vehicle_types.json")
json.dump({"_source": "RFIRE.BIN vehicle-type records 0x4456b8 (+0x2e8 each) and descriptors, document 57; see extract_vehicle_types.py",
           "types": out}, open(path, "w"), indent=1)
for k, v in out.items():
    print(k, v["name"], {a: v[a] for a in ("max_forward_per_tick", "hit_points", "armor", "fuel")})
