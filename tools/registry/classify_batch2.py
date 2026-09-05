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
