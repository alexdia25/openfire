"""Turns the output of tools/ghidra_scripts/DumpCoastalShapes.java into tools/data/coastal_shapes.json
(document 53): per coastal id, whether the tile's shape is jittered like its decoration and the collision
shapes of the id's FIRST descriptor plus the tile callback (coastal entry +0x14, 0x0 = none; document 54) (FUN_0042bb10 tests only `*(descriptor + 8)`, not the chained
sub-objects). Usage: python extract_coastal_shapes.py <dump.txt>

A shape: `flags` is the shape's byte +9 (bit 1 = a trigger zone, document 54); type 2 = axis-aligned box [minx, miny, maxx, maxy], type 3 = convex polygon (also has a box), all
relative to the tile centre plus the shape's own offset; z0..z1 its height range; `layer` / `mask` bit sets
(two shapes collide only if a.mask & b.layer and b.mask & a.layer).
"""
import json, os, re, sys

out = {}
cur = None
first_desc = {}
for line in open(sys.argv[1]):
    line = line.strip()
    m = re.match(r"ID (\d+) jitter=(\w+) callback=(0x\w+)", line)
    if m:
        cur = int(m.group(1))
        out[str(cur)] = {"jitter": m.group(2) == "true", "callback": m.group(3), "shapes": []}
        continue
    m = re.match(r"SHAPE (\d+) desc=(0x\w+) type=(\d+) b9=(\d+) layer=(\d+) mask=(\d+) z=([-\d.]+),([-\d.]+) off=([-\d.]+),([-\d.]+)(.*)", line)
    if not m:
        continue
    i = int(m.group(1))
    desc = m.group(2)
    first_desc.setdefault(i, desc)
    if desc != first_desc[i]:
        continue  # only the first descriptor's shapes are tested by the collision code
    shape = {"type": int(m.group(3)), "flags": int(m.group(4)), "layer": int(m.group(5)), "mask": int(m.group(6)),
             "z": [float(m.group(7)), float(m.group(8))], "off": [float(m.group(9)), float(m.group(10))]}
    rest = m.group(11)
    b = re.search(r"box=([-\d.]+),([-\d.]+),([-\d.]+),([-\d.]+)", rest)
    if b:
        shape["box"] = [float(x) for x in b.groups()]
    p = re.search(r"poly=(\S+)", rest)
    if p:
        shape["poly"] = [[float(v) for v in pt.split(",")] for pt in p.group(1).split(";")]
    out[str(i)]["shapes"].append(shape)
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "coastal_shapes.json")
json.dump({"_source": "RFIRE.BIN coastal table 0x447038 -> descriptor +8 shape chains, DumpCoastalShapes.java, document 53; see extract_coastal_shapes.py",
           "coastal": {k: v for k, v in out.items() if v["shapes"]}}, open(path, "w"), indent=1)
print("wrote", path, sum(1 for v in out.values() if v["shapes"]), "ids with shapes")
