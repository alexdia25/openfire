"""Classification batch 1 for the asset ID registry (PORTING_PLAN.md 2.4.1):
- the terrain tileset block, cel indices 0-111 (section 1.7)
- the 89 effect-mask cels, auto-classified by PRE0 family (section 1.6 / rf_effect_cel.py)
- the 4 PRE0==17 target-lock reticle cels (section 1.6)

This is a one-time authoring script, not a converter -- it is meant to be read as a
record of *why* each cel got the ID it did. Re-running it regenerates the same output
deterministically from build/car/art_atlas.json; it never touches /build/.

Confidence levels used below:
  "confirmed"    -- traced through RFIRE.BIN's code, not just inferred from pixels
                    (e.g. cel 109 = buildable ground, section 1.7's dispatch-tile override)
  "visual"       -- assigned by looking at the rendered cel; shape/colour is exactly as
                    described, but the *gameplay* role (which biome, which building type)
                    is this project's best reading, not verified against code or manual.
  "visual_group" -- part of a visually-obvious autotile family (e.g. a sand/water coastline
                    tile) where the specific ID number is an arbitrary but stable index into
                    that family, not a claim about which exact edge/corner it represents
                    (no orientation data exists in tile_lookup_tables.json to confirm N/S/E/W).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "build", "car", "art_atlas.json")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

NOT_SEEN_IN_RETAIL_LEVELS = {92, 102, 105, 106, 107, 108}


def terrain_entries():
    entries = {}

    def put(idx, id_, note=None, confidence="visual_group"):
        e = {"id": id_, "category": "terrain", "confidence": confidence}
        if note:
            e["note"] = note
        if idx in NOT_SEEN_IN_RETAIL_LEVELS:
            e["seen_in_retail_levels"] = False
        entries[idx] = e

    # base fills
    put(0, "terrain.coast.sand_water.mottled_shallow",
        "speckled sand/water blend with no hard coastline, unlike 4-23", "visual")
    put(1, "terrain.ground.sand_light", confidence="visual")
    put(2, "terrain.ground.sand_warm", confidence="visual")
    put(3, "terrain.ground.forest_dense.a", confidence="visual")

    # sand/water coastline autotile family -- 20 shapes, arbitrary stable order
    sand_water_main = list(range(4, 24))
    for n, idx in enumerate(sand_water_main, start=1):
        put(idx, f"terrain.coast.sand_water.{n:02d}")

    # minor sand edge cases, some plain, some with a small water sliver
    minor = {24: "sand_water.21", 25: "sand_water.22", 26: "sand_light.b",
             27: "sand_water.23", 28: "sand_light.c", 29: "sand_water.24",
             30: "sand_light.d", 31: "sand_light.e"}
    for idx, suffix in minor.items():
        put(idx, f"terrain.{'coast' if 'sand_water' in suffix else 'ground'}.{suffix}",
            "thin water sliver at tile edge" if "sand_water" in suffix else "plain, no water visible")

    # second ground biome -- plain dune/dry ground, 32-48
    for n, idx in enumerate(range(32, 49), start=1):
        put(idx, f"terrain.ground.dune_plain.{n:02d}")

    # ripple transition toward the forest/water family
    for n, idx in enumerate(range(49, 52), start=1):
        put(idx, f"terrain.coast.dune_water.{n:02d}", "soft ripple edge, no hard coastline border")

    put(52, "terrain.ground.forest_dense.b", confidence="visual")

    # forest/water coastline autotile family -- 20 shapes, mirrors the sand family
    for n, idx in enumerate(range(53, 73), start=1):
        put(idx, f"terrain.coast.forest_water.{n:02d}")

    # red-roofed building/structure tileset
    rooftop_indices = list(range(73, 80)) + list(range(81, 84)) + list(range(87, 90))
    for n, idx in enumerate(rooftop_indices, start=1):
        put(idx, f"terrain.structure.rooftop_red.{n:02d}", confidence="visual")

    put(80, "terrain.ground.blank.a", "fully transparent tile (index-0 pixels only)", "visual")
    put(92, "terrain.ground.blank.b", "fully transparent tile (index-0 pixels only)", "visual")

    for n, idx in enumerate([84, 85, 86], start=1):
        put(idx, f"terrain.ground.furrow_green.{n:02d}",
            "green striped texture, function unconfirmed (crop rows / hedge / runway marking)",
            "visual")

    put(90, "marker.target.bullseye_green", "red-bordered square, green-and-red bullseye centre", "visual")
    put(91, "marker.target.bullseye_cyan", "red-bordered square, cyan-and-red bullseye centre", "visual")
    put(93, "decoration.grass_patch", "yellow-bordered green square", "visual")
    put(94, "decoration.water_patch", "yellow-bordered mottled blue square", "visual")
    put(95, "decoration.reef_patch", "yellow-bordered blue-green mottled square with light flecks", "visual")
    put(96, "marker.target.bullseye_moon", "bullseye with a gold crescent-moon centre", "visual")

    for n, idx in enumerate([97, 98, 99, 100], start=1):
        put(idx, f"terrain.ground.red_panel.{n:02d}", "plain solid/mottled red panel", "visual")

    put(101, "decoration.tree", "dark green canopy on a post/trunk", "visual")
    put(102, "terrain.ground.teal_panel", "plain solid teal panel", "visual")
    put(103, "decoration.shrub", "dark mottled patch on lighter ground", "visual")
    put(104, "marker.hazard_stripe", "orange/black diagonal hazard stripes", "visual")

    for n, idx in enumerate([105, 106, 107, 108], start=1):
        put(idx, f"terrain.ground.rubble_red.{n:02d}", "red spatter/rubble texture on black", "visual")

    put(109, "terrain.ground.buildable",
        "CONFIRMED (section 1.7): the art-id override applied to building-candidate dispatch "
        "tiles (raw bytes 0xB4/0xDC)", "confirmed")

    for n, idx in enumerate([110, 111], start=5):
        put(idx, f"terrain.ground.rubble_red.{n:02d}", "red spatter/rubble texture on black", "visual")

    assert len(entries) == 112, f"expected 112 terrain entries, got {len(entries)}"
    return entries


def effect_and_reticle_entries(atlas):
    entries = {}
    cels = atlas["cels"]

    families = {
        1: ("shadow", "hard", "flat darken_row4 (~84%) shadow, linear mask, real bytes {0,11}"),
        13: ("shadow", "hard", "flat darken_row4 (~84%) shadow, span-encoded mask -- same table as PRE0 1"),
        2: ("shadow", "soft", "flat darken_row2 (~91%) shadow, linear mask, real bytes {0,243}"),
        3: ("tint", "colour", "per-pixel tint-target index into the 256x256 aa0c table"),
        5: ("glow", None, "per-pixel brightness index into the 32-row brighten table (explosion/glow gradient)"),
    }
    counters = {}
    for c in sorted(cels, key=lambda c: c["index"]):
        if c["kind"] != "effect_mask":
            continue
        pre0 = c["pre0"]
        family, sub, note = families[pre0]
        key = (family, sub)
        counters[key] = counters.get(key, 0) + 1
        n = counters[key]
        id_ = f"effect.{family}.{sub}.{n:03d}" if sub else f"effect.{family}.{n:03d}"
        entries[c["index"]] = {
            "id": id_, "category": "effect", "confidence": "confirmed",
            "note": f"PRE0={pre0}: {note}",
        }

    reticle_indices = sorted(c["index"] for c in cels if c["kind"] == "sprite" and c.get("pre0") == 17)
    assert len(reticle_indices) == 4, f"expected 4 PRE0==17 reticle cels, got {reticle_indices}"
    for n, idx in enumerate(reticle_indices, start=1):
        entries[idx] = {
            "id": f"ui.reticle.target_lock.{n:02d}", "category": "ui", "confidence": "visual",
            "note": ("16x16 concentric-ring bullseye, own embedded palette (section 1.6). "
                     "Distinct colour per variant; meaning (team? animation frame?) UNCONFIRMED "
                     "-- ruled out as a team-colour swatch (section 1.6, 2026-09-06)."),
        }

    return entries


def main():
    with open(ATLAS_JSON) as f:
        atlas = json.load(f)

    entries = {}
    entries.update(terrain_entries())
    entries.update(effect_and_reticle_entries(atlas))

    os.makedirs(os.path.dirname(REGISTRY_JSON), exist_ok=True)
    if os.path.exists(REGISTRY_JSON):
        with open(REGISTRY_JSON) as f:
            registry = json.load(f)
    else:
        registry = {
            "schema_version": "0.1.0",
            "source": "ART.CAR, 2165 cels (see PORTING_PLAN.md section 1.6)",
            "cels": {},
        }

    seen_ids = {}
    for idx, entry in sorted(entries.items()):
        if entry["id"] in seen_ids:
            raise ValueError(f"duplicate id {entry['id']!r}: cels {seen_ids[entry['id']]} and {idx}")
        seen_ids[entry["id"]] = idx
        registry["cels"][str(idx)] = entry

    with open(REGISTRY_JSON, "w") as f:
        json.dump(registry, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"wrote {len(entries)} entries ({len(registry['cels'])} total in registry) to {REGISTRY_JSON}")


if __name__ == "__main__":
    main()
