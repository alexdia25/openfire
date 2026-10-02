"""Builds tools/data/explosion_records.json (document 50) from Ghidra dumps of RFIRE.BIN's data
segment, so the extraction is reproducible without the binary in this repo.

Inputs (all produced with tools/ghidra_scripts/DumpDwords.java; the dumps stay outside the repo):
  python extract_explosion_records.py <dump 0x43e000 5120> <dump 0x443000 2240> <refs.txt>
where refs.txt is the output of FindPointerRefsMulti.java for the 26 record addresses.

Record layout (FUN_0042dba0 / FUN_0042dbe0 / FUN_0042dd90, documents 50-51):
  [0] script pointer   [1] script/descriptor table   [3] duration   [5] progress per tick
  [6] scale            [7] corner count   [8] corner array   [9] part count   [10] parts (6 ints each)
Part: [cel, start | end << 8 | fade << 16 | variant_mode << 24, 4 corner indices, ...].
  The part is shown while start <= floor(progress) <= end, as cel + (floor(progress) - start); from
  progress >= fade it fades out; variant_mode 1-4 selects one of 2/4/8 following parts at random.
"""
import collections, json, os, re, struct, sys

B = 0x43E000
mem = bytearray(0x7300)
for fn in sys.argv[1:3]:
    for line in open(fn):
        p = line.split()
        if len(p) >= 2 and len(p[0]) == 8:
            try:
                a, v = int(p[0], 16), int(p[1], 16)
            except ValueError:
                continue
            if B <= a < B + len(mem) - 3:
                mem[a - B:a - B + 4] = struct.pack("<I", v)
END = B + len(mem)


def dw(a): return struct.unpack("<I", mem[a - B:a - B + 4])[0]
def sdw(a): return struct.unpack("<i", mem[a - B:a - B + 4])[0]
def u8(a): return mem[a - B]
def s8(a): v = mem[a - B]; return v - 256 if v > 127 else v


NAMES = {0: "END", 1: "STOP", 2: "WAIT", 3: "SOUND", 4: "TILE_STATE", 5: "TILE_SET", 6: "DESC_TBL", 7: "DESC_DEFAULT",
         8: "SET_PROGRESS", 9: "IF", 10: "JUMP", 11: "KILL", 12: "DESC_REC", 13: "DAMAGE_BOX", 14: "BOX_EXTENT",
         15: "NOP2", 16: "DETACH", 17: "DRAW_LIST", 18: "TILE_DMG_A", 19: "TILE_DMG_B", 20: "REPEAT", 21: "OP21",
         22: "TILE_TEAM"}
ARGS = {1: 0, 2: 1, 3: 1, 4: 0, 5: 4, 6: 1, 7: 0, 8: 1, 9: 3, 10: 1, 11: 0, 12: 1, 13: 6, 14: 1, 15: 2, 16: 0, 17: 1,
        18: 3, 19: 3, 21: 1, 22: 2}


def disassemble(a):
    out = []
    for _ in range(80):
        op = u8(a)
        if op == 0:
            out.append(["END"]); break
        if op == 20:
            out.append(["REPEAT", s8(a + 1)]); a += 2; continue
        if op not in ARGS:
            out.append(["?%d" % op]); break
        out.append([NAMES[op]] + [s8(a + 1 + i) for i in range(ARGS[op])]); a += 1 + ARGS[op]
    return out


def parts_of(r):
    cc, cp, pc, pp = dw(r + 28), dw(r + 32), dw(r + 36), dw(r + 40)
    parts = []
    for i in range(pc):
        a = pp + 24 * i
        fl = dw(a + 4)
        idx = [dw(a + 8 + 4 * k) for k in range(4)]
        parts.append({
            "cel": dw(a), "start": fl & 0xFF, "end": (fl >> 8) & 0xFF, "fade": (fl >> 16) & 0xFF,
            "variant_mode": (fl >> 24) & 7,
            "corners": [[round(sdw(cp + 12 * j + 4 * k) / 65536, 4) for k in range(3)] for j in idx],
        })
    return parts


refs = []
for line in open(sys.argv[3]):
    m = re.search(r"REF (\w+) @ (\w+)(?: in (\w+))?", line.replace(" (GhidraScript)", "").strip())
    if m:
        refs.append((int(m.group(1), 16), int(m.group(2), 16), m.group(3)))
coastal = collections.defaultdict(lambda: collections.defaultdict(list))
code = collections.defaultdict(set)
for rec, a, fn in refs:
    if 0x447030 <= a < 0x448800:
        coastal[rec][((a - 0x447030) % 0x38) // 4].append((a - 0x447030) // 0x38)
    elif fn:
        code[rec].add(fn)

records = sorted({r for r, _, _ in refs} | {0x444b68, 0x444ac8, 0x444a30, 0x4445e8, 0x4445b8})
out = {}
for r in records:
    out[hex(r)] = {
        "duration": dw(r + 12) / 65536, "rate_per_tick": dw(r + 20) / 65536, "scale": dw(r + 24) / 65536,
        "script": disassemble(dw(r)), "parts": parts_of(r),
        "coastal_destroy_effect_ids": sorted(coastal[r][11]), "coastal_field10_ids": sorted(coastal[r][10]),
        "code_refs": sorted(code[r]),
    }
tables = {
    "0x448970": {"used_by": "projectile types 0,3,5,7,11 (entry+0x34)",
                 "surface": {"0 land": "0x444740", "1 water": "0x4445b8", "2 pavement": "0x444968",
                             "3 object hit": "0x444b68", "4 tile hit": "0x444ac8"}},
    "0x448988": {"used_by": "projectile types 1,2,4,6,8,9,10",
                 "surface": {"0 land": "0x444840", "1 water": "0x4445e8", "2 pavement": "0x444a30",
                             "3 object hit": "0x444b68", "4 tile hit": "0x444ac8"}},
}
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "explosion_records.json")
json.dump({"_source": __doc__.strip().splitlines()[0] + " -- see this script's docstring", "impact_tables": tables,
           "records": out}, open(path, "w"), indent=1)
print("wrote", path, len(out), "records")
