"""Builds tools/data/vehicle_types.json (document 57): per vehicle type (Tank, Jeep, MSV, Heli) the traced
movement, armour, hit points, fuel and collision shape, plus the draw-descriptor parts of
tools/data/vehicle_type_parts.json with their corners in world units.

Inputs: a Ghidra dump of the four vehicle-type records (DumpDwords.java 0x4456b8 744; records are 0x2e8 bytes
apart) and, for the collision shapes, the output of DumpShapes.java for each type's draw descriptor
(0x43ea18, 0x43fd78, 0x43f358, 0x440b70), pasted below (see document 53 for the shape layout).
Also, for the vehicle definitions (PORTING_PLAN.md 2.7.2, step 3): the dock tolerance (+0x254, document 77), the death
wait (+0x260, document 87), the "created" sound descriptor (+0x240, document 82; resolved to a cue id through
tools/data/sound_cues.json where the descriptor is one of the traced cues) and, from a second optional dump, the camera
swoop's start height by type (the table at 0x4452c0, DumpDwords.java 0x4452c0 4; document 90); and for the music director
(document 98) the record's theme line and priority (bytes +0x2bc / +0x2bd) and, from a third optional dump, the death
line by type (the byte table at 0x4466e4, DumpDwords.java 0x4466e4 1).
The normal-play camera (issue #91): the record's own camera rig (a 0x60-byte rig at +0xbc whose callback +0xc8 is FUN_00416420; the vehicle
state is a copy of the record from +8, so the rig sits at state +0xb4) and the camera fields near the record's end (+0x2c0..+0x2dc), plus
how long the creation rig holds the swoop target (the byte table at 0x4452e8, DumpDwords.java 0x4452e8 1, in the camera table dump).
Usage: python extract_vehicle_types.py <records_dump.txt> [camera_table_dump.txt] [death_line_dump.txt]
Dumps are "address value" lines (hex); DumpDwords.java's own log lines are accepted too.
"""
import json, os, struct, sys

BASE = 0x4456B8
STRIDE = 0x2E8
mem = {}
for path in sys.argv[1:]:
    for line in open(path):
        p = line.split("DumpDwords.java>")[-1].split()
        if len(p) >= 2 and len(p[0]) == 8:
            try:
                mem[int(p[0], 16)] = int(p[1], 16)
            except ValueError:
                pass
CAMERA_TABLE = 0x4452C0
DEATH_LINE_TABLE = 0x4466E4
CAMERA_HOLD_TABLE = 0x4452E8


def byte_at(addr):
    word = mem.get(addr & ~3)
    return None if word is None else (word >> (8 * (addr & 3))) & 0xFF


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
# The Jeep's swim-mode drawing (FUN_00402fc0, document 62): the table at 0x43fb78 (9 rows of 6 dwords, 16.16) is indexed by
# whole(immersion * 8); a row is (a, _, c, d, _, f) and sets the wheel-strip corners: x = -a (top edge, height c) and
# x = -d (bottom edge, height f) for the left strip, +a / +d for the right. Row 0 equals the static geometry
# (4.5, 8, 4.5, 0). Above index 3 the descriptor switches to 0x43fcb8, which adds part 11 (cel 0x81a = 2074, the four
# wheels seen from above) as a square of half-size 12 * max(immersion, 0.25) at height 0.
SWIM_ROWS = [(4.5, 8.0, 4.5, 0.0), (3.75, 7.0, 6.0, 0.0), (3.0, 5.0, 7.5, 0.0), (3.0, 3.0, 8.25, 0.5), (2.25, 2.0, 8.25, 1.0),
             (2.25, 1.0, 8.25, 1.0), (1.5, 1.0, 7.5, 1.0), (1.125, 1.0, 7.125, 1.0), (0.75, 1.0, 6.75, 1.0)]
# The MSV's rack (FUN_00402ec0, document 64): the 8 corners 44-51 of its descriptor are recomputed every frame as
# R(elevation) * base + offset, base = the table at 0x43ed30 (corners 0-3 the top plate, 4-7 the canister strip; units,
# y = minus forward), offset = (0, 6, 12) (the dword triple at 0x43ed9c). The callback also overwrites the y of base corners 4
# and 5 with -6 - n, n being its weapon counter while it reloads (document 59). The salvo offsets at 0x43ed90 are
# (-1.5, 6, 12), (0, 6, 12), (1.5, 6, 12); the rocket points are (0, -15, -1) and (0, 1.5, -1) (0x43edb8).
MSV_RACK = {
    "base": [[-3.75, -8.25, 0.0], [3.75, -8.25, 0.0], [3.75, 1.5, 0.0], [-3.75, 1.5, 0.0],
             [-3.75, -4.5, -1.0], [3.75, -4.5, -1.0], [3.75, 0.0, -1.0], [-3.75, 0.0, -1.0]],
    "offset": [0.0, 6.0, 12.0],
    "salvo_x": [-1.5, 0.0, 1.5],
    "rocket_points": [[0.0, -15.0, -1.0], [0.0, 1.5, -1.0]],
}
parts = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "vehicle_type_parts.json")))
cues = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "sound_cues.json")))["cues"]
cue_by_addr = {c["addr"].lower(): k for k, c in cues.items() if "addr" in c}


