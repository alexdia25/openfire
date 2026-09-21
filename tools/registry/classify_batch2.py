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


# AUDIT 2026-09-20 (registry hand-edited, not re-generated; document 46): every vehicle part in the
# type descriptors (tools/data/vehicle_type_parts.json) is a group of 5 consecutive cels starting at
# the descriptor's cel: +0 tan, +1 green (the same shape, verified by identical size and pixel count),
# +2 a smaller "yellow" version (purpose untraced), +3/+4 two more variant slots (debris pieces for
# the Tank/MSV/Jeep, purpose untraced; unclear for the Heli). Descriptor flag 0x8 shifts the cel by the variant. The
# registry had scattered these across prop/effect/character/ui families. Tank slots 0/1 keep their
# names (game/vehicle_box_3d.gd looks them up by name); every other non-blank slot is renamed.
# MSV 324 (1/2/3 blue canisters) and Jeep 457 (5 same-size frames) are not team groups.
VEHICLE_PART_GROUPS = {
    "hovercraft": [167, 172, 177, 182, 187, 192, 197, 202, 207, 212],
    "jeep": [417, 422, 427, 432, 437, 442, 447, 452],
    "msv": [279, 284, 289, 294, 299, 304, 309, 314, 319],
    "heli": [524, 529, 534, 539, 544, 549, 554, 559, 564, 569, 574],
}
VEHICLE_SLOTS = ["tan", "green", "yellow", "alt3", "alt4"]
BLANK_SLOTS = {(177, 3), (177, 4), (182, 3), (182, 4), (187, 3), (187, 4), (192, 3), (192, 4),
               (197, 3), (197, 4), (207, 3), (207, 4), (417, 2), (417, 3), (417, 4),
               (432, 3), (432, 4), (437, 3), (437, 4), (442, 3), (442, 4), (452, 3), (452, 4),
               (289, 3), (289, 4), (294, 3), (294, 4), (299, 3), (299, 4), (549, 3), (549, 4)}
for _type, _cels in VEHICLE_PART_GROUPS.items():
    for _c in _cels:
        for _k, _slot in enumerate(VEHICLE_SLOTS):
            if (_c, _k) in BLANK_SLOTS or (_type == "hovercraft" and _k < 2):
                continue
            put(_c + _k, f"vehicle.{_type}.p{_c}.{_slot}", "vehicle",
                "vehicle part variant group (document 46): " + ("code-verified part cel" if _k == 0
                else f"slot {_k} of the group starting at cel {_c}"),
                "code_verified" if _k == 0 else "visual")
for _n, _c in enumerate([324, 325, 326], start=1):
    put(_c, f"vehicle.msv.p324.canisters_{_n}", "vehicle", "1/2/3 blue canisters on the MSV (document 46)", "visual")
for _n, _c in enumerate(range(457, 462), start=1):
    put(_c, f"vehicle.jeep.p457.frame_{_n:02d}", "vehicle", "five same-size frames; Jeep parts 9/10 (document 46)", "visual" if _c > 457 else "code_verified")


