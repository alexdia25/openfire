"""Cross-checks every cel this project has actually traced back to real game CODE (not just
eyeballed) against packs/registry/asset_ids.json's own classification of that cel.

Why this exists: document 37/39's Tank investigation found the registry's classification of
cel 188 was flatly wrong (a decoration, when code proves it's a vehicle hull panel) and that
2 more real Tank parts (202, 212) were sitting in the registry under vague, unconfirmed-sounding
notes the whole time -- purely because nothing had ever cross-checked "what does the game's own
code actually build out of this cel" against "what does the registry guess this cel is", for
any cel outside the one vehicle this session happened to trace by hand. This script generalizes
that check to every source of code-verified cel data this project has extracted so far, and is
meant to be re-run as more such sources are added (new vehicle types, new decoration ids, new
per-object-type descriptors), not just for vehicles.

Data sources treated as ground truth (each cel they mention was proven, by tracing real
RFIRE.BIN code, to be part of a specific game object -- this is a categorically stronger claim
than any "visual_group"/"visual" registry entry, which is a human guess from a thumbnail):
  - tools/data/vehicle_type_parts.json (tools/ghidra_scripts/DumpVehicleTypeParts.java) --
    every real part of all 4 vehicle-type descriptors (Tank/Jeep/MSV/Heli).
  - tools/data/coastal_decorations.json (tools/ghidra_scripts/DumpCoastalDecorations.java) --
    every real part of every coastal decoration id.

For each code-verified cel, this reports:
  - MISMATCH: registry category doesn't match the source's expected category at all (a real
    bug, like cel 188's old "decoration" label for a real vehicle part -- document 37).
  - UNVERIFIED: registry category is plausible but confidence is still "visual"/"visual_group"
    -- not wrong, but a guess this data source can now upgrade to something stronger.
  - MISSING: cel isn't in the registry at all.
  - OK: category matches and confidence is already "confirmed" or better.

This is a REPORT-only tool -- it does not write to the registry. Corrections still go through
this project's established hand-patch pattern (direct packs/registry/asset_ids.json edit +
a matching put() correction block in tools/registry/classify_bulk.py), same as document 37's
cel 188 fix, so each correction stays reviewable and documented instead of a silent bulk
rewrite.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")
VEHICLE_PARTS_JSON = os.path.join(ROOT, "tools", "data", "vehicle_type_parts.json")
COASTAL_DECORATIONS_JSON = os.path.join(ROOT, "tools", "data", "coastal_decorations.json")

STRONG_CONFIDENCE = {"confirmed", "code_verified"}

# Categories that describe a RENDERING ROLE incompatible with also being one static part of a
# decoration/vehicle object, regardless of what the cel looks like -- "ui" is a HUD overlay
# (never world-space geometry) and "pickup" is a standalone collectible with its own spawn/pickup
# logic (never someone else's fixed sub-part). Both are real bugs when found this way (document
# 39 found and fixed 4 such cels). Every OTHER category (structure, prop, marker, effect,
# character, terrain...) is left as a softer, genuinely ambiguous finding: a coastal decoration
# can legitimately be assembled out of ordinary "structure"/"prop" pieces that are also
# completely valid standing alone (a building wall segment is still a real "structure" cel even
# though some decoration also uses it) -- recategorizing every such cel to "decoration" would be
# an unreviewed, sweeping taxonomy change this project's own standards don't support on a script's
# say-so. See document 38 for the full discussion.
ROLE_INCOMPATIBLE_CATEGORIES = {"ui", "pickup"}


def _collect_vehicle_cels(path):
    """Returns {cel_index: "vehicle-type-name part N"} for every real part in
    vehicle_type_parts.json (skips a part if its cel index isn't a plausible atlas index --
    the same boundary-detection philosophy as the extraction script itself, since a few
    trailing entries in some types may still be right at the edge of plausible)."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    out = {}
    for _idx, vtype in data["vehicle_types"].items():
        name = vtype["name"]
        for part in vtype["parts"]:
            cel = part["cel"]
            if cel < 0 or cel > 4000:
                continue
            label = f"{name} part {part['part_idx']}"
            out.setdefault(cel, []).append(label)
    return out


