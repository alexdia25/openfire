"""Phase 1e (second half): emit a real content pack (PORTING_PLAN.md section 2.4.2)
from the existing ART.CAR atlas + the asset ID registry (section 2.4.1, done).

This is the thing Phase 4 actually needs to exist before it can load anything --
the engine must never read art_atlas.json/png directly (section 2.4), only a pack.
Output goes to /packs/<pack_id>/, which is gitignored (see .gitignore) because it
embeds real pixel data sliced out of the user's own ART.CAR -- exactly the kind of
extracted-asset output section 0 says must never be committed.

What this emits, and what it doesn't yet:
  - pack.json               manifest (section 2.4.2)
  - sprites/sprites.json    every cel -> {page, x, y, w, h, pivot_x, pivot_y}, keyed
                            by its registry ID. Sprite pages are the SAME atlas PNGs
                            convert_car.py already produces (section 2.4.2 explicitly
                            allows "atlas pages, or loose frames" -- no need to
                            re-slice into 2165 individual files).
  - terrain/tileset.json    raw art id (0-127) -> sprite id + a coarse terrain_class
                            guess, for the 0-111 terrain block (section 1.7: art id
                            IS the cel index, no separate mapping table needed).
  - reserved.blank.* cels are included for completeness (a terrain tile can validly
    reference one and render nothing) rather than special-cased out.

NOT yet emitted (left for later, not a blocker for Phase 4 step 1 "render terrain +
static objects"): animations.json (grouping registry IDs into real frame sequences
needs the coarse-pass IDs refined first -- see docs/process/19), audio/, fonts/,
ui/. Pivots are a flat centre-of-cel default (w/2, h/2) since real pivot recovery
(section 2.4.3 item 2) hasn't happened -- every sprite entry says so via
"pivot_source": "default_center" rather than silently implying it was recovered.

Also emits levels/ -- an addition to section 2.4.2's schema, not in the original plan
text: each converted .RFM (tools/convert_rfm.py output, already in build/rfm/) is
copied in as levels/<NAME>/level.json + art.bin. This is still converted, non-raw-
format output (JSON + a resolved art-id byte grid, not copyrighted .RFM bytes
verbatim), but it's still derived from the user's own level files, so it lives in the
same gitignored pack, not the repo -- same reasoning as the sprite pixel data above.

Usage:
    python tools/build_pack.py <returnfire_dir> <out_dir>
    (out_dir defaults to packs/original_pc; expects build/car/art_atlas.json and
    art_atlas.png/art_effects.png, and build/rfm/*.json + *.art.bin, to already exist --
    run convert_car.py and convert_rfm.py first)
"""
import argparse
import json
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_BUILD_CAR = os.path.join(ROOT, "build", "car")
DEFAULT_BUILD_RFM = os.path.join(ROOT, "build", "rfm")
DEFAULT_OUT = os.path.join(ROOT, "packs", "original_pc")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

PACK_ID = "original_pc"
PIXELS_PER_WORLD_UNIT = 32  # matches the original's 32x32 terrain tile, section 2.4.3 item 1

TERRAIN_CLASS_PREFIXES = [
    ("terrain.coast.", "coast"),
    ("terrain.structure.", "structure"),
    ("terrain.ground.buildable", "buildable"),
    ("terrain.ground.blank", "blank"),
    ("terrain.ground.", "ground"),
    ("marker.", "marker"),
    ("decoration.", "decoration"),
]