# AUDIT 2026-09-20, part 2 (registry hand-edited, not re-generated; document 46): names for cels the
# audit identified by their code owner or by a flat composite of the coastal decorations that use them.
AUDIT2 = [
    # (cel, id, category, note, confidence)
    (157, "decoration.rock_grey.01", "decoration", "small grey rock (coastal id 8)", "code_verified"),
    (158, "decoration.rock_grey.02", "decoration", "grey rock (coastal ids 7, 8)", "code_verified"),
    (159, "decoration.rock_shallows.01", "decoration", "rock with cyan surf ring (coastal id 10)", "code_verified"),
    (160, "decoration.rock_shallows.02", "decoration", "rock with cyan surf ring (coastal ids 9, 10)", "code_verified"),
    (123, "decoration.flowers_red.01", "decoration", "scatter of red flowers (coastal id 12)", "code_verified"),
    (124, "decoration.pebble.01", "decoration", "single pebble (coastal id 13)", "code_verified"),
    (161, "decoration.dock_planks.01", "decoration", "wooden dock planks, vertical (coastal id 74)", "code_verified"),
    (162, "decoration.dock_planks.02", "decoration", "wooden dock planks, horizontal (coastal id 75)", "code_verified"),
    (1882, "decoration.wreckage.01", "decoration", "destroyed-building debris, tan (coastal id 73; +1 is the green variant)", "code_verified"),
    (1883, "decoration.wreckage.02", "decoration", "destroyed-building debris, green variant of 1882", "visual"),
    (1884, "decoration.wreckage.03", "decoration", "destroyed-building debris, tan (coastal id 53; +1 is the green variant)", "code_verified"),
    (1885, "decoration.wreckage.04", "decoration", "destroyed-building debris, green variant of 1884", "visual"),
    (1886, "decoration.wreckage.05", "decoration", "destroyed-building debris (coastal id 51)", "code_verified"),
    (1887, "decoration.wreckage.06", "decoration", "destroyed-building debris, variant of 1886", "visual"),
    # Projectile art: the 12 projectile types at 0x4489a0 point (entry+0x2c) at ordinary draw descriptors.
    (1075, "projectile.shell.01", "projectile", "Tank shell body, 4x4 units (types 0, 7, 11)", "code_verified"),
    (1066, "projectile.rocket_blue.01", "projectile", "blue rocket body 4x8 units (types 2, 8, 9)", "code_verified"),
    (1067, "projectile.rocket_blue.02", "projectile", "blue rocket, brighter variant of 1066", "visual"),
    (1069, "projectile.rocket_red.01", "projectile", "red rocket body (types 1, 3, 4, 5, 6)", "code_verified"),
    (1070, "projectile.rocket_red.02", "projectile", "red rocket, brighter variant of 1069", "visual"),
    (1072, "projectile.rocket_orange.01", "projectile", "large orange rocket (type 10, damage 400)", "code_verified"),
    (1073, "projectile.rocket_orange.02", "projectile", "orange rocket, brighter variant of 1072", "visual"),
    (1077, "projectile.trail.01", "projectile", "exhaust flame drawn behind rockets; flag 0x8 = variant shifted (types 1-4, 6, 8-10)", "code_verified"),
    (1078, "projectile.trail.02", "projectile", "rocket exhaust flame, variant of 1077", "visual"),
    (1079, "projectile.trail.03", "projectile", "rocket exhaust flame, variant of 1077", "visual"),
    (1080, "projectile.trail.04", "projectile", "rocket exhaust flame, variant of 1077", "visual"),
    (1068, "effect.shadow.hard.projectile_blue", "effect", "ground shadow of the blue rocket (types 2, 8, 9)", "code_verified"),
    (1071, "effect.shadow.hard.projectile_red", "effect", "ground shadow of the red rocket (types 1, 3, 4, 5, 6)", "code_verified"),
    (1074, "effect.shadow.hard.projectile_orange", "effect", "ground shadow of the orange rocket (type 10)", "code_verified"),
    (1076, "effect.shadow.hard.projectile_shell", "effect", "ground shadow of the shell (types 0, 7, 11)", "code_verified"),
    (1081, "effect.ember_small.01", "effect", "small dark ember/dot, 8x8 (was marker.checkered_flag)", "visual"),
    (1082, "effect.ember_small.02", "effect", "small dark ember with red centre, 8x8", "visual"),
    (1083, "effect.ember_small.03", "effect", "small dark ember with red centre, 8x8", "visual"),
]
for _cel, _id, _cat, _note, _conf in AUDIT2:
    put(_cel, _id, _cat, _note, _conf)


