"""Sanity-check packs/registry/asset_ids.json against build/car/art_atlas.json:
- every registry cel index actually exists in the atlas
- no duplicate semantic IDs
- reports how many of the atlas's 2165 cels are still unclassified (by category)

This is a lightweight precursor to the full tools/validate_pack.py described in
PORTING_PLAN.md section 2.4.3 item 7 (which validates a whole content pack against
the registry); this one just checks the registry's own internal consistency plus
coverage, since that's what's needed while the registry itself is still being built.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "build", "car", "art_atlas.json")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")


def main():
    with open(ATLAS_JSON) as f:
        atlas = json.load(f)
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)

    atlas_indices = {c["index"] for c in atlas["cels"]}
    cels = registry["cels"]
    errors = []

    seen_ids = {}
    for idx_str, entry in cels.items():
        idx = int(idx_str)
        if idx not in atlas_indices:
            errors.append(f"registry cel {idx} does not exist in art_atlas.json")
        if entry["id"] in seen_ids:
            errors.append(f"duplicate id {entry['id']!r}: cels {seen_ids[entry['id']]} and {idx}")
        seen_ids[entry["id"]] = idx

    classified = {int(k) for k in cels.keys()}
    unclassified = atlas_indices - classified

    by_kind = {}
    cel_by_index = {c["index"]: c for c in atlas["cels"]}
    for idx in unclassified:
        k = cel_by_index[idx]["kind"]
        by_kind[k] = by_kind.get(k, 0) + 1

    print(f"atlas cels: {len(atlas_indices)}")
    print(f"registry entries: {len(cels)}")
    print(f"unclassified: {len(unclassified)}  {by_kind}")
    if errors:
        print(f"\n{len(errors)} ERROR(S):")
        for e in errors:
            print(" -", e)
        sys.exit(1)
    print("no errors")


if __name__ == "__main__":
    main()