def created_sound(t):
    addr = mem[BASE + t * STRIDE + 0x240]
    if addr == 0:
        return None
    return {"descriptor": hex(addr), "cue": cue_by_addr.get(hex(addr))}


def fixed(t, off):
    return field(t, off) / 65536


def ease(t, off):
    return [fixed(t, off), fixed(t, off + 4), fixed(t, off + 8)]   # {accel, brake, max rate} per tick (FUN_00417420)


def camera_rig(t):
    """FUN_00416420, the rig every vehicle registers at its init (0x40b873): the per-type numbers it reads (document 129)."""
    hold = byte_at(CAMERA_HOLD_TABLE + min(t, 3))
    return {
        "hold_ticks": hold,                        # 0x4452e8: the creation rig (FUN_0040b1c0, piVar2[7]) keeps the swoop target this long
        "rest_height": fixed(t, 0x130),            # state +0x128 (copied from record +0x130): the height when the vehicle sits still
        "zoom_height": fixed(t, 0x2D0),            # record +0x2d0: what the two-button toggle (0x40bc24) swaps rest_height to; not built
        "drive_height": fixed(t, 0x2CC),           # record +0x2cc: the height at a steady speed of 0.2 a tick or more
        "rest_pitch": fixed(t, 0x2D8),             # record +0x2d8: the pitch when still (32 = 45 degrees)
        "drive_pitch": fixed(t, 0x2D4),            # record +0x2d4: the pitch when driving (50 = 70.3 degrees)
        "follow_ease": ease(t, 0xBC + 0x3C),       # rig +0x3c: the x/y follow (FUN_00416fa0)
        "height_ease": ease(t, 0xBC + 0x48),       # rig +0x48: the height
        "pitch_ease": ease(t, 0xBC + 0x54),        # rig +0x54: the pitch
        "rise_ease": ease(t, 0x2C0),               # record +0x2c0: the height while it is below rest_height
        "air_threat": field(t, 0) == 3,            # FUN_00416420 tilts another player's camera when this type (record +0 == 3) is near
    }


def camera_height(t):
    v = mem.get(CAMERA_TABLE + min(t, 3) * 4)
    return None if v is None else (v - 2 ** 32 if v >= 2 ** 31 else v) / 65536
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
        "ammo": [field(t, 0x1A8), field(t, 0x1DC)],          # weapon slots 0 / 1 (+0x194 / +0x1c8 blocks, +0x14): the stock a slot starts with (document 72)
        "weapon_cooldown_ticks": [field(t, 0x1A4), field(t, 0x1D8)],  # block +0x10
        "fuel": field(t, 0x210),  # a plain integer (the game shifts it into 16.16, FUN_0040b980)
        **({"rack": MSV_RACK} if t == 2 else {}),
        **({"swim": {"rows": [list(r) for r in SWIM_ROWS], "ring_cel": 2074, "ring_half": 12.0}} if t == 1 else {}),
        "sink_depth": field(t, 0x158) / 65536,  # FUN_0040cf90: a vehicle in deep water is lost below this depth (document 62)
        "dock_tolerance": field(t, 0x254) / 65536,  # FUN_0040b980 / can_dock: how far from the pad centre it may stand to dock (document 77)
        "death_wait_ticks": field(t, 0x260),       # ticks from death to the next vehicle / the loss sequence (document 87)
        "created_sound": created_sound(t),         # played when the vehicle object is created (document 82)
        **({"camera_swoop_height": camera_height(t)} if camera_height(t) is not None else {}),   # document 90
        **({"camera_rig": camera_rig(t)} if byte_at(CAMERA_HOLD_TABLE) is not None else {}),   # issue #91
        "music_theme_line": byte_at(BASE + t * STRIDE + 0x2BC),   # FUN_0040b980's music request for a new vehicle (document 98)
        "music_priority": byte_at(BASE + t * STRIDE + 0x2BD),
        **({"music_death_line": byte_at(DEATH_LINE_TABLE + t)} if byte_at(DEATH_LINE_TABLE + t) is not None else {}),
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