def _collect_decoration_cels(path):
    """Returns {cel_index: "coastal decoration N"} for every part of every coastal decoration
    id in coastal_decorations.json."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    out = {}
    for coastal_id, parts in data["decorations"].items():
        for part in parts:
            cel = part["cel"]
            label = f"coastal decoration {coastal_id}"
            out.setdefault(cel, []).append(label)
    return out


def main():
    with open(REGISTRY_JSON, encoding="utf-8") as f:
        registry = json.load(f)
    cels = registry["cels"]

    sources = [
        ("vehicle", _collect_vehicle_cels(VEHICLE_PARTS_JSON)),
        ("decoration", _collect_decoration_cels(COASTAL_DECORATIONS_JSON)),
    ]

    hard_mismatches = []
    soft_mismatches = []
    unverified = []
    missing = []
    ok_count = 0
    total_code_verified_cels = 0

    seen_cels = set()
    for expected_category, cel_map in sources:
        for cel, labels in sorted(cel_map.items()):
            if cel in seen_cels:
                # A cel referenced by more than one source -- report once, against whichever
                # source found it first, rather than double-counting.
                continue
            seen_cels.add(cel)
            total_code_verified_cels += 1
            entry = cels.get(str(cel))
            if entry is None:
                missing.append((cel, expected_category, labels))
                continue
            if entry["category"] != expected_category:
                record = (cel, expected_category, entry["category"], entry["id"], labels)
                if entry["category"] in ROLE_INCOMPATIBLE_CATEGORIES:
                    hard_mismatches.append(record)
                else:
                    soft_mismatches.append(record)
            elif entry.get("confidence") not in STRONG_CONFIDENCE:
                unverified.append((cel, entry["id"], entry.get("confidence"), labels))
            else:
                ok_count += 1

    print(f"code-verified cels checked: {total_code_verified_cels}")
    print(f"  OK (category matches, confidence already strong): {ok_count}")
    print(f"  UNVERIFIED (category plausible, confidence still a guess): {len(unverified)}")
    print(f"  HARD MISMATCH (role-incompatible category -- a real bug): {len(hard_mismatches)}")
    print(f"  SOFT MISMATCH (plausible composite reuse, needs human judgment): {len(soft_mismatches)}")
    print(f"  MISSING (not in registry at all): {len(missing)}")
    mismatches = hard_mismatches  # kept for the shared printer below; soft ones print separately

    if hard_mismatches:
        print(f"\n{len(hard_mismatches)} HARD MISMATCH(ES) -- role-incompatible category, a "
              f"real bug regardless of what the cel looks like:")
        for cel, expected, actual, reg_id, labels in hard_mismatches:
            print(f"  cel {cel}: registry says category={actual!r} ({reg_id}), "
                  f"but real code says category={expected!r} -- {', '.join(labels)}")

    if soft_mismatches:
        print(f"\n{len(soft_mismatches)} SOFT MISMATCH(ES) -- plausible composite reuse (e.g. a "
              f"decoration built from ordinary structure/prop pieces that are also valid "
              f"standing alone) -- needs human judgment, NOT auto-fixed by this script:")
        for cel, expected, actual, reg_id, labels in soft_mismatches:
            print(f"  cel {cel}: registry says category={actual!r} ({reg_id}), "
                  f"real code also uses it as a {expected!r} part -- {', '.join(labels)}")

    if missing:
        print(f"\n{len(missing)} MISSING -- code-verified but not in the registry at all:")
        for cel, expected, labels in missing:
            print(f"  cel {cel}: expected category={expected!r} -- {', '.join(labels)}")

    if unverified:
        print(f"\n{len(unverified)} UNVERIFIED -- category is right, confidence could be "
              f"upgraded to code_verified now that real code confirms it:")
        for cel, reg_id, confidence, labels in unverified:
            print(f"  cel {cel} ({reg_id}, confidence={confidence!r}) -- {', '.join(labels)}")


if __name__ == "__main__":
    main()
