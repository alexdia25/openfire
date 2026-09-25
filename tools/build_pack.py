"""Phase 1e (second half): emit a real content pack (PORTING_PLAN.md section 2.4.2)
from the existing ART.CAR atlas + the asset ID registry (section 2.4.1, done).

This is the thing Phase 4 actually needs to exist before it can load anything --
the engine must never read art_atlas.json/png directly (section 2.4), only a pack.
Output goes to /packs/<pack_id>/, which is gitignored (see .gitignore) because it
embeds real pixel data sliced out of the user's own ART.CAR -- exactly the kind of
extracted-asset output section 0 says must never be committed.

What this emits, and what it doesn't yet:
  - pack.json               manifest (section 2.4.2)
  - sprites/<group>/<name>.png + sprites/sprites.json
                            every cel as its own PNG ("loose frames", section 2.4.2),
                            cut out of convert_car.py's atlas and filed by its registry
                            ID (vehicle.tank.hull.01 ->
                            sprites/vehicle/tank/hull.01.png); sprites.json maps
                            each id -> {file, w, h, pivot_x, pivot_y, kind}. Pack.gd
                            packs the frames into atlas pages at load time, so a
                            replacement pack can swap single frames (PORTING_PLAN.md
                            2.7.5; this replaced two shipped atlas pages, 2026-09-24).
                            `kind` is "effect" for the effect-mask cels (document 9),
                            which used to be told apart only by living on page 1.
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

Also emits terrain/decorations.json -- coastal-blend id (every level.json's own
"decorations" list is keyed by this, per tile) -> the real ART.CAR parts that id spawns
(document 35, docs/process/): resolves tools/data/coastal_decorations.json's cel indices
through the same registry the sprite atlas already uses, so the engine only ever sees
sprite ids, never raw cel numbers, exactly like terrain/tileset.json already does for
plain ground tiles. Ids tools/data/coastal_decorations.json doesn't (yet) resolve are
simply absent -- callers treat an unknown coastal id as "no decoration", not an error.

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

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_BUILD_CAR = os.path.join(ROOT, "build", "car")
DEFAULT_BUILD_RFM = os.path.join(ROOT, "build", "rfm")
DEFAULT_BUILD_SOUND = os.path.join(ROOT, "build", "sound")
DEFAULT_OUT = os.path.join(ROOT, "packs", "original_pc")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")
COASTAL_DECORATIONS_JSON = os.path.join(ROOT, "tools", "data", "coastal_decorations.json")
COASTAL_DAMAGE_JSON = os.path.join(ROOT, "tools", "data", "coastal_damage.json")
EXPLOSION_RECORDS_JSON = os.path.join(ROOT, "tools", "data", "explosion_records.json")
COASTAL_SHAPES_JSON = os.path.join(ROOT, "tools", "data", "coastal_shapes.json")
GATES_JSON = os.path.join(ROOT, "tools", "data", "gates.json")
SOUND_CUES_JSON = os.path.join(ROOT, "tools", "data", "sound_cues.json")
WATER_JSON = os.path.join(ROOT, "tools", "data", "water_tables.json")
FLAG_JSON = os.path.join(ROOT, "tools", "data", "flag.json")
RADAR_JSON = os.path.join(ROOT, "tools", "data", "radar.json")
HUD_PANELS_JSON = os.path.join(ROOT, "tools", "data", "hud_panels.json")
SELECTOR_JSON = os.path.join(ROOT, "tools", "data", "selector.json")
GAME_ART_CAR = os.path.join(os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire"), "ART", "ART.CAR")
VEHICLE_TYPES_JSON = os.path.join(ROOT, "tools", "data", "vehicle_types.json")
ENGINE_LOOPS_JSON = os.path.join(ROOT, "tools", "data", "engine_loops.json")
PROJECTILE_TYPES_JSON = os.path.join(ROOT, "tools", "data", "projectile_types.json")
COASTAL_DECORATION_CORNERS_JSON = os.path.join(ROOT, "tools", "data", "coastal_decoration_corners.json")

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


def sprite_file(sprite_id):
    """A sprite id's loose-frame path under sprites/: the first two id segments are folders (the object), the rest the
    file name -- vehicle.tank.hull.01 -> vehicle/tank/hull.01.png."""
    parts = sprite_id.split(".")
    return "/".join(parts[:2]) + "/" + ".".join(parts[2:]) + ".png" if len(parts) > 2 else "/".join(parts) + ".png"


# Team colour presets beyond the original two (PORTING_PLAN.md 2.7.7). PORT PRESETS, not from the original:
# each is the HSV mean a recolour aims the team pixels at, like the measured means of tan and green.
TEAM_COLOUR_PRESETS = {
    "red": [0.0, 0.75, 0.55],
    "blue": [0.61, 0.70, 0.55],
    "yellow": [0.14, 0.80, 0.70],
    "grey": [0.0, 0.03, 0.50],
    "white": [0.0, 0.05, 0.85],
    "black": [0.0, 0.10, 0.18],
}
TEAM_PAIR_MIN_CONSISTENCY = 0.6   # share of changed pixels that follow their tan colour's usual green colour


def emit_team_colours(out_dir, sprites_dir, sprites, registry, cels, flag_pairs):
    """PORTING_PLAN.md 2.7.7: every (tan, green) sprite pair the traced data implies -- flag-8 parts (the cel + 1
    team variant, documents 44/57/59), the flag's +13 frames (document 65), and registry ids that differ only by a
    `tan`/`green` segment -- is checked to really be a recolour (same size and footprint, changed pixels mapping
    consistently tan -> green), then written to sprites/team_sets.json {tan id: green id}. teams/colours.json holds
    the colours: tan and green are the original art (with their measured HSV means), the rest port presets that
    Pack recolours tan art to at load. Returns the number of accepted pairs."""
    import colorsys
    import math
    from collections import Counter, defaultdict
    by_id = {registry[str(c)]["id"]: c for c in cels}
    pairs = set()
    named = set()   # pairs whose ids say tan / green: trusted with a looser footprint check (the Heli rotor's green
                    # blades are drawn a few pixels differently, but they are the same part)
    for a, b in flag_pairs:
        if a in cels and b in cels:
            pairs.add((registry[str(a)]["id"], registry[str(b)]["id"]))
    for sid in by_id:
        segs = sid.split(".")
        if "tan" in segs:
            other = ".".join("green" if x == "tan" else x for x in segs)
            if other in by_id:
                pairs.add((sid, other))
                named.add(sid)

    def load(sid):
        return Image.open(os.path.join(sprites_dir, sprites[sid]["file"])).convert("RGBA")

    accepted, rejected = {}, {}
    hsv_acc = {"tan": [0.0, 0.0, 0.0, 0.0, 0], "green": [0.0, 0.0, 0.0, 0.0, 0]}
    for tan_id, green_id in sorted(pairs):
        if tan_id == green_id or tan_id in accepted:
            continue
        a, b = load(tan_id), load(green_id)
        if a.size != b.size:
            rejected[tan_id] = f"{green_id}: size {a.size} vs {b.size}"
            continue
        mapping = defaultdict(Counter)
        footprint_diff = changed = 0
        for pa, pb in zip(a.getdata(), b.getdata()):
            if (pa[3] == 0) != (pb[3] == 0):
                footprint_diff += 1
            elif pa[3] and pa != pb:
                changed += 1
                mapping[pa[:3]][pb[:3]] += 1
        opaque = sum(1 for px in a.getdata() if px[3])
        if opaque == 0 or footprint_diff > (0.3 if tan_id in named else 0.05) * opaque:
            rejected[tan_id] = f"{green_id}: footprints differ ({footprint_diff} of {opaque} px)"
            continue
        if changed == 0:
            rejected[tan_id] = f"{green_id}: identical, nothing team-coloured"
            continue
        consistency = sum(c.most_common(1)[0][1] for c in mapping.values()) / changed
        if consistency < TEAM_PAIR_MIN_CONSISTENCY:
            rejected[tan_id] = f"{green_id}: not a recolour (consistency {consistency:.2f})"
            continue
        accepted[tan_id] = green_id
        for pa, pb in zip(a.getdata(), b.getdata()):
            if pa[3] and pb[3] and pa != pb:
                for key, px in (("tan", pa), ("green", pb)):
                    h, s_, v = colorsys.rgb_to_hsv(px[0] / 255, px[1] / 255, px[2] / 255)
                    acc = hsv_acc[key]
                    acc[0] += math.cos(h * 2 * math.pi)
                    acc[1] += math.sin(h * 2 * math.pi)
                    acc[2] += s_
                    acc[3] += v
                    acc[4] += 1

    def mean(key):
        acc = hsv_acc[key]
        n = max(acc[4], 1)
        return [round((math.atan2(acc[1], acc[0]) / (2 * math.pi)) % 1.0, 4), round(acc[2] / n, 4), round(acc[3] / n, 4)]

    with open(os.path.join(sprites_dir, "team_sets.json"), "w") as f:
        # "masks" is for art with one drawing plus a team-paint mask (a mod's new vehicle; Pack.team_masks): none here.
        json.dump({"pairs": accepted, "rejected": rejected, "masks": {}}, f, indent=1, sort_keys=True)
        f.write("\n")
    colours = {"tan": {"source": "original", "variant": 0, "hsv": mean("tan")},
               "green": {"source": "original", "variant": 1, "hsv": mean("green")}}
    for name, hsv in TEAM_COLOUR_PRESETS.items():
        colours[name] = {"source": "port_preset", "hsv": hsv}
    os.makedirs(os.path.join(out_dir, "teams"), exist_ok=True)
    with open(os.path.join(out_dir, "teams", "colours.json"), "w") as f:
        json.dump({"reference": "tan", "colours": colours}, f, indent=1, sort_keys=True)
        f.write("\n")
    return len(accepted)


# The original four, in selector-bay order (runtime index = the original type number): id, the level's VHCL stock letter
# and the stock a level without one gets (document 73; A is the MSV), and the selector script name (document 78).
ORIGINAL_ROSTER = [("rf.tank", 0, "T", 3, "Tank"), ("rf.jeep", 1, "J", 8, "Jeep"), ("rf.msv", 2, "A", 3, "MSV"),
                   ("rf.heli", 3, "H", 3, "Heli")]
# The wreck drawn when a vehicle dies (document 87): Tank and Jeep share descriptor 0x43ece8 / 0x440218, the MSV's
# (0x43f628) has the same corner sizes and its own cels; the Heli's single part (0x440fa0) is off-centre. Each quad:
# sprites [tan, green] (or one), height above ground, half-size and centre in world units, and whether it is a shadow.
_SMALL = [{"sprites": ["effect.shadow.hard.wreck_small"], "height": 0.4, "half": [13.5, 13.5], "center": [0, 0], "shadow": True},
          {"sprites": ["vehicle.wreck.small.a.tan", "vehicle.wreck.small.a.green"], "height": 0.6, "half": [12, 12], "center": [0, 0]},
          {"sprites": ["vehicle.wreck.small.b.tan", "vehicle.wreck.small.b.green"], "height": 2.6, "half": [12, 12], "center": [0, 0]}]
WRECKS = {
    0: {"descriptor": "0x43ece8", "quads": _SMALL},
    1: {"descriptor": "0x440218", "quads": _SMALL},
    2: {"descriptor": "0x43f628", "quads": [
        {"sprites": ["effect.shadow.hard.wreck_large"], "height": 0.4, "half": [13.5, 13.5], "center": [0, 0], "shadow": True},
        {"sprites": ["vehicle.wreck.large.a.tan", "vehicle.wreck.large.a.green"], "height": 0.6, "half": [12, 12], "center": [0, 0]},
        {"sprites": ["vehicle.wreck.large.b.tan", "vehicle.wreck.large.b.green"], "height": 2.6, "half": [12, 12], "center": [0, 0]}]},
    3: {"descriptor": "0x440fa0", "quads": [
        {"sprites": ["vehicle.wreck.heli.tan", "vehicle.wreck.heli.green"], "height": 0.4, "half": [13.6, 27.2], "center": [0, 13.6]}]},
}


# The behaviour modules each original vehicle's record handlers became (game/vehicle_modules/, PORTING_PLAN.md 2.7.2 step
# 4). Only switches that differ from a module's traced defaults are listed; the modules hold the traced numbers.
BEHAVIOUR = {
    0: {"drive": {"model": "ground"}, "aim": {"model": "gun_mount", "params": {"turret": True}},
        "slots": [{"handler": "cannon"}], "water": {"model": "hull_water"}},
    1: {"drive": {"model": "ground", "params": {"turn_accelerates": True, "road_follow": True}}, "aim": {"model": "none"},
        "slots": [{"handler": "lobbed_missile"}], "water": {"model": "hull_water", "params": {"can_swim": True}},
        # FUN_00436640 / FUN_00436610 (document 54) test the vehicle type == 1 itself: bushes and rocks block the Jeep
        "terrain": {"blocked_by_bushes": True, "blocked_by_rocks": True},
        # only the Jeep picks up, carries and captures the flag (FUN_00432e40 / FUN_00432d80 / the flag update; documents 65, 54)
        "flags": {"carries_flag": True}},
    2: {"drive": {"model": "ground"}, "aim": {"model": "gun_mount", "params": {"turret": False}},
        "slots": [{"handler": "rocket_salvo"}, {"handler": "mine_layer"}], "water": {"model": "hull_water"}},
    3: {"drive": {"model": "rotor"}, "aim": {"model": "none"}, "slots": [{"handler": "heli_guns"}], "water": {"model": "none"}},
}


# FUN_0040f2f0 (document 98) picks a new vehicle's theme by its type: the Tank's depends on the flags (own flag carried or
# the other within 128 units: 2; stock 2: 0; else 0 / 1 by a random roll), the Heli's on its stock and a roll (8 / 9), every
# other type's is the record's own line. The definitions name the rule; game/music_director.gd implements the three.
MUSIC_THEME_RULE = {0: "flag_threat", 3: "stock_or_roll"}


def emit_vehicle_definitions(out_dir, vt, sound_dir):
    """PORTING_PLAN.md 2.7.2, step 3: one definition per vehicle, vehicles/<id>/vehicle.json, grouped the way the original's
    vehicle-type record is (stats, drive, weapons, shape, events, camera, render, wreck), plus vehicles/roster.json (the
    four in bay order, with their stock). Every number is the traced record's (tools/data/vehicle_types.json, from
    RFIRE.BIN via extract_vehicle_types.py); the record offset each came from is kept in "_record". A mod adds a vehicle by
    adding a definition, or changes one by giving the same id (Pack layers them per id)."""
    vdir = os.path.join(out_dir, "vehicles")
    os.makedirs(vdir, exist_ok=True)
    for old in os.listdir(vdir):   # stale definitions and the pre-definition table; projectile_types.json stays
        path = os.path.join(vdir, old)
        if os.path.isdir(path):
            shutil.rmtree(path)
        elif old in ("vehicle_types.json", "roster.json"):
            os.remove(path)
    # the engine loops (document 97): each vehicle's continuous sound, folded in as sounds.engine_loop; the samples join the pack
    loops_doc = json.load(open(ENGINE_LOOPS_JSON)) if os.path.exists(ENGINE_LOOPS_JSON) else {"loops": {}, "by_vehicle_type": []}
    audio_dir = os.path.join(out_dir, "audio")
    os.makedirs(audio_dir, exist_ok=True)
    if os.path.exists(os.path.join(audio_dir, "loops.json")):
        os.remove(os.path.join(audio_dir, "loops.json"))   # the pre-definition table; the definitions carry it now
    loop_by_descriptor = {l["descriptor"]: k for k, l in loops_doc["loops"].items()}
    for l in loops_doc["loops"].values():
        src = os.path.join(sound_dir, l["wav"])
        if os.path.exists(src):
            shutil.copyfile(src, os.path.join(audio_dir, l["wav"]))
    roster = []
    for vid, index, stock_key, default_stock, script in ORIGINAL_ROSTER:
        t = vt[str(index)]
        created = t.get("created_sound")
        on_create = {"sound": created["cue"], "descriptor": created["descriptor"]} if created else {"sound": None}
        if created and created["cue"] is None:
            if created["descriptor"] in loop_by_descriptor:
                # document 97: the Tank's and MSV's +0x240 descriptor is Tread.SDT, their engine loop -- started as sounds.engine_loop
                on_create["loop"] = loop_by_descriptor[created["descriptor"]]
            else:
                on_create["_untraced"] = "descriptor %s is not one of the traced sound cues (NEXT_STEPS)" % created["descriptor"]
        loop_key = loops_doc["by_vehicle_type"][index] if index < len(loops_doc["by_vehicle_type"]) else None
        sounds = {"engine_loop": {"id": loop_key, **loops_doc["loops"][loop_key]}} if loop_key else {}
        render = {"parts": t["parts"]}
        for extra in ("swim", "rack"):
            if extra in t:
                render[extra] = t[extra]
        d = {
            "id": vid, "name": t["name"], "original_index": index,
            "_source": "RFIRE.BIN vehicle-type record 0x%x (0x4456b8 + %d * 0x2e8), document 57 and on" % (0x4456B8 + index * 0x2E8, index),
            "stats": {"hit_points": t["hit_points"], "armor": t["armor"], "fuel": t["fuel"], "sink_depth": t["sink_depth"],
                      "dock_tolerance": t["dock_tolerance"], "death_wait_ticks": t["death_wait_ticks"]},
            "drive": {**{k: t[k] for k in ("max_forward_per_tick", "max_reverse_per_tick", "accel_per_tick2",
                                           "friction_per_tick2", "turn_steps_per_tick")}, **BEHAVIOUR[index]["drive"]},
            "aim": BEHAVIOUR[index]["aim"],
            "weapons": {"ammo": t["ammo"], "cooldown_ticks": t["weapon_cooldown_ticks"], "slots": BEHAVIOUR[index]["slots"]},
            "water": BEHAVIOUR[index]["water"],
            "terrain": BEHAVIOUR[index].get("terrain", {"blocked_by_bushes": False, "blocked_by_rocks": False}),
            "flags": BEHAVIOUR[index].get("flags", {"carries_flag": False}),
            "shape": t["shape"],
            "events": {"on_create": on_create},
            "sounds": sounds,
            "camera": {"swoop_height": t.get("camera_swoop_height")},
            # the music director (document 98): the theme a new vehicle asks for (record +0x2bc, priority +0x2bd), the line its
            # death plays (table 0x4466e4), and which of FUN_0040f2f0's three rules picks its theme when it is (re)created
            "music": {"theme_line": t.get("music_theme_line"), "priority": t.get("music_priority"),
                      "death_line": t.get("music_death_line"), "theme_rule": MUSIC_THEME_RULE.get(index, "record_line")},
            "selector": {"script": script},
            "render": render,
            "wreck": WRECKS[index],
            "_record": {"stats.hit_points": "+0x28", "stats.armor": "+0x24", "stats.fuel": "+0x210",
                        "stats.sink_depth": "+0x158", "stats.dock_tolerance": "+0x254", "stats.death_wait_ticks": "+0x260",
                        "drive": "+0x168..+0x178", "weapons.ammo": "+0x1a8 / +0x1dc", "weapons.cooldown_ticks": "+0x1a4 / +0x1d8",
                        "events.on_create": "+0x240", "camera.swoop_height": "table 0x4452c0", "render": "+0x148 (draw descriptor)"},
        }
        os.makedirs(os.path.join(vdir, vid))
        with open(os.path.join(vdir, vid, "vehicle.json"), "w") as f:
            json.dump(d, f, indent=1, sort_keys=True)
            f.write("\n")
        roster.append({"id": vid, "stock_key": stock_key, "default_stock": default_stock})
    with open(os.path.join(vdir, "roster.json"), "w") as f:
        json.dump({"vehicles": roster}, f, indent=1)
        f.write("\n")


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
    ap.add_argument("--build-sound-dir", default=DEFAULT_BUILD_SOUND,
                     help="dir with convert_sdt.py output, *.wav (default: build/sound)")
    args = ap.parse_args()

    with open(os.path.join(args.build_car_dir, "art_atlas.json")) as f:
        atlas = json.load(f)
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)["cels"]

    cels = {c["index"]: c for c in atlas["cels"]}
    all_cels = cels   # `cels` is reused for the selector's own cel table further down
    missing = [idx for idx in cels if str(idx) not in registry]
    if missing:
        raise SystemExit(f"{len(missing)} cels have no registry entry (run tools/registry/validate_registry.py); "
                          f"first few: {missing[:10]}")

    sprites_dir = os.path.join(args.out_dir, "sprites")
    terrain_dir = os.path.join(args.out_dir, "terrain")
    os.makedirs(sprites_dir, exist_ok=True)
    os.makedirs(terrain_dir, exist_ok=True)

    # Loose frames replace the shipped atlas pages: clear the old layout first so a stale page can't linger.
    for old in os.listdir(sprites_dir):
        path = os.path.join(sprites_dir, old)
        if os.path.isdir(path):
            shutil.rmtree(path)
        elif old.endswith(".png"):
            os.remove(path)
    atlas_images = [Image.open(os.path.join(args.build_car_dir, name)).convert("RGBA")
                    for name in ("art_atlas.png", "art_effects.png")]

    sprites = {}
    for idx, c in cels.items():
        reg_id = registry[str(idx)]["id"]
        if reg_id in sprites:
            raise SystemExit(f"duplicate registry id {reg_id!r} (cel {idx} and an earlier one) -- "
                              f"registry should be unique, this is a bug upstream, not here")
        page = 0 if c["kind"] == "sprite" else 1
        rel = sprite_file(reg_id)
        frame = atlas_images[page].crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
        os.makedirs(os.path.join(sprites_dir, os.path.dirname(rel)), exist_ok=True)
        frame.save(os.path.join(sprites_dir, rel))
        sprites[reg_id] = {
            "file": rel,
            "w": c["w"], "h": c["h"],
            "pivot_x": round(c["w"] / 2, 1), "pivot_y": round(c["h"] / 2, 1),
            "pivot_source": "default_center",
            "kind": "sprite" if page == 0 else "effect",
        }

    sprites_json = {
        "atlas_pages": [],
        "sprites": sprites,
    }
    # Team pairs (tan cel, green cel) found while resolving flag-8 parts below; checked and written by
    # emit_team_colours() at the end (PORTING_PLAN.md 2.7.7).
    team_pairs = set()
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
    # The home pads are team-owned tiles: art HOME_ART_BASE + player index, 90 tan / 91 green (documents 77, 80).
    # `side` lets the tile renderer draw them in that side's colour (PORTING_PLAN.md 2.7.7).
    for side, art_id in enumerate((90, 91)):
        if str(art_id) in tileset:
            tileset[str(art_id)]["side"] = side
            team_pairs.add((90, 91))
    with open(os.path.join(terrain_dir, "tileset.json"), "w") as f:
        json.dump({"tile_size_px": 32, "tiles": tileset}, f, indent=2, sort_keys=True)
        f.write("\n")

    # Coastal decorations (document 35, docs/process/): resolve each known coastal id's real
    # ART.CAR cel indices into sprite ids, same lookup terrain/tileset.json already does above.
    # tools/data/coastal_decorations.json is itself incomplete (3 of 91 ids unresolved, see its
    # own "_missing" field) -- an id missing here just means no decoration for that id yet, not
    # an error; game/pack.gd is written to treat an unknown id exactly like a "no decoration"
    # entry, not a load failure.
    n_decoration_ids = 0
    if os.path.exists(COASTAL_DECORATIONS_JSON):
        with open(COASTAL_DECORATIONS_JSON) as f:
            coastal_decorations = json.load(f)["decorations"]
        # Document 44: real per-part quad corners (world units, tile = 32) for every part of every
        # chained sub-object, from tools/data/coastal_decoration_corners.json. Ids it covers use
        # ONLY that data (it is a superset of coastal_decorations.json's link-0 list); ids it
        # doesn't cover fall back to the older cel/flags-only list (no geometry, so not drawn).
        corner_doc = {}
        if os.path.exists(COASTAL_DECORATION_CORNERS_JSON):
            with open(COASTAL_DECORATION_CORNERS_JSON) as f:
                corner_doc = json.load(f)["decorations"]
        decoration_types = {}
        for coastal_id in sorted(set(coastal_decorations) | set(corner_doc), key=int):
            parts = coastal_decorations.get(coastal_id, [])
            resolved_parts = []
            if coastal_id in corner_doc:
                for part in corner_doc[coastal_id]:
                    if part["cel"] not in cels:
                        continue
                    entry = {
                        "sprite_id": registry[str(part["cel"])]["id"],
                        "flags": part["flags"],
                        "corners": part["corners"],
                        "offset": part["offset"],
                        "zoff": part.get("zoff", 0.0),
                        "jitter": part.get("jitter", False),
                    }
                    if part["flags"] & 8:
                        # Flag bit 3: the part's cel is shifted by the tile's variant (0..3) at
                        # draw time -- pre-resolve those 4 cels to sprite ids (None if absent).
                        entry["variant_sprite_ids"] = [
                            registry[str(part["cel"] + v)]["id"] if (part["cel"] + v) in cels else None
                            for v in range(4)]
                        team_pairs.add((part["cel"], part["cel"] + 1))
                    resolved_parts.append(entry)
            else:
                for part in parts:
                    if part["cel"] not in cels:
                        continue  # a cel index this build's ART.CAR atlas doesn't have -- skip it
                    resolved_parts.append({
                        "sprite_id": registry[str(part["cel"])]["id"],
                        "flags": part["flags"],
                    })
            if resolved_parts:
                decoration_types[coastal_id] = resolved_parts
        with open(os.path.join(terrain_dir, "decorations.json"), "w") as f:
            json.dump({"decoration_types": decoration_types}, f, indent=2, sort_keys=True)
            f.write("\n")
        n_decoration_ids = len(decoration_types)

    # Document 44: per-coastal-id hit points and destroyed-state chain (e.g. a candidate building
    # 22 -> 62 -> 63), consumed by game/pack.gd's get_coastal_damage().
    if os.path.exists(COASTAL_DAMAGE_JSON):
        with open(COASTAL_DAMAGE_JSON) as f:
            damage = json.load(f)["coastal"]
        with open(os.path.join(terrain_dir, "coastal_damage.json"), "w") as f:
            json.dump({"coastal": damage}, f, indent=1, sort_keys=True)
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

    # Vehicle types (document 57): stats and collision shape, and each part with its sprite ids (tan, green).
    if os.path.exists(VEHICLE_TYPES_JSON):
        with open(VEHICLE_TYPES_JSON) as f:
            vt = json.load(f)["types"]
        for t in vt.values():
            if "swim" in t:
                t["swim"]["ring_sprite"] = registry[str(t["swim"]["ring_cel"])]["id"]
            for part in t["parts"]:
                n = 3 if part["flags"] & 8 else 1  # tan, green, and variant 2 = the hit flash (document 59)
                part["sprite_ids"] = [registry[str(part["cel"] + v)]["id"] for v in range(n)]
                if part["flags"] & 8:
                    team_pairs.add((part["cel"], part["cel"] + 1))
        emit_vehicle_definitions(args.out_dir, vt, args.build_sound_dir)

    # Projectile types and their draw descriptors (documents 46, 58); parts carry sprite ids (flag 8: + team).
    if os.path.exists(PROJECTILE_TYPES_JSON):
        with open(PROJECTILE_TYPES_JSON) as f:
            pj = json.load(f)
        for parts in pj["descriptors"].values():
            for part in parts:
                n = 2 if part["flags"] & 8 else 1
                part["sprite_ids"] = [registry[str(part["cel"] + v)]["id"] for v in range(n)]
                if part["flags"] & 8:
                    team_pairs.add((part["cel"], part["cel"] + 1))
        os.makedirs(os.path.join(args.out_dir, "vehicles"), exist_ok=True)
        with open(os.path.join(args.out_dir, "vehicles", "projectile_types.json"), "w") as f:
            json.dump({"types": pj["types"], "descriptors": pj["descriptors"]}, f)

    # The capture flag (document 65): sprite ids per wave frame (13 tan, then 13 green)
    if os.path.exists(FLAG_JSON):
        with open(FLAG_JSON) as f:
            fl = json.load(f)
        for group in ("ground", "carried"):
            for part in fl[group].values():
                n = 1 if part["cel"] == 1881 else 26
                part["sprite_ids"] = [registry[str(part["cel"] + i)]["id"] for i in range(n)]
                if n == 26:
                    team_pairs.update((part["cel"] + i, part["cel"] + 13 + i) for i in range(13))
        os.makedirs(os.path.join(args.out_dir, "markers"), exist_ok=True)
        with open(os.path.join(args.out_dir, "markers", "flag.json"), "w") as f:
            json.dump(fl, f)

    # The game's runtime palette (document 20: runtime[10 + i] = shared_plut[i], slots 0-9 black), for the mod tool's
    # "original palette" swatches (EDITOR_PLAN.md 3.1). An aid, not a restriction: the port draws full-colour RGBA.
    if os.path.exists(GAME_ART_CAR):
        car = open(GAME_ART_CAR, "rb").read()
        palette = [[0, 0, 0] if k < 10 else [car[0x282CC + (k - 10) * 4 + 2], car[0x282CC + (k - 10) * 4 + 1],
                                            car[0x282CC + (k - 10) * 4]] for k in range(256)]
        with open(os.path.join(sprites_dir, "palette.json"), "w") as f:
            json.dump({"_source": "ART.CAR shared PLUT at 0x282CC, offset to slot 10 (document 20)", "rgb": palette}, f)
            f.write("\n")

    # The radar's colours (document 69): the palette indices of tools/data/radar.json as RGB. The runtime palette is
    # runtime[10 + i] = shared_plut[i] (convert_car.py), the shared PLUT being at 0x282CC of ART.CAR.
    if os.path.exists(RADAR_JSON) and os.path.exists(GAME_ART_CAR):
        with open(RADAR_JSON) as f:
            rd = json.load(f)
        car = open(GAME_ART_CAR, "rb").read()

        def rgb(k):
            o = 0x282CC + (k - 10) * 4
            return [car[o + 2], car[o + 1], car[o]] if k >= 10 else [0, 0, 0]
        used = {rd["land"], rd["water"], rd["flagged_tile"], *rd["flag_blip"]["colours"],
                *[c for v in rd["coastal_colours"].values() for c in v]}
        rd["rgb"] = {str(k): rgb(k) for k in used}
        os.makedirs(os.path.join(args.out_dir, "hud"), exist_ok=True)
        with open(os.path.join(args.out_dir, "hud", "radar.json"), "w") as f:
            json.dump(rd, f)

    # The HUD panels of the four vehicles (document 70): layouts plus the sprite id of each base cel
    if os.path.exists(HUD_PANELS_JSON):
        with open(HUD_PANELS_JSON) as f:
            hp = json.load(f)
        for pn in hp["panels"].values():
            pn["sprite_id"] = registry[str(pn["base_cel"])]["id"]
        # The bars are drawn in mode 10 (FUN_00418ef0 case 10): the word at PLUTPtr + 2 is 15-bit RGB, turned into the NEAREST entry of the
        # game's palette by GetNearestPaletteIndex (document 74). The runtime palette is slots 0-9 black, then the shared PLUT (0x282CC).
        if os.path.exists(GAME_ART_CAR):
            car_bytes = open(GAME_ART_CAR, "rb").read()
            runtime = [(0, 0, 0)] * 10 + [(car_bytes[0x282CC + 4 * i + 2], car_bytes[0x282CC + 4 * i + 1], car_bytes[0x282CC + 4 * i])
                                          for i in range(246)]

            def nearest(word):
                r, g, b = ((word >> 10) & 31) * 255 // 31, ((word >> 5) & 31) * 255 // 31, (word & 31) * 255 // 31
                r, g, b = (word >> 7) & 0xF8, (word >> 2) & 0xF8, (word << 3) & 0xF8   # the game's own conversion (0xf8 masks)
                return list(min(runtime, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2))
            hp["fuel_rgb"] = {k: nearest(v) for k, v in hp["fuel_colour_words"].items()}
            hp["ammo_rgb"] = {k: nearest(v) for k, v in hp["ammo_colour_words"].items()}
        hp["select"]["icon_ids"] = [registry[str(c)]["id"] for c in hp["select"]["icon_cels"]]
        hp["select"]["digit_ids"] = [registry[str(hp["select"]["digit_base_cel"] + i)]["id"] for i in range(10)]
        hp["pips"]["sprite_id"] = registry[str(hp["pips"]["cel"])]["id"]
        for k in ("flag_cel", "home_cel"):
            hp["compass"][k.replace("_cel", "_sprite_id")] = registry[str(hp["compass"][k])]["id"]
        if "weapon_select" in hp:
            hp["weapon_select"]["sprite_ids"] = {k: registry[str(c)]["id"] for k, c in hp["weapon_select"]["cels"].items()}
        os.makedirs(os.path.join(args.out_dir, "hud"), exist_ok=True)
        with open(os.path.join(args.out_dir, "hud", "panels.json"), "w") as f:
            json.dump(hp, f)

    # The docked vehicle-choice screen (document 78): layout data plus the sprite id of every cel it draws
    if os.path.exists(SELECTOR_JSON):
        with open(SELECTOR_JSON) as f:
            sel = json.load(f)
        # Every cel the screen draws, as sprite ids -- the original's cel arithmetic (picture_base + type * 2 + team,
        # pointer + frame, strip / cloud / dirt + rand, digit_base + digit) expanded into explicit lists here, so the
        # runtime (and a replacement pack) never computes an id from a number (PORTING_PLAN.md 2.7.5).
        cels = sel["cels"]
        rid = lambda c: registry[str(c)]["id"] if c else ""
        team_pairs.update((cels["picture_base"] + t * 2, cels["picture_base"] + t * 2 + 1) for t in range(4))   # traced pairs
        sel["sprites"] = {
            **{k: rid(cels[k]) for k in ("box", "highlight", "platform_cap", "platform_body", "strip_centre",
                                          "map_frame", "radar", "panel_frame", "panel_interior")},
            "hangar": rid(sel["hangar"]["cel"]),
            "pictures": [[rid(cels["picture_base"] + t * 2 + team) for team in (0, 1)] for t in range(4)],
            "pointer": [rid(cels["pointer"] + i) for i in range(3)],
            "strip": [rid(cels["strip"][0] + i) for i in range(2)],
            "cloud": [rid(cels["cloud"] + i) for i in range(3)],
            "dirt": [rid(cels["dirt"] + i) for i in range(4)],
            "digits": [rid(cels["digit_base"] + i) for i in range(10)],
            "icon": [rid(c) for c in cels["icon"]],
            "weapon_icon": [rid(c) for c in cels["weapon_icon"]],
            "second_icon": [rid(c) for c in cels["second_icon"]],
        }
        os.makedirs(os.path.join(args.out_dir, "hud"), exist_ok=True)
        with open(os.path.join(args.out_dir, "hud", "selector.json"), "w") as f:
            json.dump(sel, f)

    # Water classification tables (document 62)
    if os.path.exists(WATER_JSON):
        shutil.copyfile(WATER_JSON, os.path.join(terrain_dir, "water.json"))

    # Team gates (document 56): parts with their sprite ids resolved (flag 8 = +variant), for game/gate.gd.
    if os.path.exists(GATES_JSON):
        with open(GATES_JSON) as f:
            gj = json.load(f)["gates"]
        for gid, g in gj.items():
            for d in g["descs"]:
                for part in d["parts"]:
                    n = 2 if part["flags"] & 8 else 1
                    part["sprite_ids"] = [registry[str(part["cel"] + v)]["id"] for v in range(n)]
                    if part["flags"] & 8:
                        team_pairs.add((part["cel"], part["cel"] + 1))
                d["sprite_open"] = registry[str(d["cel_open"])]["id"]
                d["sprite_closed"] = registry[str(d["cel_closed"])]["id"]
        with open(os.path.join(terrain_dir, "gates.json"), "w") as f:
            json.dump({"gates": gj}, f)

    # Sound cues (document 82): copies the already-converted .wav files (tools/convert_sdt.py output) into
    # the pack's own audio/ dir and writes audio.json (PORTING_PLAN.md section 2.4.2's id -> {file, ...}
    # schema), sourced from tools/data/sound_cues.json's traced descriptor -> filename mapping. Only cues
    # with a real .wav on disk are included; a cue whose file didn't convert is silently skipped here (the
    # traced data stays in tools/data/sound_cues.json regardless).
    n_audio = 0
    if os.path.exists(SOUND_CUES_JSON) and os.path.isdir(args.build_sound_dir):
        with open(SOUND_CUES_JSON) as f:
            sound_cues = json.load(f)["cues"]
        audio_dir = os.path.join(args.out_dir, "audio")
        os.makedirs(audio_dir, exist_ok=True)
        audio_json = {}
        copied = set()
        for cue_id, cue in sound_cues.items():
            wav = cue["wav"]
            src = os.path.join(args.build_sound_dir, wav)
            if not os.path.exists(src):
                continue
            if wav not in copied:
                shutil.copyfile(src, os.path.join(audio_dir, wav))
                copied.add(wav)
            audio_json[cue_id] = {"file": wav, "category": "sfx", "priority": 0}
            n_audio += 1
        with open(os.path.join(audio_dir, "audio.json"), "w") as f:
            json.dump(audio_json, f)

    # Collision shapes of each coastal id's tile (document 53), consumed by game/pack.gd's get_coastal_shapes().
    if os.path.exists(COASTAL_SHAPES_JSON):
        with open(COASTAL_SHAPES_JSON) as f:
            cs = json.load(f)
        with open(os.path.join(terrain_dir, "coastal_shapes.json"), "w") as f:
            json.dump(cs, f)

    # Explosion records (document 50/51): per record its scale/rate/duration and parts with the frame sprite
    # ids (cel + 0 .. end - start) resolved through the registry, plus the coastal-id -> destroy-effect map
    # and the projectile surface tables. Consumed by game/pack.gd's get_explosion().
    if os.path.exists(EXPLOSION_RECORDS_JSON):
        with open(EXPLOSION_RECORDS_JSON) as f:
            ex = json.load(f)
        records = {}
        by_coastal = {}
        by_coastal_crush = {}
        for addr, r in ex["records"].items():
            parts = []
            for part in r["parts"]:
                frames = []
                for k in range(part["end"] - part["start"] + 1):
                    entry = registry.get(str(part["cel"] + k))
                    frames.append(entry["id"] if entry else "")
                parts.append({"start": part["start"], "end": part["end"], "fade": part["fade"],
                              "variant_mode": part["variant_mode"], "corners": part["corners"], "frames": frames})
            records[addr] = {"duration": r["duration"], "rate_per_tick": r["rate_per_tick"], "scale": r["scale"],
                             "parts": parts, "script": r["script"]}
            for cid in r["coastal_destroy_effect_ids"]:
                by_coastal[str(cid)] = addr
            for cid in r["coastal_field10_ids"]:
                by_coastal_crush[str(cid)] = addr
        os.makedirs(os.path.join(args.out_dir, "effects"), exist_ok=True)
        with open(os.path.join(args.out_dir, "effects", "explosions.json"), "w") as f:
            json.dump({"records": records, "coastal_destroy_effect": by_coastal, "coastal_crush_effect": by_coastal_crush,
                       "impact_tables": ex["impact_tables"]}, f)

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

    n_team = emit_team_colours(args.out_dir, sprites_dir, sprites, registry, all_cels, team_pairs)

    print(f"wrote pack {PACK_ID!r} to {args.out_dir}: {len(sprites)} sprites ({n_team} team-recolourable), "
          f"{len(tileset)} terrain tiles, {n_decoration_ids} decoration types, {n_levels} levels, "
          f"{n_audio} audio cues")


if __name__ == "__main__":
    main()
