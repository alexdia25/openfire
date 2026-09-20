"""Builds tools/data/gates.json (document 56): the two "gate" objects (coastal ids 43 and 44, class 0x44e370,
FUN_00432270 / FUN_004322f0) from a Ghidra dump of 0x44cd00.. (DumpDwords.java 0x44cd00 720).

Each gate is a copy of a 0x104-byte block: two chained draw descriptors (the two door wings) and two solid bars.
The draw hooks (descriptor +0, FUN_0042e240 / 0x42e2b0 for id 43, 0x42e320 / 0x42e390 for id 44) rewrite, per
frame, corners 9, 10, 13 and 14 along the gate's axis (x for 43, y for 44) to +-(16 - floor(open)) and switch the
last part's cel from 0x359 (closed) to 0x35a (open); the constants below are read from those decompilations.
Usage: python extract_gates.py <dump.txt>
"""
import json, os, sys

mem = {}
for line in open(sys.argv[1]):
    p = line.split()
    if len(p) >= 2 and len(p[0]) == 8:
        try:
            mem[int(p[0], 16)] = int(p[1], 16)
        except ValueError:
            pass


def dw(a): return mem[a]
def sdw(a):
    v = mem[a]
    return (v - 2 ** 32 if v >= 2 ** 31 else v) / 65536.0


def descriptor(a, sign, axis, dyn_part):
    cc, cp, pc, pp = dw(a + 0x2c), dw(a + 0x30), dw(a + 0x34), dw(a + 0x38)
    return {
        "offset": [sdw(a + 0x14), sdw(a + 0x18)],
        "corners": [[sdw(cp + 12 * i + 4 * k) for k in range(3)] for i in range(cc)],
        "parts": [{"cel": dw(pp + 32 * i), "flags": dw(pp + 32 * i + 4),
                   "corner_idx": [dw(pp + 32 * i + 16 + 4 * k) for k in range(4)]} for i in range(pc)],
        "dyn_corners": [9, 10, 13, 14], "dyn_axis": axis, "dyn_sign": sign, "dyn_part": dyn_part,
        "cel_closed": 0x359, "cel_open": 0x35a,
    }


def shape(a):
    return {"type": dw(a), "layer": (dw(a + 8) >> 16) & 255, "mask": (dw(a + 8) >> 24) & 255,
            "z": [sdw(a + 0xc), sdw(a + 0x10)], "off": [sdw(a + 0x14), sdw(a + 0x18)],
            "box": [sdw(a + 0x1c + 4 * k) for k in range(4)]}


region = shape(0x44CDB0)
out = {
    "43": {"axis": "x", "descs": [descriptor(0x44D160, 1, "x", 6), descriptor(0x44D1A4, -1, "x", 6)],
           "shapes": [shape(0x44D1E8), shape(0x44D224)], "region": region},
    "44": {"axis": "y", "descs": [descriptor(0x44D628, 1, "y", 7), descriptor(0x44D66C, -1, "y", 7)],
           "shapes": [shape(0x44D6B0), shape(0x44D6EC)], "region": region},
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "gates.json")
json.dump({"_source": "RFIRE.BIN gate objects 0x44d160 / 0x44d628, document 56; see extract_gates.py", "gates": out},
          open(path, "w"), indent=1)
print("wrote", path)
