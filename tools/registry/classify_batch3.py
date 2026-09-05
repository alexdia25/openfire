"""Classification batch 3: cel indices 154-216 (minus the fully-blank ones already
auto-classified by classify_blank.py) -- plant decorations, and the first ground
vehicle: a tracked hovercraft/APC shown in tan and cyan colour variants.

From here on, vehicle/building parts use a coarser convention than batch 1's terrain
tiles: a shared object prefix (e.g. "hovercraft") + a sequential "part" or sub-category
number, confidence "visual_group". Precisely which anatomical part a cel is (hull side
vs front vs top) is not load-bearing for the registry's purpose -- an artist replacing
the pack looks at the rendered reference image regardless -- so this batch does not
strain to be more precise than the pixels obviously support.

Notable observation worth carrying into PORTING_PLAN.md section 4 (team colouring,
previously "no lead"): cels 167-209 include the SAME hovercraft hull/cab pieces
duplicated in tan and cyan with matching pose (e.g. 172/173, 177/178, 192/193,
197/198). That's consistent with per-team duplicate art rather than a palette swap
at draw time, at least for this vehicle -- flagged in the notes below, not yet
confirmed against code.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

TEAM_NOTE = ("possible team-colour lead (2026-09-06): this hovercraft hull piece "
             "recurs in both tan and cyan with matching pose -- see PORTING_PLAN.md "
             "section 4 item 3 (team colouring). Not confirmed against code.")

ENTRIES = {}


def put(idx, id_, category, note=None, confidence="visual_group"):
    ENTRIES[idx] = {"id": id_, "category": category, "confidence": confidence, **({"note": note} if note else {})}


for n, idx in enumerate([154, 155, 156], start=1):
    put(idx, f"decoration.plant.sapling.{n:02d}", "decoration")
for n, idx in enumerate([157, 158], start=1):
    put(idx, f"decoration.plant.flower_red.{n:02d}", "decoration")
for n, idx in enumerate([159, 160], start=1):
    put(idx, f"decoration.plant.coral_red.{n:02d}", "decoration")
for n, idx in enumerate([161, 162], start=1):
    put(idx, f"decoration.plant.reeds.{n:02d}", "decoration")
for n, idx in enumerate([163, 164, 165], start=1):
    put(idx, f"decoration.plant.vine_berry.{n:02d}", "decoration")
put(166, "decoration.plant.stem_h.01", "decoration")

hull = [(167, "tan pillar"), (168, "dark-red pillar"), (169, "tan pillar"),
        (172, "tan oval hull-top"), (173, "cyan oval hull-top", TEAM_NOTE),
        (174, "orange/gold ornate oval hull-top"),
        (177, "tan block, red-dot windows"), (178, "cyan block, red-dot windows", TEAM_NOTE),
        (184, "tan panel"), (187, "cyan panel", TEAM_NOTE),
        (189, "tan cab, red visor+trim"), (192, "tan cab, red eyes+mouth trim"),
        (193, "cyan cab, red eyes+mouth trim", TEAM_NOTE),
        (197, "tan panel"), (198, "cyan panel", TEAM_NOTE),
        (202, "assembled composite side view w/ barrel-like extension"),
        (206, "tan panel"), (207, "tan panel"),
        (208, "green/teal camo cab variant"), (209, "brown/green camo cab variant")]
for n, item in enumerate(hull, start=1):
    idx, desc = item[0], item[1]
    note = item[2] if len(item) > 2 else desc
    put(idx, f"vehicle.hovercraft.hull.{n:02d}", "vehicle", note)

for n, idx in enumerate([170, 171, 179, 194, 199], start=1):
    put(idx, f"decoration.emblem.{n:02d}", "decoration", "ornate insignia-like pattern, not clearly a hull piece")
for n, idx in enumerate([175, 176], start=1):
    put(idx, f"decoration.debris.{n:02d}", "decoration", "small loose chip, tan/blue")
for n, idx in enumerate([182, 183], start=1):
    put(idx, f"vehicle.hovercraft.track.{n:02d}", "vehicle", "tank-tread segment")
put(203, "vehicle.hovercraft.turret_detail.01", "vehicle")
for n, idx in enumerate([204, 205, 215, 216], start=1):
    put(idx, f"decoration.tire_track.{n:02d}", "decoration", "yellow dashed ground mark")
for n, idx in enumerate([212, 213, 214], start=1):
    put(idx, f"vehicle.hovercraft.wheel_hub.{n:02d}", "vehicle", "concentric-ring wheel/turret-base icon")
put(188, "decoration.stripe_band.01", "decoration", "horizontal orange/green/tan banded strip, purpose unconfirmed")


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
