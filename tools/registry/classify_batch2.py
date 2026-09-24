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
AUDIT6.append((2074, "vehicle.jeep.wheels_topdown", "vehicle", "the Jeep's four wheels seen from above: swim-mode part 11 (descriptor 0x43fcb8, cel 0x81a; document 62)", "code_verified"))
for _cel, _id, _cat, _note, _conf in AUDIT6:
    put(_cel, _id, _cat, _note, _conf)


# AUDIT 2026-09-21, part 7 (registry hand-edited, not re-generated; document 65): the capture flag's cels. Each draw callback of
# the flag (0x403300 ground, 0x4032a0 carried) draws part cel + whole(obj+0x5c) + 13 * (team != 0): 13 wave frames per team, three
# sets of 26 cels (carried side view 1803, ground cloth with pole 1829, carried top view 1855).
AUDIT7 = []
for _set, _base, _what in (("carried_side", 1803, "carried flag, side view"), ("cloth", 1829, "ground flag (cloth and pole)"),
                           ("carried_top", 1855, "carried flag, top view")):
    for _team_i, _team in enumerate(("tan", "green")):
        for _f in range(13):
            AUDIT7.append((_base + _team_i * 13 + _f, f"marker.flag.{_set}.{_team}.{_f + 1:02d}", "marker",
                           f"{_what}, {_team}, wave frame {_f} of 13 (descriptor part cel {_base}; document 65)",
                           "code_verified"))
for _cel, _id, _cat, _note, _conf in AUDIT7:
    put(_cel, _id, _cat, _note, _conf)


# the HUD panel bases (document 68 / 70): the kind-2 element draws cel 0x797 (1943) + a per-vehicle number, and the four cels are four panels
# (by their pictures: Tank, Jeep with a compass dial, MSV, Heli; the order Tank, Jeep, MSV, Heli matches the vehicle records). 1940 is the blank frame.
AUDIT8 = [
    (1940, "ui.hud.panel_blank", "ui", "blank panel frame (template slot 2, offset -3,-2; document 66)", "visual_group"),
    (1943, "ui.hud.panel.tank", "ui", "HUD panel base, Tank (kind-2 element cel 0x797 + vehicle number; documents 68, 70)", "visual_group"),
    (1944, "ui.hud.panel.jeep", "ui", "HUD panel base, Jeep (compass dial; documents 68, 70)", "visual_group"),
    (1945, "ui.hud.panel.msv", "ui", "HUD panel base, MSV (documents 68, 70)", "visual_group"),
    (1946, "ui.hud.panel.heli", "ui", "HUD panel base, Heli (documents 68, 70)", "visual_group"),
]
for _cel, _id, _cat, _note, _conf in AUDIT8:
    put(_cel, _id, _cat, _note, _conf)


# the Jeep panel's missile pips (document 72): kind 7 draws cel 0x20ac0 = 1968 per missile and paints 0x7af = 1967 over a spent one.
AUDIT9 = [
    (1968, "ui.hud.pip_missile", "ui", "the Jeep panel's missile pip (kind 7 element FUN_004127b0 draws celtable + 0x20ac0; document 72)", "visual_group"),
    (1967, "ui.hud.pip_erase", "ui", "the patch kind 7 draws over a used pip (cel 0x7af, an 8 x 8 background swatch; document 72)", "visual_group"),
]
for _cel, _id, _cat, _note, _conf in AUDIT9:
    put(_cel, _id, _cat, _note, _conf)


# The home pad art (document 80): not a "bullseye" -- a bolted grey plate with a yellow-and-black hazard-striped border around a two-leaf hatch (a
# brown centre panel for 90, green for 91: the team's colour). FUN_0040b400, called once a tick only while a vehicle sits still on its own pad
# within docking tolerance and is NOT pressing a fire button, rotates 7 colour words of the cel's palette region at a fast, fixed rate (0x2666/65536
# a tick, about 9.3 steps a second): an animated warning-light border telling the player they are in position to dock. The visual identity (hatch,
# hazard stripes) is a look, so it stays "visual" confidence; the animation trigger and rate are code-verified.
AUDIT10 = [
    (90, "structure.hangar_hatch.tan", "terrain", "the tan team's home pad: a bolted hatch, brown centre, yellow-and-black hazard-stripe border that animates while a vehicle waits to dock (FUN_0040b400, document 80); was mislabelled a bullseye", "visual"),
    (91, "structure.hangar_hatch.green", "terrain", "the green team's home pad, the same hatch with a green centre (document 80); was mislabelled a bullseye", "visual"),
]
for _cel, _id, _cat, _note, _conf in AUDIT10:
    put(_cel, _id, _cat, _note, _conf)


