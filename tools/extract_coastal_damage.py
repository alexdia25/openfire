"""Turns a Ghidra `DumpDwords.java 0x00447038 1300` dump of RFIRE.BIN's coastal table (91 real
ids x 0x38 bytes, document 44) into tools/data/coastal_damage.json: per coastal id, the hit
points a tile starts with, its ground art, and what it turns into when destroyed.

Fields (entry E = 0x447038 + id*0x38), read by FUN_0042e4f0 / FUN_0042e8c0 / FUN_0042e6a0:
  E+4   flags dword   (bit 1 / bit 2: destroyed art gets a random +0..1 / +0..3 variation)
  E+8   base_art      ground art id this coastal id gives its tile
  E+9   hp            initial tile hit points (bits 25-27 of the tile word)
  E+0x14 handler      code pointer called on destruction (0x432710 = the target-pool handler)
  E+0x28 result_art   added to the new coastal id's base art on destruction (0 = none)
  E+0x29 result_coastal  coastal id the tile becomes when its hit points run out (0 = none)
Usage: python extract_coastal_damage.py <dump.txt>
"""
import json, os, re, sys

dw = [int(l.split()[1], 16) for l in open(sys.argv[1]) if re.match(r'^[0-9a-f]{8}\s+[0-9a-f]{8}', l)]
out = {}
for i in range(1, 92):
    e = dw[i * 14:(i + 1) * 14]
    out[str(i)] = {
        "hp": (e[2] >> 8) & 0xFF,
        "base_art": e[2] & 0xFF,
        "destroyed_coastal": (e[10] >> 8) & 0xFF,
        "destroyed_art_offset": e[10] & 0xFF,
        "flags": e[1],
        "pool_handler": e[5] == 0x432710,
    }
path = os.path.join(os.path.dirname(__file__), "data", "coastal_damage.json")
json.dump({"_source": "RFIRE.BIN coastal table 0x00447038, DumpDwords.java, document 44; see this script's docstring",
           "coastal": out}, open(path, "w"), indent=1)
print("wrote", path)
