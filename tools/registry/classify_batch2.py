"""Classification batch 2: cel indices 112-152 -- scenery decoration (bushes, palm
trees, rocks) and an 8-frame radar/minimap icon set.

Same one-time-authoring-script pattern as classify_batch1.py: run it, it merges its
entries into packs/registry/asset_ids.json, keep it as a record of the reasoning.

Visual read: three colour families of the same handful of foliage silhouettes
(blue-green, white, black) recur across 112-152. The most likely explanation is
Return Fire's known destructible terrain -- intact/flash/burnt states of the same
bush -- but nothing here traces that through code, so it's recorded as a hypothesis
in the notes, not baked into the ID (IDs use neutral colour-family names).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

DESTRUCT_NOTE = ("one of three recurring colour families (blue-green/white/black) across "
                  "cels 112-152; possibly intact/flash/destroyed states of the same "
                  "destructible-scenery object (Return Fire has destructible terrain "
                  "foliage) -- UNCONFIRMED, not traced through code.")

ENTRIES = {}


def put(idx, id_, category, note=None, confidence="visual"):
    e = {"id": id_, "category": category, "confidence": confidence}
    if note:
        e["note"] = note
    ENTRIES[idx] = e


for n, idx in enumerate([112, 113, 114, 115, 118, 119, 136, 139, 140, 143, 144], start=1):
    put(idx, f"decoration.foliage.bush_blue.{n:02d}", "decoration", DESTRUCT_NOTE)

# CORRECTED 2026-09-19 (registry hand-edited, not re-generated; document 44): 116, 117, 120, 121,
# 133, 137, 141 are PRE0=13 shadow masks (-> effect.shadow.hard.*), 134/138/142 are palm trunk quads
# (-> decoration.tree.palm_trunk.01-03; 138 was "decoration.tree.palm"). Only 145 is a real
# ordinary sprite and keeps its bush_white name.
for n, idx in enumerate([116, 117, 120, 121, 133, 137, 141, 145], start=1):
    put(idx, f"decoration.foliage.bush_white.{n:02d}", "decoration", DESTRUCT_NOTE)

for n, idx in enumerate([151, 152], start=1):
    put(idx, f"decoration.foliage.bush_black.{n:02d}", "decoration", DESTRUCT_NOTE)

put(122, "decoration.foliage.leaf_patch", "decoration", "small textured square, ground clutter")
put(123, "effect.sparkle.small", "effect", "scattered small yellow/tan dots, particle-like")
put(124, "decoration.dot_red", "decoration", "single small red blob, purpose unconfirmed (berry/marker/projectile)")

for n, idx in enumerate(range(125, 133), start=1):
    put(idx, f"ui.radar.icon.{n:02d}", "ui",
        "green radar-screen background with a black silhouette blip; 131-132 shift to a "
        "red/orange alert palette")

put(134, "decoration.rock_tan.01", "decoration", "tan craggy vertical shape (rock or dead trunk)")
put(142, "decoration.rock_tan.02", "decoration", "tan craggy shape, same family as 134")
put(135, "decoration.foliage.frond_blue", "decoration", "single palm-frond fan shape")
put(138, "decoration.tree.palm", "decoration", "full palm tree: trunk + ball canopy")

for n, idx in enumerate(range(146, 151), start=1):
    put(idx, f"decoration.tree.branch_brown.{n:02d}", "decoration",
        "brown branch/trunk with blue-green leaf clusters")

# CORRECTED 2026-09-20 (registry hand-edited, not re-generated): names now follow what the cel
# actually shows. 0,3,52-59 sand; 1,2,24-51 open water; 60 plain grass; 61-72 grass/sand coast.
# Earlier labels (dune_plain/dune_water on blue water, forest_water on sand and grass, water_open on
# sand cels 0/3/52) were left over from the pre-palette-fix theories.
put(0, "terrain.ground.sand_plain.01", "terrain", "plain sand, no water or grass")
put(1, "terrain.ground.water_open.01", "terrain", "plain open water, no coastline")
put(2, "terrain.ground.water_open.02", "terrain", "plain open water, no coastline")
put(3, "terrain.ground.sand_plain.02", "terrain", "plain sand, no water or grass")
put(24, "terrain.ground.water_open.03", "terrain", "plain open water, no coastline")
put(25, "terrain.ground.water_open.04", "terrain", "plain open water, no coastline")
put(26, "terrain.ground.water_open.05", "terrain", "plain open water, no coastline")
put(27, "terrain.ground.water_open.06", "terrain", "plain open water, no coastline")
put(28, "terrain.ground.water_open.07", "terrain", "plain open water, no coastline")
put(29, "terrain.ground.water_open.08", "terrain", "plain open water, no coastline")
put(30, "terrain.ground.water_open.09", "terrain", "plain open water, no coastline")
put(31, "terrain.ground.water_open.10", "terrain", "plain open water, no coastline")
put(32, "terrain.ground.water_open.11", "terrain", "plain open water, no coastline")
put(33, "terrain.ground.water_open.12", "terrain", "plain open water, no coastline")
put(34, "terrain.ground.water_open.13", "terrain", "plain open water, no coastline")
put(35, "terrain.ground.water_open.14", "terrain", "plain open water, no coastline")
put(36, "terrain.ground.water_open.15", "terrain", "plain open water, no coastline")
put(37, "terrain.ground.water_open.16", "terrain", "plain open water, no coastline")
put(38, "terrain.ground.water_open.17", "terrain", "plain open water, no coastline")
put(39, "terrain.ground.water_open.18", "terrain", "plain open water, no coastline")
put(40, "terrain.ground.water_open.19", "terrain", "plain open water, no coastline")
put(41, "terrain.ground.water_open.20", "terrain", "plain open water, no coastline")
put(42, "terrain.ground.water_open.21", "terrain", "plain open water, no coastline")
put(43, "terrain.ground.water_open.22", "terrain", "plain open water, no coastline")
put(44, "terrain.ground.water_open.23", "terrain", "plain open water, no coastline")
put(45, "terrain.ground.water_open.24", "terrain", "plain open water, no coastline")
put(46, "terrain.ground.water_open.25", "terrain", "plain open water, no coastline")
put(47, "terrain.ground.water_open.26", "terrain", "plain open water, no coastline")
put(48, "terrain.ground.water_open.27", "terrain", "plain open water, no coastline")
put(49, "terrain.ground.water_open.28", "terrain", "plain open water, no coastline")
put(50, "terrain.ground.water_open.29", "terrain", "plain open water, no coastline")
put(51, "terrain.ground.water_open.30", "terrain", "plain open water, no coastline")
put(52, "terrain.ground.sand_plain.03", "terrain", "plain sand, no water or grass")
put(53, "terrain.ground.sand_plain.04", "terrain", "plain sand, no water or grass")
put(54, "terrain.ground.sand_plain.05", "terrain", "plain sand, no water or grass")
put(55, "terrain.ground.sand_plain.06", "terrain", "plain sand, no water or grass")
put(56, "terrain.ground.sand_plain.07", "terrain", "plain sand, no water or grass")
put(57, "terrain.ground.sand_plain.08", "terrain", "plain sand, no water or grass")
put(58, "terrain.ground.sand_plain.09", "terrain", "plain sand, no water or grass")
put(59, "terrain.ground.sand_plain.10", "terrain", "plain sand, no water or grass")
put(60, "terrain.ground.grass_plain.01", "terrain", "plain grass")
put(61, "terrain.coast.grass_sand.01", "terrain", "grass meeting sand (edge/corner blend)")
put(62, "terrain.coast.grass_sand.02", "terrain", "grass meeting sand (edge/corner blend)")
put(63, "terrain.coast.grass_sand.03", "terrain", "grass meeting sand (edge/corner blend)")
put(64, "terrain.coast.grass_sand.04", "terrain", "grass meeting sand (edge/corner blend)")
put(65, "terrain.coast.grass_sand.05", "terrain", "grass meeting sand (edge/corner blend)")
put(66, "terrain.coast.grass_sand.06", "terrain", "grass meeting sand (edge/corner blend)")
put(67, "terrain.coast.grass_sand.07", "terrain", "grass meeting sand (edge/corner blend)")
put(68, "terrain.coast.grass_sand.08", "terrain", "grass meeting sand (edge/corner blend)")
put(69, "terrain.coast.grass_sand.09", "terrain", "grass meeting sand (edge/corner blend)")
put(70, "terrain.coast.grass_sand.10", "terrain", "grass meeting sand (edge/corner blend)")
put(71, "terrain.coast.grass_sand.11", "terrain", "grass meeting sand (edge/corner blend)")
put(72, "terrain.coast.grass_sand.12", "terrain", "grass meeting sand (edge/corner blend)")


def main():
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)

    seen_ids = {v["id"]: int(k) for k, v in registry["cels"].items()}
    for idx, entry in sorted(ENTRIES.items()):
        if entry["id"] in seen_ids and seen_ids[entry["id"]] != idx:
            raise ValueError(f"duplicate id {entry['id']!r}: cels {seen_ids[entry['id']]} and {idx}")
        seen_ids[entry["id"]] = idx
        registry["cels"][str(idx)] = entry

    with open(REGISTRY_JSON, "w") as f:
        json.dump(registry, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"wrote {len(ENTRIES)} entries ({len(registry['cels'])} total in registry)")


if __name__ == "__main__":
    main()
