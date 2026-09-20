"""Builds tools/data/projectile_types.json (documents 46, 58): the 12 projectile types of RFIRE.BIN's table at
0x4489a0 (12 entries x 0x3c bytes) and the draw descriptors they point at.

Inputs:
  <dump>         DumpDwords.java 0x4489a0 180 (the table)
  <descriptors>  the "desc=" / "part" lines printed by DumpDescriptorParts.java for each body/shadow descriptor
                 (0x4547f0 0x454410 0x454580 0x4546f0 0x454858 0x454478 0x4545e8 0x454758)
Entry fields (dwords): [2] flags (bit 0: spawned through the pitch matrix; bit 1: ballistic, its pitch grows by
[10] per tick instead of shrinking to 0), [3] speed, [9] damage, [10] pitch rate, [11] body descriptor,
[12] shadow descriptor, [13] impact table, [14] low byte = lifetime in ticks (document 45).
Usage: python extract_projectile_types.py <dump.txt> <descriptors.txt>
"""
import json, os, re, sys

dw = [int(l.split()[1], 16) for l in open(sys.argv[1]) if re.match(r"^[0-9a-f]{8}\s+[0-9a-f]{8}", l)]
descs = {}
cur = None
for line in open(sys.argv[2]):
    m = re.search(r"# desc=0x(\w+)", line)
    if m:
        cur = int(m.group(1), 16)
        descs[cur] = []
        continue
    m = re.search(r"part part_idx=\d+ cel=(\d+) flags=0x(\w+) .*corners_fixed16_16=(\S+)", line)
    if m and cur is not None:
        corners = [[int(v) / 65536 for v in c.split(",")] for c in m.group(3).split(";")]
        descs[cur].append({"cel": int(m.group(1)), "flags": int(m.group(2), 16), "corners": corners})

types = []
for t in range(12):
    r = dw[t * 15:(t + 1) * 15]
    types.append({
        "type": t, "flags": r[2], "speed_units_per_tick": r[3] / 65536, "damage": r[9] / 65536,
        "pitch_rate_raw": r[10], "lifetime_ticks": r[14] & 0xFF,
        "body_descriptor": hex(r[11]), "shadow_descriptor": hex(r[12]), "impact_table": hex(r[13]),
    })
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "projectile_types.json")
json.dump({"_source": "RFIRE.BIN projectile type table 0x4489a0 and its draw descriptors, documents 46 and 58; see "
                      "extract_projectile_types.py. pitch_rate_raw is in 22-bit angle units per tick (0x400000 = 360 deg).",
           "types": types, "descriptors": {hex(k): v for k, v in descs.items()}}, open(path, "w"), indent=1)
print("wrote", path, len(types), "types", len(descs), "descriptors")