# AUDIT 2026-09-20, part 3 (registry hand-edited, not re-generated; document 48): owners found by
# scanning RFIRE.BIN for every draw descriptor (tools/ghidra_scripts/ScanDescriptors.java) and by the
# vehicle class's wreck object (class 0x4453e8 switches to the type record's +0x164 descriptor).
AUDIT3 = [
    (274, "effect.shadow.hard.wreck_small", "effect", "wreck ground shadow, Tank and Jeep (descriptors 0x43ece8, 0x440218)", "code_verified"),
    (275, "vehicle.wreck.small.a.tan", "vehicle", "Tank/Jeep wreck decal, ground level, 24x24 units (flag 0x8: +1 green)", "code_verified"),
    (276, "vehicle.wreck.small.a.green", "vehicle", "green variant of 275", "visual"),
    (277, "vehicle.wreck.small.b.tan", "vehicle", "Tank/Jeep wreck debris decal, 2 units above the ground (+1 green)", "code_verified"),
    (278, "vehicle.wreck.small.b.green", "vehicle", "green variant of 277", "visual"),
    (412, "effect.shadow.hard.wreck_large", "effect", "MSV wreck ground shadow (descriptor 0x43f628)", "code_verified"),
    (413, "vehicle.wreck.large.a.tan", "vehicle", "MSV wreck decal (+1 green)", "code_verified"),
    (414, "vehicle.wreck.large.a.green", "vehicle", "green variant of 413", "visual"),
    (415, "vehicle.wreck.large.b.tan", "vehicle", "MSV wreck debris decal (+1 green)", "code_verified"),
    (416, "vehicle.wreck.large.b.green", "vehicle", "green variant of 415", "visual"),
    (606, "vehicle.wreck.heli.tan", "vehicle", "Heli wreck debris (descriptor 0x440fa0, flag 0x8: +1 green)", "code_verified"),
    (607, "vehicle.wreck.heli.green", "vehicle", "green variant of 606", "visual"),
    (580, "vehicle.heli.rotor.a.tan", "vehicle", "Heli rotor blade, chained sub-object 0x440708 of the Heli descriptor (+1 green)", "code_verified"),
    (581, "vehicle.heli.rotor.a.green", "vehicle", "green variant of 580", "visual"),
    (584, "vehicle.heli.rotor.b.tan", "vehicle", "Heli rotor blade, sub-object 0x440708 (+1 green)", "code_verified"),
    (585, "vehicle.heli.rotor.b.green", "vehicle", "green variant of 584", "visual"),
    (588, "vehicle.heli.rotor.c", "vehicle", "Heli rotor part (descriptors 0x4406c0, 0x440708)", "code_verified"),
    (579, "effect.shadow.hard.heli_body", "effect", "Heli ground shadow (descriptors 0x440e90, 0x440ed8)", "code_verified"),
    (1881, "marker.capture_flag_base.01", "marker", "part of the capture-flag object (descriptor 0x440448, with cel 1829)", "code_verified"),
]
for _cel, _id, _cat, _note, _conf in AUDIT3:
    put(_cel, _id, _cat, _note, _conf)


# AUDIT 2026-09-20, part 4 (registry hand-edited, not re-generated; document 49): cels 1084-1739 are
# animation clips, found as animated parts in the draw descriptors (tools/data/effect_animations.json).
# The old effect.burst_red/brown/green names were colour guesses that cut across clips. Blank cels stay
# reserved.blank.
EFFECT_ANIM_CLIPS = {
    1084: "explosion_smoke_column",
    1109: "fireball_smoke",
    1123: "smoke_puff",
    1139: "flame_burst",
    1159: "smoke_wisp",
    1172: "explosion_large",
    1197: "fireball_ring",
    1210: "explosion_fireball",
    1251: "flame_column",
    1275: "explosion_dust",
    1291: "smoke_and_flames",
    1380: "explosion_big",
    1416: "explosion_medium",
    1436: "explosion_small",
    1452: "explosion_spark",
    1468: "explosion_spark_b",
    1484: "explosion_flash",
    1504: "explosion_flash_b",
    1523: "debris_chunks",
    1529: "smoke_puffs",
    1537: "water_ring",
    1555: "water_ring_small",
    1565: "water_splash",
    1580: "sand_explosion",
    1598: "sand_puff",
    1612: "sand_puff_b",
    1626: "sand_puff_c",
    1640: "sand_puff_d",
    1654: "grey_explosion",
    1672: "smoke_puff_a",
    1686: "smoke_puff_b",
    1700: "smoke_puff_c",
    1714: "smoke_puff_d",
}
EFFECT_ANIM_BLANK = {1122, 1138, 1171, 1221, 1240, 1250, 1303, 1364, 1379, 1415, 1435, 1436, 1451, 1467, 1483, 1522, 1536, 1564, 1611, 1625, 1638, 1639, 1652, 1653, 1685, 1699, 1712, 1713, 1726, 1727}
_starts = sorted(EFFECT_ANIM_CLIPS)
for _i, _st in enumerate(_starts):
    _nx = _starts[_i + 1] if _i + 1 < len(_starts) else 1740
    for _c in range(_st, _nx):
        if _c in EFFECT_ANIM_BLANK:
            continue
        put(_c, f"effect.anim.{EFFECT_ANIM_CLIPS[_st]}.{_c - _st:02d}", "effect", "animation frame (document 49)", "code_verified" if _c == _st else "visual")