# CORRECTED 2026-09-22 (registry hand-edited, not re-generated; document 83): 1977-1980 were
# classify_bulk.py guesses ("exit sign", "boost", "armor", "pause" icons) that turned out to be the
# Heli HUD panel's weapon-select icons -- kind-9 element FUN_00412a00 (panel slot 8, Heli only,
# document 70's "Not done" list) draws one of these four at two fixed panel positions depending on
# a single bit, obj+0xc & 0x10000000 -- the exact same weapon-select flag FUN_0040e600 (fire) and
# FUN_0040e7a0 (the third button, "toggle bit 28") already use (document 63). Verified against the
# real art, not just the code: 1977/1978 are the same rocket-like silhouette bright vs grey (the
# bomb), 1979/1980 the same twin-bar silhouette bright vs grey (the twin-mounted gun).
put(1977, "ui.hud.heli_weapon.bomb_lit", "ui",
    "bright rocket-silhouette icon; drawn when obj+0xc bit 0x10000000 is set (bomb selected)")
put(1978, "ui.hud.heli_weapon.bomb_dim", "ui",
    "dim/grey rocket-silhouette icon; drawn when the bomb is not selected (or no live object)")
put(1979, "ui.hud.heli_weapon.gun_lit", "ui",
    "bright twin-bar (twin gun) icon; drawn when obj+0xc bit 0x10000000 is clear (gun selected)")
put(1980, "ui.hud.heli_weapon.gun_dim", "ui",
    "dim/grey twin-bar (twin gun) icon; drawn when the gun is not selected")

# CORRECTED 2026-09-24 (registry hand-edited, not re-generated; document 88): cels 2126-2139 were
# "character.trooper_portrait.NN" (helmeted face); they are the laughing skull of the death screen
# (FUN_00418510: cel 2125 + table[timer] (+7 for player 0)). 2126-2132 tan helmet, 2133-2139 green.
for f in range(1, 8):
    put(2125 + f, f"ui.death_skull.tan.f{f}", "ui",
        f"laughing helmeted skull, mouth-open frame f{f} (document 88)", confidence="code_verified")
    put(2132 + f, f"ui.death_skull.green.f{f}", "ui",
        f"laughing helmeted skull, mouth-open frame f{f} (document 88)", confidence="code_verified")
put(2125, "ui.icon.lost_vehicle_cross", "ui",
    "7x7 red cross over the remaining-vehicle icons on the death screen (document 88)", confidence="code_verified")

