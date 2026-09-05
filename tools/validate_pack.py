"""Validate a content pack against the asset ID registry and its own internal
consistency (PORTING_PLAN.md section 2.4.3 requirement 7: "ship tools/validate_pack.py
reporting missing IDs, unknown IDs, absent pivots, malformed regions" -- a third-party
artist needs this to work without reading engine source).

Checks:
  - pack.json has every required manifest field
  - every sprites.json region fits inside its declared atlas page's real pixel dimensions
  - every sprite has a pivot (even a default one -- absent, not just wrong, is an error)
  - terrain/tileset.json's sprite_id references all resolve to a real sprite
  - every registry ID this pack claims to cover is actually present (missing IDs);
    flags any sprite id in the pack NOT in the registry too (unknown IDs) -- this can
    happen if a pack is built against a stale registry snapshot

Usage:
    python tools/validate_pack.py [pack_dir]   (default: packs/original_pc)
"""
import argparse
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

REQUIRED_PACK_FIELDS = ["id", "name", "version", "engine_api_version", "author", "license",
                         "base_pack", "overrides", "pixels_per_world_unit"]
REQUIRED_SPRITE_FIELDS = ["page", "x", "y", "w", "h", "pivot_x", "pivot_y"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pack_dir", nargs="?", default=os.path.join(ROOT, "packs", "original_pc"))
    args = ap.parse_args()

    errors = []
    warnings = []

    pack_json_path = os.path.join(args.pack_dir, "pack.json")
    if not os.path.exists(pack_json_path):
        raise SystemExit(f"no pack.json at {pack_json_path}")
    with open(pack_json_path) as f:
        manifest = json.load(f)
    for field in REQUIRED_PACK_FIELDS:
        if field not in manifest:
            errors.append(f"pack.json missing required field {field!r}")

    sprites_json_path = os.path.join(args.pack_dir, "sprites", "sprites.json")
    with open(sprites_json_path) as f:
        sprites_doc = json.load(f)
    pages = sprites_doc["atlas_pages"]
    sprites = sprites_doc["sprites"]

    page_sizes = []
    for page_name in pages:
        page_path = os.path.join(args.pack_dir, "sprites", page_name)
        if not os.path.exists(page_path):
            errors.append(f"atlas page {page_name!r} listed in sprites.json but file missing")
            page_sizes.append(None)
            continue
        page_sizes.append(Image.open(page_path).size)

    for sprite_id, entry in sprites.items():
        for field in REQUIRED_SPRITE_FIELDS:
            if field not in entry:
                errors.append(f"sprite {sprite_id!r} missing required field {field!r}")
                break
        else:
            page_idx = entry["page"]
            if page_idx < 0 or page_idx >= len(pages):
                errors.append(f"sprite {sprite_id!r} references page {page_idx}, out of range")
                continue
            size = page_sizes[page_idx]
            if size is None:
                continue
            pw, ph = size
            x, y, w, h = entry["x"], entry["y"], entry["w"], entry["h"]
            if x < 0 or y < 0 or x + w > pw or y + h > ph:
                errors.append(f"sprite {sprite_id!r} region ({x},{y},{w},{h}) exceeds "
                              f"page {pages[page_idx]!r} bounds ({pw}x{ph})")

    if os.path.exists(REGISTRY_JSON):
        with open(REGISTRY_JSON) as f:
            registry_ids = {v["id"] for v in json.load(f)["cels"].values()}
        pack_ids = set(sprites.keys())
        missing = registry_ids - pack_ids
        unknown = pack_ids - registry_ids
        if missing:
            warnings.append(f"{len(missing)} registry IDs not present in this pack (sample: "
                             f"{sorted(missing)[:5]})")
        if unknown:
            errors.append(f"{len(unknown)} sprite IDs in this pack are not in the current registry "
                          f"(sample: {sorted(unknown)[:5]}) -- pack may be stale, rebuild it")
    else:
        warnings.append("no registry found to cross-check IDs against")

    tileset_path = os.path.join(args.pack_dir, "terrain", "tileset.json")
    if os.path.exists(tileset_path):
        with open(tileset_path) as f:
            tileset = json.load(f)["tiles"]
        for art_id, tile in tileset.items():
            if tile["sprite_id"] not in sprites:
                errors.append(f"tileset art id {art_id} references sprite_id "
                              f"{tile['sprite_id']!r}, not found in sprites.json")

    print(f"pack: {args.pack_dir}")
    print(f"sprites: {len(sprites)}, atlas pages: {len(pages)}")
    if warnings:
        print(f"\n{len(warnings)} warning(s):")
        for w in warnings:
            print(" -", w)
    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(" -", e)
        sys.exit(1)
    print("\nno errors")


if __name__ == "__main__":
    main()