def terrain_class_for(registry_id):
    for prefix, cls in TERRAIN_CLASS_PREFIXES:
        if registry_id.startswith(prefix):
            return cls
    return "other"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("build_car_dir", nargs="?", default=DEFAULT_BUILD_CAR,
                     help="dir with art_atlas.json/.png and art_effects.json/.png (default: build/car)")
    ap.add_argument("out_dir", nargs="?", default=DEFAULT_OUT,
                     help="pack output dir (default: packs/original_pc)")
    ap.add_argument("--build-rfm-dir", default=DEFAULT_BUILD_RFM,
                     help="dir with convert_rfm.py output, *.json + *.art.bin (default: build/rfm)")
    args = ap.parse_args()

    with open(os.path.join(args.build_car_dir, "art_atlas.json")) as f:
        atlas = json.load(f)
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)["cels"]

    cels = {c["index"]: c for c in atlas["cels"]}
    missing = [idx for idx in cels if str(idx) not in registry]
    if missing:
        raise SystemExit(f"{len(missing)} cels have no registry entry (run tools/registry/validate_registry.py); "
                          f"first few: {missing[:10]}")

    sprites_dir = os.path.join(args.out_dir, "sprites")
    terrain_dir = os.path.join(args.out_dir, "terrain")
    os.makedirs(sprites_dir, exist_ok=True)
    os.makedirs(terrain_dir, exist_ok=True)

    shutil.copyfile(os.path.join(args.build_car_dir, "art_atlas.png"),
                     os.path.join(sprites_dir, "art_atlas.png"))
    shutil.copyfile(os.path.join(args.build_car_dir, "art_effects.png"),
                     os.path.join(sprites_dir, "art_effects.png"))

    sprites = {}
    for idx, c in cels.items():
        reg_id = registry[str(idx)]["id"]
        if reg_id in sprites:
            raise SystemExit(f"duplicate registry id {reg_id!r} (cel {idx} and an earlier one) -- "
                              f"registry should be unique, this is a bug upstream, not here")
        page = 0 if c["kind"] == "sprite" else 1
        sprites[reg_id] = {
            "page": page,
            "x": c["x"], "y": c["y"], "w": c["w"], "h": c["h"],
            "pivot_x": round(c["w"] / 2, 1), "pivot_y": round(c["h"] / 2, 1),
            "pivot_source": "default_center",
        }

    sprites_json = {
        "atlas_pages": ["art_atlas.png", "art_effects.png"],
        "sprites": sprites,
    }
    with open(os.path.join(sprites_dir, "sprites.json"), "w") as f:
        json.dump(sprites_json, f, indent=2, sort_keys=True)
        f.write("\n")

    # Terrain tileset: art id IS the cel index (section 1.7) -- 0-111 is the tile block
    # (section 1.7's finding, cross-checked against the registry's own terrain batch).
    tileset = {}
    for art_id in range(112):
        if art_id not in cels:
            continue
        reg_id = registry[str(art_id)]["id"]
        tileset[str(art_id)] = {
            "sprite_id": reg_id,
            "terrain_class": terrain_class_for(reg_id),
        }
    with open(os.path.join(terrain_dir, "tileset.json"), "w") as f:
        json.dump({"tile_size_px": 32, "tiles": tileset}, f, indent=2, sort_keys=True)
        f.write("\n")

    pack_manifest = {
        "id": PACK_ID,
        "name": "Return Fire (1996) -- Original PC Port Assets",
        "version": "0.1.0",
        "engine_api_version": "0.1.0",
        "author": "Silent Software (original assets); pack structure generated by returnfire-godot",
        "license": "Requires the user's own legally owned copy of Return Fire -- not for redistribution. "
                   "See docs/PORTING_PLAN.md section 0.",
        "base_pack": None,
        "overrides": [],
        "pixels_per_world_unit": PIXELS_PER_WORLD_UNIT,
        "team_colours": {"team_a": "tan", "team_b": "green"},
    }
    with open(os.path.join(args.out_dir, "pack.json"), "w") as f:
        json.dump(pack_manifest, f, indent=2, sort_keys=True)
        f.write("\n")

    levels_dir = os.path.join(args.out_dir, "levels")
    n_levels = 0
    if os.path.isdir(args.build_rfm_dir):
        os.makedirs(levels_dir, exist_ok=True)
        for name in sorted(os.listdir(args.build_rfm_dir)):
            if not name.endswith(".json"):
                continue
            stem = name[:-len(".json")]
            art_bin = os.path.join(args.build_rfm_dir, stem + ".art.bin")
            level_json = os.path.join(args.build_rfm_dir, name)
            if not os.path.exists(art_bin):
                continue
            out_level_dir = os.path.join(levels_dir, stem)
            os.makedirs(out_level_dir, exist_ok=True)
            shutil.copyfile(level_json, os.path.join(out_level_dir, "level.json"))
            shutil.copyfile(art_bin, os.path.join(out_level_dir, "art.bin"))
            n_levels += 1

    print(f"wrote pack {PACK_ID!r} to {args.out_dir}: {len(sprites)} sprites, "
          f"{len(tileset)} terrain tiles, {n_levels} levels")


if __name__ == "__main__":
    main()