# CORRECTED 2026-09-24 (registry hand-edited, not re-generated; user report): "vehicle.hovercraft.*" is the Tank
# (document 31 found the roster is Tank/Jeep/MSV/Heli but the ids were never renamed) -> vehicle.tank.*; three stray
# "hovercraft.wheel_hub" cels outside the block get neutral visual names; "vehicle.jetski.*" (640-654) and
# "prop.watercraft_distant.*" (630-639) are one 25-frame submarine sequence (visual, untraced) -> vehicle.submarine.01-25.
put(167, 'vehicle.tank.hull.01', 'vehicle',
    "category/id were already correct -- upgraded from visual_group to code_verified 2026-09-08 (document 38) since this cel is now proven, not guessed, to be a real Tank part. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(168, 'vehicle.tank.hull.02', 'vehicle',
    "dark green pillar (re-checked after the section 1.6 palette fix -- was misread as 'dark-red' then 'dark blue-grey' under the wrong palette) [RENAMED 2026-09-24 from vehicle.hovercraft.hull.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(169, 'vehicle.tank.p167.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 167 [RENAMED 2026-09-24 from vehicle.hovercraft.p167.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(170, 'vehicle.tank.p167.alt3', 'vehicle',
    "vehicle part variant group (document 46): slot 3 of the group starting at cel 167 [RENAMED 2026-09-24 from vehicle.hovercraft.p167.alt3: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(171, 'vehicle.tank.p167.alt4', 'vehicle',
    "vehicle part variant group (document 46): slot 4 of the group starting at cel 167 [RENAMED 2026-09-24 from vehicle.hovercraft.p167.alt4: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(172, 'vehicle.tank.hull.04', 'vehicle',
    "category/id were already correct -- upgraded from visual_group to code_verified 2026-09-08 (document 38) since this cel is now proven, not guessed, to be a real Tank part. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.04: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(173, 'vehicle.tank.hull.05', 'vehicle',
    "blue-dominant hull/cab icon (checked: b > g), NOT part of the confirmed tan/green team-colour pair (section 4 item 5, 2026-09-06) -- an earlier note here called this a team-colour lead; that's now walked back since it doesn't match the confirmed pair. Real duplicate-coloured art, purpose unconfirmed. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.05: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(174, 'vehicle.tank.p172.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 172 [RENAMED 2026-09-24 from vehicle.hovercraft.p172.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(175, 'vehicle.tank.p172.alt3', 'vehicle',
    "vehicle part variant group (document 46): slot 3 of the group starting at cel 172 [RENAMED 2026-09-24 from vehicle.hovercraft.p172.alt3: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(176, 'vehicle.tank.p172.alt4', 'vehicle',
    "vehicle part variant group (document 46): slot 4 of the group starting at cel 172 [RENAMED 2026-09-24 from vehicle.hovercraft.p172.alt4: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(177, 'vehicle.tank.turret.top.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.top.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(178, 'vehicle.tank.hull.08', 'vehicle',
    "blue-dominant hull/cab icon (checked: b > g), NOT part of the confirmed tan/green team-colour pair (section 4 item 5, 2026-09-06) -- an earlier note here called this a team-colour lead; that's now walked back since it doesn't match the confirmed pair. Real duplicate-coloured art, purpose unconfirmed. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.08: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(179, 'vehicle.tank.p177.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 177 [RENAMED 2026-09-24 from vehicle.hovercraft.p177.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(182, 'vehicle.tank.track.01', 'vehicle',
    "category/id were already correct -- upgraded from visual_group to code_verified 2026-09-08 (document 38) since this cel is now proven, not guessed, to be a real Tank part. [RENAMED 2026-09-24 from vehicle.hovercraft.track.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(183, 'vehicle.tank.track.02', 'vehicle',
    "tank-tread segment [RENAMED 2026-09-24 from vehicle.hovercraft.track.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(184, 'vehicle.tank.p182.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 182 [RENAMED 2026-09-24 from vehicle.hovercraft.p182.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(187, 'vehicle.tank.hull.10', 'vehicle',
    "category/id were already correct -- upgraded from visual_group to code_verified 2026-09-08 (document 38) since this cel is now proven, not guessed, to be a real Tank part. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.10: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(188, 'vehicle.tank.hull.21', 'vehicle',
    "corrected 2026-09-08 (was misclassified as decoration.stripe_band.01) -- confirmed by direct RE trace (document 37) as the green-team counterpart of cel 187 (vehicle.hovercraft.hull.10), one of the Tank real 3D box model's six real faces; same rivet-detail shape, green instead of brown [RENAMED 2026-09-24 from vehicle.hovercraft.hull.21: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(189, 'vehicle.tank.p187.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 187 [RENAMED 2026-09-24 from vehicle.hovercraft.p187.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(192, 'vehicle.tank.turret.side.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.side.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(193, 'vehicle.tank.hull.13', 'vehicle',
    "blue-dominant hull/cab icon (checked: b > g), NOT part of the confirmed tan/green team-colour pair (section 4 item 5, 2026-09-06) -- an earlier note here called this a team-colour lead; that's now walked back since it doesn't match the confirmed pair. Real duplicate-coloured art, purpose unconfirmed. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.13: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(194, 'vehicle.tank.p192.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 192 [RENAMED 2026-09-24 from vehicle.hovercraft.p192.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(197, 'vehicle.tank.turret.back.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.back.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(198, 'vehicle.tank.hull.15', 'vehicle',
    "blue-dominant hull/cab icon (checked: b > g), NOT part of the confirmed tan/green team-colour pair (section 4 item 5, 2026-09-06) -- an earlier note here called this a team-colour lead; that's now walked back since it doesn't match the confirmed pair. Real duplicate-coloured art, purpose unconfirmed. [RENAMED 2026-09-24 from vehicle.hovercraft.hull.15: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(199, 'vehicle.tank.p197.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 197 [RENAMED 2026-09-24 from vehicle.hovercraft.p197.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(202, 'vehicle.tank.turret.barrel.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.barrel.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(203, 'vehicle.tank.turret.barrel.02', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.barrel.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(204, 'vehicle.tank.p202.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 202 [RENAMED 2026-09-24 from vehicle.hovercraft.p202.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(205, 'vehicle.tank.p202.alt3', 'vehicle',
    "vehicle part variant group (document 46): slot 3 of the group starting at cel 202 [RENAMED 2026-09-24 from vehicle.hovercraft.p202.alt3: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(206, 'vehicle.tank.p202.alt4', 'vehicle',
    "vehicle part variant group (document 46): slot 4 of the group starting at cel 202 [RENAMED 2026-09-24 from vehicle.hovercraft.p202.alt4: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(207, 'vehicle.tank.turret.front.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.front.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(208, 'vehicle.tank.hull.19', 'vehicle',
    "green/teal camo cab variant [RENAMED 2026-09-24 from vehicle.hovercraft.hull.19: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual_group')
put(209, 'vehicle.tank.p207.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 207 [RENAMED 2026-09-24 from vehicle.hovercraft.p207.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(212, 'vehicle.tank.turret.muzzle_ring.01', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.muzzle_ring.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(213, 'vehicle.tank.turret.muzzle_ring.02', 'vehicle',
    "corrected 2026-09-08 (document 39): confirmed by decompiling the real vehicle draw dispatcher (FUN_00402dc0) that this cel belongs to the Tank's own SEPARATE turret descriptor (0x0043e9b8), not a generic hull panel -- the previous id was a guess made before this descriptor was known to exist at all. [RENAMED 2026-09-24 from vehicle.hovercraft.turret.muzzle_ring.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='code_verified')
put(214, 'vehicle.tank.p212.yellow', 'vehicle',
    "vehicle part variant group (document 46): slot 2 of the group starting at cel 212 [RENAMED 2026-09-24 from vehicle.hovercraft.p212.yellow: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(215, 'vehicle.tank.p212.alt3', 'vehicle',
    "vehicle part variant group (document 46): slot 3 of the group starting at cel 212 [RENAMED 2026-09-24 from vehicle.hovercraft.p212.alt3: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(216, 'vehicle.tank.p212.alt4', 'vehicle',
    "vehicle part variant group (document 46): slot 4 of the group starting at cel 212 [RENAMED 2026-09-24 from vehicle.hovercraft.p212.alt4: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank's traced draw descriptor, parts 167-216 with their +1 team / +2 flash variants (documents 37, 57).]", confidence='visual')
put(218, 'vehicle.tank.rotation.tan.01', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(219, 'vehicle.tank.rotation.tan.02', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(220, 'vehicle.tank.rotation.tan.03', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.03: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(221, 'vehicle.tank.rotation.tan.04', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.04: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(222, 'vehicle.tank.rotation.tan.05', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.05: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(223, 'vehicle.tank.rotation.tan.06', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.06: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(224, 'vehicle.tank.rotation.tan.07', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.07: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(225, 'vehicle.tank.rotation.tan.08', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.08: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(226, 'vehicle.tank.rotation.tan.09', 'vehicle',
    "continues the vehicle.hovercraft.rotation.tan sequence (cels 218-225) one frame further -- an 11-pixel, near-edge-on sliver. Originally misclassified as prop.debris_faint by the original bulk pass; corrected 2026-09-06 after comparing pixel counts against its neighbours (220, 166, 69, 34, 11 non-transparent pixels, monotonically thinning) while diagnosing a user-reported turning-sprite bug (PORTING_PLAN.md section 4 item 10). Cels 227-231 were checked the same way and are genuinely blank padding, not further real frames. [RENAMED 2026-09-24 from vehicle.hovercraft.rotation.tan.09: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(232, 'vehicle.tank.rotation.green.01', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.01: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(233, 'vehicle.tank.rotation.green.02', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.02: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(234, 'vehicle.tank.rotation.green.03', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.03: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(235, 'vehicle.tank.rotation.green.04', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.04: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(236, 'vehicle.tank.rotation.green.05', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.05: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(237, 'vehicle.tank.rotation.green.06', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.06: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(238, 'vehicle.tank.rotation.green.07', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.07: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(239, 'vehicle.tank.rotation.green.08', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.08: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(240, 'vehicle.tank.rotation.green.09', 'vehicle',
    "[RENAMED 2026-09-24 from vehicle.hovercraft.rotation.green.09: there is no hovercraft -- the game roster is Tank/Jeep/MSV/Heli (document 31) and this block is the Tank (same hull art as 172/173); these frames are NOT referenced by the Tank descriptor (document 37), so 'rotation' is itself an unverified label.]", confidence='visual_group')
put(614, 'prop.fragment_grey.01', 'prop',
    '[RENAMED 2026-09-24 from vehicle.hovercraft.wheel_hub.04: no hovercraft vehicle exists (document 31) and nothing links this cel to the Tank; name is a visual placeholder, owner untraced.]', confidence='visual_group')
put(622, 'prop.ring_yellow.01', 'prop',
    '[RENAMED 2026-09-24 from vehicle.hovercraft.wheel_hub.05: no hovercraft vehicle exists (document 31) and nothing links this cel to the Tank; name is a visual placeholder, owner untraced.]', confidence='visual_group')
put(623, 'prop.ring_yellow.02', 'prop',
    '[RENAMED 2026-09-24 from vehicle.hovercraft.wheel_hub.06: no hovercraft vehicle exists (document 31) and nothing links this cel to the Tank; name is a visual placeholder, owner untraced.]', confidence='visual_group')
put(630, 'vehicle.submarine.01', 'vehicle',
    'submarine surfacing/diving sequence, frame 1 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.01, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(631, 'vehicle.submarine.02', 'vehicle',
    'submarine surfacing/diving sequence, frame 2 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.02, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(632, 'vehicle.submarine.03', 'vehicle',
    'submarine surfacing/diving sequence, frame 3 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.03, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(633, 'vehicle.submarine.04', 'vehicle',
    'submarine surfacing/diving sequence, frame 4 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.04, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(634, 'vehicle.submarine.05', 'vehicle',
    'submarine surfacing/diving sequence, frame 5 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.05, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(635, 'vehicle.submarine.06', 'vehicle',
    'submarine surfacing/diving sequence, frame 6 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.06, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(636, 'vehicle.submarine.07', 'vehicle',
    'submarine surfacing/diving sequence, frame 7 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.07, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(637, 'vehicle.submarine.08', 'vehicle',
    'submarine surfacing/diving sequence, frame 8 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.08, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(638, 'vehicle.submarine.09', 'vehicle',
    'submarine surfacing/diving sequence, frame 9 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.09, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(639, 'vehicle.submarine.10', 'vehicle',
    'submarine surfacing/diving sequence, frame 10 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from prop.watercraft_distant.10, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(640, 'vehicle.submarine.11', 'vehicle',
    'submarine surfacing/diving sequence, frame 11 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.01, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(641, 'vehicle.submarine.12', 'vehicle',
    'submarine surfacing/diving sequence, frame 12 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.02, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(642, 'vehicle.submarine.13', 'vehicle',
    'submarine surfacing/diving sequence, frame 13 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.03, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(643, 'vehicle.submarine.14', 'vehicle',
    'submarine surfacing/diving sequence, frame 14 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.04, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(644, 'vehicle.submarine.15', 'vehicle',
    'submarine surfacing/diving sequence, frame 15 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.05, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(645, 'vehicle.submarine.16', 'vehicle',
    'submarine surfacing/diving sequence, frame 16 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.06, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(646, 'vehicle.submarine.17', 'vehicle',
    'submarine surfacing/diving sequence, frame 17 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.07, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(647, 'vehicle.submarine.18', 'vehicle',
    'submarine surfacing/diving sequence, frame 18 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.08, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(648, 'vehicle.submarine.19', 'vehicle',
    'submarine surfacing/diving sequence, frame 19 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.09, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(649, 'vehicle.submarine.20', 'vehicle',
    'submarine surfacing/diving sequence, frame 20 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.10, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(650, 'vehicle.submarine.21', 'vehicle',
    'submarine surfacing/diving sequence, frame 21 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.11, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(651, 'vehicle.submarine.22', 'vehicle',
    'submarine surfacing/diving sequence, frame 22 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.12, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(652, 'vehicle.submarine.23', 'vehicle',
    'submarine surfacing/diving sequence, frame 23 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.13, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(653, 'vehicle.submarine.24', 'vehicle',
    'submarine surfacing/diving sequence, frame 24 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.14, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')
put(654, 'vehicle.submarine.25', 'vehicle',
    'submarine surfacing/diving sequence, frame 25 of 25 (cels 630-654): a wake that grows into a dark hull with a conning tower. [RENAMED 2026-09-24 from vehicle.jetski.15, user-identified and visually confirmed; NOT traced -- no code or table reference to cels 630-654 found yet; the sound-test list has a "Sub" cue (document 31).]', confidence='visual')


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