# AUDIT 2026-09-20, part 5 (registry hand-edited, not re-generated; document 56): the cels of the team gate
# objects (coastal ids 43/44, class 0x44e370): parts of their draw descriptors 0x44d160 / 0x44d628.
AUDIT5 = [
    (853, "structure.gate.frame_a", "structure", "gate frame strip (descriptor part cel 0x355)", "code_verified"),
    (854, "structure.gate.frame_b", "structure", "gate frame strip (part cel 0x356)", "code_verified"),
    (856, "structure.gate.wall", "structure", "gate wall face with a doorway (part cel 0x358)", "code_verified"),
    (857, "structure.gate.light_off", "structure", "gate door face while closed (part cel 0x359, swapped for 0x35a when open)", "code_verified"),
    (858, "structure.gate.light_on", "structure", "gate door face while open (cel 0x35a)", "code_verified"),
    (859, "structure.gate.panel.tan", "structure", "gate door panel, tan (part cel 0x35b, flag 8: +1 green)", "code_verified"),
    (860, "structure.gate.panel.green", "structure", "gate door panel, green variant of 859", "visual"),
]
for _cel, _id, _cat, _note, _conf in AUDIT5:
    put(_cel, _id, _cat, _note, _conf)


# AUDIT 2026-09-21, part 6 (registry hand-edited, not re-generated; documents 60 and 61):
# - 1081-1083: the mine's light (descriptor 0x454200: cel 0x439, flag 8, variant = the mine's state 0 / 1 / 2).
# - 1779-1802: the Jeep's missile body, 12 spin frames per team (descriptor 0x4548f0 part cel 0x6f3; its init callback
#   0x436be0 draws cel + frame + 12 for team 1, frame = whole(obj+0x70) advancing every 6 ticks). Not decorations.
AUDIT6 = [
    (1081, "effect.ember_small.01", "effect", "mine light, state 0 (unlit blink phase); descriptor 0x454200 part cel (document 60)", "code_verified"),
    (1082, "effect.ember_small.02", "effect", "mine light, state 1 (armed, steady); variant 1 of the mine's part (document 60)", "visual"),
    (1083, "effect.ember_small.03", "effect", "mine light, state 2 (blink phase on); variant 2 of the mine's part (document 60)", "visual"),
]
for _n in range(12):
    AUDIT6.append((1779 + _n, f"projectile.jeep_missile.tan.{_n + 1:02d}", "projectile",
                   "Jeep missile body, spin frame " + str(_n + 1) + " of 12, tan (descriptor 0x4548f0 part cel 0x6f3; document 61)",
                   "code_verified" if _n == 0 else "visual"))
    AUDIT6.append((1791 + _n, f"projectile.jeep_missile.green.{_n + 1:02d}", "projectile",
                   "Jeep missile body, spin frame " + str(_n + 1) + " of 12, green (cel 1779 + 12 + frame; document 61)", "visual"))
for _cel, _id, _cat, _note, _conf in AUDIT6:
    put(_cel, _id, _cat, _note, _conf)


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
