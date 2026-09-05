"""Auto-classify every remaining unclassified sprite cel that is 100% transparent
(alpha extrema (0,0) across the whole crop) as a reserved/blank placeholder.

These aren't a visual family to look at -- they're empty. Confirmed the same pattern
already exists in the terrain block (cels 80/92, section 2.4.1 batch 1) where a cel
slot is fully transparent by design. Auto-detecting these programmatically (rather
than eyeballing contact sheets) is strictly more reliable and much faster.
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "build", "car", "art_atlas.json")
ATLAS_PNG = os.path.join(ROOT, "build", "car", "art_atlas.png")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")


def main():
    with open(ATLAS_JSON) as f:
        atlas = json.load(f)
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)

    classified = {int(k) for k in registry["cels"].keys()}
    sprite_atlas = Image.open(ATLAS_PNG).convert("RGBA")

    blank = []
    for c in atlas["cels"]:
        idx = c["index"]
        if idx in classified or c["kind"] != "sprite":
            continue
        crop = sprite_atlas.crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
        if crop.getextrema()[3] == (0, 0):
            blank.append(idx)
    blank.sort()

    for n, idx in enumerate(blank, start=1):
        registry["cels"][str(idx)] = {
            "id": f"reserved.blank.{n:04d}",
            "category": "reserved",
            "confidence": "confirmed",
            "note": "cel is 100% transparent (alpha all-zero) -- no art here, verified "
                    "programmatically against art_atlas.png, not a guess",
        }

    with open(REGISTRY_JSON, "w") as f:
        json.dump(registry, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"classified {len(blank)} fully-transparent cels as reserved.blank.*")
    print(f"registry now has {len(registry['cels'])} entries")


if __name__ == "__main__":
    main()
