"""Bulk classification of the remaining sprite cels (vehicles, buildings, weapon
props, UI, fonts) -- the "coarse pass" the user asked for (2026-09-06): group by
object + sequential part/frame number, confidence "visual_group" unless noted,
precision saved for a later refinement pass once real rendering can verify against
gameplay. See classify_batch1-3.py for the earlier, more precise terrain/effect/
first-vehicle batches this continues from.

This script accumulates entries across many contact-sheet review sessions (each
section below is one batch, commented with the index range it covers) and is
re-run after each addition. Keep it idempotent: re-running with the same ENTRIES
must produce the same registry state.

KNOWN BUG, found 2026-09-06, NOT YET FIXED -- do not just re-run this file to apply a
new correction block without checking first: `_ensure_seeded()`'s per-call exclusion
(see its own comment) only excludes the indices of the ONE seq()/put() call currently
seeding, not every other call in this file that assigns the same id family. Several
families are legitimately split across multiple calls (structure.building_wall:
lines ~268/292/319; structure.window: ~306/320, at least). Re-running the whole file
after those families are already on disk makes each of those calls' seeding scans
see the OTHER calls' already-assigned numbers as "used", inflating the family's
counter every run -- the exact drift bug document 21 already found and partially
fixed, just triggered a different way (one call correctly excludes its own past
output, but not a sibling call's). Confirmed by re-running this file standalone on
2026-09-06: structure.building_wall and structure.window entries drifted (e.g.
.841->.911) with no code change to those families at all. Correction blocks added
as explicit put() calls with hand-picked numbers (see the capture-flag correction
below) are unaffected -- they don't touch _family_next. Anything using seq()'s
auto-numbering for a family already split across multiple calls is at risk on
re-run; verify with `git diff packs/registry/asset_ids.json` after running this file
and revert+hand-patch (like the capture-flag fix below did) rather than committing a
mass renumbering that wasn't the point of the change.
"""
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "build", "car", "art_atlas.json")
ATLAS_PNG = os.path.join(ROOT, "build", "car", "art_atlas.png")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

ENTRIES = {}


def dominant_team_colour(idx, atlas_cels, atlas_img):
    """tan vs green (section 4 item 5), by mean RGB of a cel's non-transparent pixels --
    used where a long run of near-identical frames alternates between the two known team
    hues (see the 655-754 trooper-run family) and eyeballing a downscaled contact sheet
    risks mis-transcribing which frame is which colour.

    CORRECTED (2026-09-06): originally compared only b vs r and returned "blue" -- a
    real bug in its own right (this project's two team colours are tan and green, never
    blue, confirmed independently in PORTING_PLAN.md section 4 item 5), compounded by
    convert_car.py's palette-offset bug (docs/process/20) changing every cel's actual
    colours out from under this heuristic. Re-checked against the regenerated (correct)
    atlas: green is unambiguously the highest channel for the second team, not merely
    higher than blue."""
    c = atlas_cels[idx]
    crop = atlas_img.crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
    pixels = [p for p in crop.getdata() if p[3] > 0]
    r = sum(p[0] for p in pixels) / len(pixels)
    g = sum(p[1] for p in pixels) / len(pixels)
    b = sum(p[2] for p in pixels) / len(pixels)
    return "green" if g > r and g > b else "tan"


def put(idx, id_, category, note=None, confidence="visual_group"):
    ENTRIES[idx] = {"id": id_, "category": category, "confidence": confidence, **({"note": note} if note else {})}


_family_next = {}  # id-family prefix -> next free sequence number, seeded once per run

with open(REGISTRY_JSON) as _f:
    _registry_at_start = json.load(_f)["cels"]


def _ensure_seeded(family, own_indices):
    # Seeded from the on-disk registry MINUS whatever this exact call is about to
    # (re)assign -- needed because some families (e.g. vehicle.hovercraft.wheel_hub)
    # are shared with the one-shot classify_batch1-3.py scripts, which this file must
    # continue numbering after, not collide with. Excluding own_indices is what makes
    # that safe to combine with re-running this file: a family touched only by this
    # script sees none of its own previous-run output counted as "used" (that output
    # is about to be overwritten by this very call), so it seeds at 1 every time;
    # a family shared with a batch1-3.py entry that this call never touches keeps
    # seeding after that entry's number, every time. An earlier version seeded from
    # the raw registry with no exclusion, which meant every re-run saw its own last
    # run's numbers as "already used" and counted past them -- a family touched by
    # N separate runs of this file drifted by N times its own size (e.g. this bug once
    # left the tan hovercraft-rotation family at .81-.88 instead of .01-.08).
    if family not in _family_next:
        own = set(own_indices)
        used = [int(v["id"][len(family):]) for k, v in _registry_at_start.items()
                 if int(k) not in own and v["id"].startswith(family) and v["id"][len(family):].isdigit()]
        _family_next[family] = (max(used) + 1) if used else 1


def seq(indices, id_fmt, category, note=None, start=None):
    """start is an optional manual override; by default the next number for this
    id family follows on from the registry, excluding this exact call's own indices
    (see _ensure_seeded), so batches never need to hand-track collisions."""
    family = id_fmt.split("{n")[0]
    _ensure_seeded(family, indices)
    for i, idx in enumerate(indices):
        if start is not None:
            n = start + i
            _family_next[family] = max(_family_next[family], n + 1)
        else:
            n = _family_next[family]
            _family_next[family] += 1
        put(idx, id_fmt.format(n=n), category, note)


# ---- batch: 218-326 ----------------------------------------------------------
# A hovercraft rotation-silhouette set (tan + cyan, matches the batch-3 hovercraft's
# colours -- likely its actual in-game top-down rotation frames, as opposed to
# batch 3's icon/panel pieces), a rotating "stalk with a ball on top" prop of
# unconfirmed identity (antenna? buoy? sensor?), an explosion/splash animation,
# fuel-drum props, small wheeled carts, control panels with screens, and missile/
# capsule rack props.
seq([218, 219, 220, 221, 222, 223, 224, 225], "vehicle.hovercraft.rotation.tan.{n:02d}", "vehicle")
seq([232, 233, 234, 235, 236, 237, 238, 239, 240], "vehicle.hovercraft.rotation.green.{n:02d}", "vehicle")
seq(list(range(246, 258)), "prop.stalk_orb.rotation.tan.{n:02d}", "prop",
    "rotating ball-on-a-stalk shape, identity unconfirmed (antenna/buoy/sensor)")
seq(list(range(258, 269)), "prop.stalk_orb.rotation.green.{n:02d}", "prop", "same prop, green-tinted variant")
seq([269, 270, 271, 272], "prop.stalk_orb.rotation.green.{n:02d}", "prop", "same prop, thin/distant frames")
seq([275, 276, 277, 282, 283, 287, 288], "effect.explosion_splash.{n:02d}", "effect",
    "red-spark/blue-splash burst, likely a hit or small-explosion animation")
seq([278, 284], "prop.fuel_drum.tan.{n:02d}", "prop")
seq([279], "prop.fuel_drum.tan_capped.{n:02d}", "prop", "tan drum with red end caps")
seq([280, 285], "prop.fuel_drum.cyan.{n:02d}", "prop")
seq([281], "prop.fuel_drum.orange.{n:02d}", "prop")
seq([286], "prop.fuel_drum.hazard_stripe.{n:02d}", "prop", "orange drum with black warning stripes")
seq([289, 300], "vehicle.cart.tan.{n:02d}", "vehicle", "small wheeled cart/mobile unit")
seq([290, 301], "vehicle.cart.cyan.{n:02d}", "vehicle")
seq([291], "vehicle.cart.orange.{n:02d}", "vehicle")
seq([294], "prop.ordnance_horizontal.01", "prop", "elongated red horizontal shape, missile or fuel tank")
seq([295], "vehicle.mobile_gun.tan.01", "vehicle", "gun barrel on a wheeled mount")
seq([296], "vehicle.mobile_gun.orange.01", "vehicle", "vertical-striped barrel on wheels")
seq([299], "vehicle.cart.tread.01", "vehicle", "tracked (not wheeled) small mobile unit")
seq([304], "vehicle.mobile_gun.detailed.01", "vehicle", "multi-colour detailed mobile weapon unit")
seq([305, 306], "prop.missile_pod.{n:02d}", "prop", "small horizontal green/blue pod with red tip")
seq([307, 308], "prop.debris_faint.{n:02d}", "prop", "very faint tan dashes/dots")
seq([309], "prop.control_panel.tan.01", "prop", "panel with a green display screen")
seq([310], "prop.control_panel.cyan.01", "prop")
seq([311], "prop.control_panel.ornate.01", "prop", "orange panel, darker ornate screen")
seq([312, 313], "prop.crate.tan.{n:02d}", "prop", "small blocky tan shapes")
seq([314], "prop.missile_rack.tan.01", "prop", "panel with 3 vertical red missile capsules")
seq([315], "prop.missile_rack.cyan.01", "prop")
seq([316], "prop.missile_rack.red.01", "prop", "solid red/orange, larger rack variant")
seq([317], "prop.sensor_array.tan.01", "prop", "panel with small red dot pattern")
seq([318], "prop.sensor_array.cyan.01", "prop")
seq([319], "decoration.emblem.06", "decoration", "green/tan ornate camo panel")
seq([320, 321], "prop.debris_faint.{n:02d}", "prop")
seq([322], "prop.fuel_canister.single.01", "prop", "single vertical capsule, blue body tan cap")
seq([323], "prop.fuel_canister.cluster_red.01", "prop", "bundled vertical capsules, red/blue")
seq([324], "prop.fuel_canister.cluster_blue.01", "prop", "bundled vertical capsules, blue/tan")
seq([226], "prop.debris_faint.{n:02d}", "prop")
seq([325], "prop.fuel_canister.cluster_blue.02", "prop", "2-capsule blue/red/white cluster")
seq([326], "prop.fuel_canister.cluster_blue.03", "prop", "3-capsule blue/red/white cluster")


# ---- batch: 328-461 -----------------------------------------------------------
# Cargo sacks, a small automated-turret-looking prop, canister racks, a bunker/
# pillbox building block (tan + teal team variants), a large explosion animation,
# assorted small props/panels/frames, and the first confirmed humanoid unit: a
# soldier/trooper figure in three colour variants (tan, cyan, brown).
seq(list(range(328, 335)), "prop.sack.tan.{n:02d}", "prop", "cargo sack, slight rotation")
seq([342, 343, 344, 345, 346, 347], "prop.sentry_turret.green.{n:02d}", "prop",
    "boxy body with two square window/eye shapes, likely a small automated turret or robot")
seq([348, 373, 381, 382, 389, 390, 391, 392, 405, 406, 415, 416, 426, 430, 431, 432],
    "prop.debris_faint.{n:02d}", "prop")
seq(list(range(356, 373)), "prop.canister_rack.{n:02d}", "prop",
    "row of red/blue vertical canisters on a base; base colour varies (plain/green/teal)")
seq(list(range(374, 381)), "structure.bunker.tan.{n:02d}", "structure", "crenellated-top bunker/pillbox block")
seq(list(range(383, 389)), "structure.bunker.teal.{n:02d}", "structure", "same bunker shape, teal team variant")
seq(list(range(398, 405)) + [413, 414], "effect.explosion_large.{n:02d}", "effect")
seq([417], "prop.tank_cylinder.tan.01", "prop", "cylindrical tank with a red valve/cross detail")
seq([418], "prop.tank_cylinder.cyan.01", "prop")
seq([422], "prop.frame.tan.01", "prop", "rectangular frame/window shape")
seq([423], "prop.frame.cyan.01", "prop")
seq([424], "prop.panel_icon.tan.01", "prop")
seq([425], "prop.panel_icon.teal.01", "prop")
seq([427], "prop.frame.tan.02", "prop", "open rectangular frame")
seq([428], "prop.frame.cyan.02", "prop")
seq([429], "prop.frame.tan.03", "prop", "thin outline frame")
seq([433], "vehicle.cart.tan.03", "vehicle")
seq([434], "vehicle.cart.cyan.03", "vehicle")
seq([437, 444, 450, 451], "effect.beam.{n:02d}", "effect", "thin vertical red line")
seq([452], "prop.window_brown.01", "prop", "brown-framed blue glass window/screen")
seq([438], "prop.control_panel.tan.02", "prop", "panel with small yellow lights")
seq([439], "prop.control_panel.orange.02", "prop", "larger, yellow lights")
seq([442], "prop.control_panel.cyan.02", "prop", "elongated, train-car-like, yellow lights")
seq([443], "prop.control_panel.red.02", "prop", "elongated, larger, yellow lights")
seq([447], "character.trooper.tan.01", "character", "humanoid infantry figure, torso up, bandolier strap")
seq([448], "character.trooper.cyan.01", "character")
seq([449], "character.trooper.brown.01", "character")
seq([453], "prop.display_screen.blue.01", "prop")
seq([454], "prop.display_screen.blue_striped.01", "prop", "same screen, diagonal-stripe state")
seq(list(range(457, 462)), "ui.map_blip.{n:02d}", "ui", "small red dot icon")


# ---- batch: 463-625 ------------------------------------------------------------
# A second trooper rotation set (head/shoulders, tan + teal), objective/target
# markers, a lot of long mottled "camo strip" and teal "wave/horizon" decorative
# strips (likely level-background or bridge/dock dressing), a standing-trooper
# squad, and assorted small props (domes, wheel hubs, spark-bolt effects).
seq(list(range(463, 470)), "character.trooper_head.rotation.tan.{n:02d}", "character")
seq([477, 478, 479, 480, 481, 482, 483, 484], "character.trooper_head.rotation.green.{n:02d}", "character")
seq(list(range(491, 505)), "character.trooper_head.rotation.green_alt.{n:02d}", "character",
    "second teal rotation/pose set, separated from the first by a gap in cel indices")
seq([470, 505, 506, 507, 508, 515, 523, 525], "prop.debris_faint.{n:02d}", "prop")
seq([509, 510, 511], "effect.explosion_large.{n:02d}", "effect",
    note="510 appears to show a trooper figure mid-burst -- possibly a death/hit animation")
seq([512, 513, 514], "prop.crate_dark.{n:02d}", "prop", "dark green/red long bar, ammo crate?")
seq([516], "prop.pickup_orb.tan.01", "prop", "small round glowing blob, possible pickup")
seq([517], "prop.pickup_orb.cyan.01", "prop")
seq([518, 520, 529, 542, 544, 545, 546, 548, 549, 550, 559, 560, 561, 562, 563],
    "prop.camo_strip.{n:02d}", "prop", "long mottled green/tan/brown horizontal strip, dressing/structure")
seq([521, 522, 524, 530, 531, 547, 551, 554, 555, 556, 557, 558],
    "prop.wave_horizon.{n:02d}", "prop", "teal wave/water/sky horizon-shaped strip")
seq([526], "structure.hatch_green.01", "structure", "door/hatch with yellow border")
seq([527], "prop.dome_turret.tan.01", "prop", "rounded pod/dome shape with a dark visor band")
seq([528], "prop.dome_turret.cyan.01", "prop")
seq(list(range(532, 539)), "marker.objective_target.{n:02d}", "marker",
    "red bullseye in a coloured frame (tan/green/blue/brown/orange) -- likely a mission-objective icon set")
seq([539, 540], "prop.ammo_panel_red.{n:02d}", "prop")
seq([541, 612, 620, 621], "effect.spark_bolt.{n:02d}", "effect", "yellow lightning-bolt/zigzag shape")
seq([543], "prop.wire_tan.01", "prop", "thin object with a red dot, cable or rope")
seq([564, 565, 566, 567, 568, 569, 570, 571, 572, 573, 574, 578],
    "character.trooper_squad.{n:02d}", "character", "standing full-body trooper figure, several colour variants")
seq([575, 576, 577], "effect.beam.{n:02d}", "effect")
seq([580, 581], "prop.brick_red.{n:02d}", "prop")
seq([584], "prop.hook_pipe.tan.01", "prop", "curved pipe/hook shape")
seq([585], "prop.hook_pipe.cyan.01", "prop")
seq([588], "prop.bar_dark_red.01", "prop")
seq([606], "prop.spike_ball.01", "prop", "red spiky ball, possibly a mine")
seq([607], "prop.panel_solid.tan.01", "prop")
seq([608], "prop.panel_solid.cyan.01", "prop")
seq([610, 611], "prop.diamond_pattern.{n:02d}", "prop", "red/orange diamond-checker strip")
seq([614, 622, 623], "vehicle.hovercraft.wheel_hub.{n:02d}", "vehicle")
seq([615, 624], "prop.dome_small.tan.{n:02d}", "prop", "small mushroom/dome shape, red top")
seq([625], "prop.dome_small.cyan.01", "prop")
seq([609], "prop.hook_claw.red.01", "prop", "small claw/hook shape, yellow tip")
seq([613], "prop.hook_claw.cyan.01", "prop")
seq([616, 617], "prop.riveted_panel_red.{n:02d}", "prop", "large mottled red panel with rivet-like dots")
seq([618], "prop.panel_solid.tan.02", "prop", "large solid tan panel")
seq([619], "prop.panel_solid.cyan.02", "prop", "large solid cyan panel")


# ---- batch: 630-869 -------------------------------------------------------------
# Major find: a ~100-cel running/walking trooper animation (655-754) in tan and
# green team colours -- almost certainly the on-foot infantry unit (Return Fire's
# rescue mechanic: pilots eject and can run, and/or hostages to recover). Preceded
# by a jetski-with-rider vehicle (630-654) and followed by small dust-puff effects
# (755-800), a chaotic multi-figure clash animation (801-820, possibly a melee/
# capture struggle), and then what looks like rescue/POW-camp dressing: red-cross-
# like markers (821-825, 858), barred-cage panels (826-827, 845-846), and building
# wall segments (834-838, 855-857, 864-869). Worth flagging in PORTING_PLAN.md as a
# new gameplay-mechanic lead once confirmed.
with open(ATLAS_JSON) as _f:
    _atlas = json.load(_f)
_cels_by_idx = {c["index"]: c for c in _atlas["cels"]}
_img = Image.open(ATLAS_PNG).convert("RGBA")

_run_counts = {"tan": 0, "green": 0}
for _idx in range(655, 755):
    _colour = dominant_team_colour(_idx, _cels_by_idx, _img)
    _run_counts[_colour] += 1
    put(_idx, f"character.trooper_run.{_colour}.{_run_counts[_colour]:03d}", "character",
        "running/walking infantry animation frame, direction within the cycle not disambiguated"
        if _run_counts[_colour] == 1 else None)

seq(list(range(630, 640)), "prop.watercraft_distant.{n:02d}", "prop", "small pale boat silhouette, likely distant-LOD")
seq(list(range(640, 655)), "vehicle.jetski.{n:02d}", "vehicle", "small watercraft with a red-clothed rider, rotation set")
seq(list(range(755, 801)), "effect.dust_puff.{n:02d}", "effect", "small light blue-white puff, likely footstep/impact dust")
seq(list(range(801, 821)), "effect.trooper_clash.{n:02d}", "effect",
    "chaotic multi-colour burst with a humanoid figure visible -- possibly a melee/capture struggle animation")
seq([821, 822, 823, 824, 825, 858], "marker.rescue_cross.{n:02d}", "marker",
    "red panel with a cyan/green cross or plus shape -- possible medic/rescue icon, unconfirmed")
seq([826, 827, 845, 846], "structure.cage_bars.{n:02d}", "structure", "dark panel with vertical bar pattern, possible POW cage")
seq([828, 829, 830], "prop.panel_frame_green.{n:02d}", "prop", "green-bordered red panel")
seq([831], "prop.chain_red.01", "prop", "thin beaded chain/rope pattern")
seq([832], "marker.sun_burst.01", "marker", "red panel with a yellow sun/star burst symbol")
seq([833], "marker.diamond_cyan.01", "marker", "cyan panel with a red diamond")
seq(list(range(834, 839)) + [855, 856, 857] + list(range(864, 870)),
    "structure.building_wall.{n:02d}", "structure", "pink/red wall segment, some with window/tent details")
seq([839, 840], "prop.panel_solid.orange.{n:02d}", "prop")
seq([841, 844], "prop.bar_thin.{n:02d}", "prop", "thin vertical coloured bar")
seq([847], "prop.composite_tan_blue.01", "prop", "small composite shape, unclear silhouette")
seq([848], "prop.blob_tan.01", "prop")
seq([849], "prop.post.tan.01", "prop")
seq([850], "prop.post.cyan.01", "prop")
seq([851, 852], "prop.diamond_pattern.{n:02d}", "prop")
seq([853, 854], "prop.bar_thin.{n:02d}", "prop")
seq([859, 860], "prop.panel_solid.dark_red.{n:02d}", "prop")
seq([863], "structure.doorway.01", "structure", "red archway with a brown door")
seq([861, 862], "effect.explosion_large.{n:02d}", "effect")


# ---- batch: 871-1075 -------------------------------------------------------------
# A large building/compound tileset: wall segments with windows and flags, domed
# roofs, doors, ladders, and rubble/damage variants of the same walls -- reads as
# a "base" structure the camera can get close to, built from the same kind of
# tile-like pieces as the terrain block (section 1.7) but at building scale.
seq(list(range(871, 878)), "structure.frame_post.{n:02d}", "structure", "A-frame post/pillar shape, brown or blue")
seq([878], "prop.rubble_patch.{n:02d}", "prop")
seq([880, 881, 882, 883, 884, 886, 887, 888, 889, 890, 891, 915, 916, 917, 918, 919,
     920, 921, 922, 923, 924, 925, 926, 930, 945, 946, 947, 948, 949, 950, 951, 952,
     955, 956, 957, 1050, 1052, 1053, 1054, 1055, 1056, 1057],
    "structure.building_wall.{n:02d}", "structure",
    note="red or blue wall segment with window/door/flag details")
seq([885], "structure.building_wall_lit.01", "structure", "wall segment, green-bordered lit window")
seq([892, 893], "structure.fence_lattice.{n:02d}", "structure", "brick/lattice fence pattern")
seq([895, 896, 897], "prop.path_strip.{n:02d}", "prop", "long road/path/water strip")
seq(list(range(898, 909)), "pickup.star.{n:02d}", "pickup", "small yellow star-burst shape, likely a pickup/power-up")
seq([909, 910, 914], "marker.panel_icon_red.{n:02d}", "marker")
seq([911, 912, 913], "marker.letter_icon.{n:02d}", "marker", "panel with a dark letter-like glyph, purpose unconfirmed")
seq([927], "effect.smoke_patch.01", "effect", "mottled cloud/smoke texture patch")
seq([928, 953, 954, 960, 961, 962, 963, 983, 984, 985, 986, 987, 988, 989, 990, 991,
     992, 993, 994, 995], "structure.building_wall_damaged.{n:02d}", "structure",
    "same wall family with a jagged rubble/destroyed edge")
seq([929], "decoration.plant.flower_red.03", "decoration")
seq([931, 942, 943], "structure.door.{n:02d}", "structure", "coloured door panel, red/green")
seq([932, 933, 940, 941], "structure.window.{n:02d}", "structure", "cyan or tan-bordered window panel")
seq([934, 935, 936], "structure.window_ornate.{n:02d}", "structure", "circular ornate red window/roundel design")
seq([938, 939], "structure.door.{n:02d}", "structure")
seq([944], "prop.debris_faint.{n:02d}", "prop")
seq([958, 959], "structure.ladder.{n:02d}", "structure", "vertical red/white ladder rungs")
seq([964, 965], "prop.panel_solid.tan_blue_edge.{n:02d}", "prop")
seq([968, 969, 970, 971, 977, 978, 979, 980, 981], "prop.panel_solid.blue.{n:02d}", "prop")
seq([972, 973, 974, 975, 976], "structure.building_wall_gable.{n:02d}", "structure",
    "wall with a pointed gable/roof silhouette along the top")
seq([997, 998, 999, 1000], "structure.dome_roof.{n:02d}", "structure", "rounded dome/tent roof shape")
seq([1001], "decoration.dashed_line.01", "decoration")
seq([1002, 1003, 1004], "decoration.stripe_band.{n:02d}", "decoration")
seq([1005, 1006, 1007, 1008, 1009, 1010, 1016, 1017, 1018, 1019, 1020, 1021, 1022, 1023],
    "structure.building_wall.{n:02d}", "structure")
seq([1012, 1013, 1014, 1015], "structure.window.{n:02d}", "structure")
seq([1024], "structure.window_lattice_green.01", "structure", "green plaid/checker window")
seq([1025], "decoration.moss_patch.01", "decoration", "dark green mottled square")
seq(list(range(1028, 1040)), "prop.pole_striped.{n:02d}", "prop", "thin vertical red/blue striped pole")
seq([1040, 1041], "marker.medallion.{n:02d}", "marker", "circular red/white concentric badge, possible landing/flag marker")
seq([1044], "prop.rubble_patch.{n:02d}", "prop")
seq([1045, 1046, 1047], "effect.explosion_large.{n:02d}", "effect")
seq([1048], "prop.panel_solid.tan.03", "prop")
seq([1049], "prop.panel_solid.cyan.03", "prop")
seq([1051], "prop.roof_box.01", "prop", "small tan/brown roof/box shape")
seq([1059, 1060], "effect.explosion_large.{n:02d}", "effect")
seq([1063], "effect.spark_bolt.{n:02d}", "effect")
seq([1064, 1065], "marker.hollow_square.{n:02d}", "marker", "hollow square outline, orange or red-dotted")
seq([1066, 1067], "prop.debris_faint.{n:02d}", "prop")
seq([1069, 1070], "prop.bone_shape.{n:02d}", "prop", "white curved bone/tusk-like shape, unconfirmed purpose")
seq([1072, 1073], "prop.dart_icon.{n:02d}", "prop", "small teal jet/dart arrow shape")
seq([1075], "decoration.foliage.bush_green.12", "decoration")


# ---- batch: 1077-1300 ------------------------------------------------------------
# A huge VFX library -- the bulk of this range is explosion/smoke/dust/blood burst
# animation frames. Two visually distinct exceptions get their own names (a
# checkered flag/warning pattern, and a set of expanding green rings that read as
# a shockwave/blast-ring animation); everything else in the range is bucketed by
# programmatic dominant-colour (same technique as the trooper-run colour split)
# into three burst families rather than hand-transcribed one at a time -- with
# ~180 near-identical animation frames in this range, that would be slow and no
# more reliable than the colour average.
seq([1081, 1082, 1083], "marker.checkered_flag.{n:02d}", "marker", "yellow/red checkered square")
seq(list(range(1200, 1211)), "effect.shockwave_ring.{n:02d}", "effect", "expanding green/yellow ring")

_burst_family = {"green": "effect.burst_green.{n:03d}", "brown_tan": "effect.burst_brown.{n:03d}",
                  "red_pink": "effect.burst_red.{n:03d}"}


def _colour_bucket(idx, atlas_cels, atlas_img):
    c = atlas_cels[idx]
    crop = atlas_img.crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
    pixels = [p for p in crop.getdata() if p[3] > 0]
    r = sum(p[0] for p in pixels) / len(pixels)
    g = sum(p[1] for p in pixels) / len(pixels)
    b = sum(p[2] for p in pixels) / len(pixels)
    if g >= r and g >= b:
        return "green"
    if b >= r and b >= g:
        return "green"  # the few blue-leaning frames here are still splash/burst, not a separate family
    return "brown_tan" if g > 110 else "red_pink"


with open(REGISTRY_JSON) as _f:
    _already_classified = {int(k) for k in json.load(_f)["cels"].keys()}

for _idx in range(1077, 1301):
    if _idx in ENTRIES or _idx in _already_classified or _idx not in _cels_by_idx:
        continue
    _bucket = _colour_bucket(_idx, _cels_by_idx, _img)
    seq([_idx], _burst_family[_bucket], "effect",
        "explosion/smoke/dust/blood burst frame, dominant-colour family; not individually verified")


# ---- batch: 1301-1563 ------------------------------------------------------------
# More VFX library, same dominant-colour bucketing as 1077-1300, plus one new
# distinct family: a set of expanding blue concentric rings (water splash / sonar
# ping, cels 1537-1563) cleanly separated from the red/brown/green bursts by a
# sharp colour-average jump (checked directly, not eyeballed).
seq(list(range(1537, 1564)), "effect.water_ring.{n:02d}", "effect", "expanding blue concentric ring")

for _idx in range(1301, 1537):
    if _idx in ENTRIES or _idx in _already_classified or _idx not in _cels_by_idx:
        continue
    _bucket = _colour_bucket(_idx, _cels_by_idx, _img)
    seq([_idx], _burst_family[_bucket], "effect",
        "explosion/smoke/dust/blood burst frame, dominant-colour family; not individually verified")


# ---- batch: 1565-1776 ------------------------------------------------------------
# More VFX library. Carves out three more distinct families before falling back to
# colour-bucketing: blue splash puffs (distinct from the ring-shaped water_ring
# family above), a small orange 8-point starburst (muzzle flash / detonation
# spark), and a long wavy red line built from several cels (likely a trailing
# effect or a decorative squiggle, not confirmed).
seq(list(range(1565, 1575)), "effect.water_splash.{n:02d}", "effect", "blue splash puff, not ring-shaped")
seq([1580, 1581, 1649, 1650], "effect.starburst.{n:02d}", "effect", "small orange 8-point starburst")
seq(list(range(1763, 1773)), "prop.wavy_line_red.{n:02d}", "prop",
    "segment of one long wavy red line spanning several cels; purpose unconfirmed (trail? wire? river?)")

for _idx in range(1565, 1777):
    if _idx in ENTRIES or _idx in _already_classified or _idx not in _cels_by_idx:
        continue
    _bucket = _colour_bucket(_idx, _cels_by_idx, _img)
    seq([_idx], _burst_family[_bucket], "effect",
        "explosion/smoke/dust/blood burst frame, dominant-colour family; not individually verified")


# ---- batch: 1779-1968 ------------------------------------------------------------
# A grab-bag: camo/rock mound clusters, map-shaped terrain patches (brown and
# blue), a capture-flag marker planted on several of those patches, dirt/water
# trail lines, camo-netting swatches, a yellow gem/pickup, an olive-green weapon
# and ammo-crate set (the first clear handheld weapon sprite found), and two more
# shockwave-ring colour variants (tan, orange) joining the earlier green/blue ones.
seq(list(range(1779, 1803)), "decoration.camo_mound.{n:02d}", "decoration", "rock/netting blob cluster, colour shifts tan-green-teal")
seq([1803, 1804, 1805, 1806, 1807, 1808, 1809, 1810, 1811, 1812, 1813, 1814],
    "decoration.terrain_patch_brown.{n:02d}", "decoration", "irregular map-shaped blob, brown/green")
seq([1815, 1816, 1817, 1818, 1819, 1820, 1821, 1822, 1823, 1824, 1825, 1826, 1827, 1828,
     1841, 1842, 1843, 1844, 1849, 1850, 1851, 1852, 1853, 1854],
    "decoration.terrain_patch_blue.{n:02d}", "decoration", "irregular map-shaped blob, light blue/ice-like")
seq([1829, 1830, 1831, 1832, 1833, 1834, 1835, 1836, 1837, 1838, 1839, 1840, 1845, 1846, 1847, 1848],
    "marker.capture_flag.{n:02d}", "marker", "red flag on a pole, planted on a terrain patch -- possible capture-point marker")
seq(list(range(1855, 1869)), "decoration.dirt_trail.{n:02d}", "decoration", "thin brown wavy line segment")
seq(list(range(1869, 1880)), "decoration.water_trail.{n:02d}", "decoration", "thin blue wavy line segment")
seq([1880], "prop.gem_red.01", "prop")
seq([1881, 1882, 1883, 1884, 1885, 1886], "marker.mine_icon.{n:02d}", "marker", "red pattern with a blue dotted border")
seq([1887], "effect.burst_red.{n:03d}", "effect")
seq([1888, 1889, 1890, 1891, 1892, 1893, 1894, 1895, 1896, 1936, 1937, 1948, 1967, 1968],
    "decoration.camo_swatch.{n:02d}", "decoration", "mottled green/olive square, camo-netting-like")
seq([1897, 1917, 1918, 1919, 1920, 1921], "pickup.gem_yellow.{n:02d}", "pickup")
seq([1922, 1923, 1924, 1925, 1938], "prop.debris_faint.{n:02d}", "prop")
seq([1926, 1927], "marker.banner_red.{n:02d}", "marker", "folded red flag/banner shape")
seq(list(range(1928, 1932)), "structure.pillar_red.{n:02d}", "structure")
seq([1932], "marker.rescue_cross.{n:02d}", "marker")
seq([1933, 1934, 1935], "prop.rubble_patch.{n:02d}", "prop")
seq([1939, 1965], "prop.wire_red.{n:02d}", "prop", "thin horizontal red line/wire")
seq([1940], "vehicle.weapon_rifle.01", "vehicle", "olive-green handheld weapon silhouette, top-down")
seq([1942, 1943, 1944, 1945, 1946, 1947], "prop.ammo_crate_olive.{n:02d}", "prop")
seq(list(range(1949, 1959)), "effect.shockwave_ring_tan.{n:02d}", "effect", "expanding tan/brown concentric ring")
seq(list(range(1959, 1963)), "effect.shockwave_ring_orange.{n:02d}", "effect", "expanding orange concentric ring")
seq([1966], "prop.panel_solid.olive.01", "prop")


# ---- batch: 1975-2164 ------------------------------------------------------------
# The tail end: HUD icons (small vehicle/aircraft minimap icons, a helmeted trooper
# portrait repeated many times, ammo/boost/pause icons), the numeric HUD font
# (0-9, found as a clean literal set -- exact digit identity, not a guess), a
# second orange trooper colour variant, and more VFX (whirlpool swirl, water
# spray, red dot-cluster markers, a large crater/mud texture).
seq([1975, 2090], "marker.hollow_square.{n:02d}", "marker")
seq([1976], "prop.debris_faint.{n:02d}", "prop")
seq([1977], "ui.icon.exit_sign.01", "ui", "olive icon, white running-figure silhouette")
seq([1978], "ui.icon.boost.01", "ui", "olive icon, white up-arrow")
seq([1979], "ui.icon.armor.01", "ui", "olive icon, white pillar/column shape")
seq([1980], "ui.icon.pause.01", "ui", "olive icon, white double-bar")
seq(list(range(1981, 1987)), "prop.skin_swatch.{n:02d}", "prop", "flat skin-tone colour square, likely a palette reference not a real sprite")
seq(list(range(1987, 1995)) + [2087, 2088, 2089], "effect.whirlpool.{n:02d}", "effect", "purple/blue spiral swirl")
seq(list(range(1995, 2038)) + list(range(2059, 2073)), "effect.water_spray.{n:02d}", "effect", "blue splotchy spray/cloud pattern")
seq(list(range(2038, 2059)) + [2073, 2074], "marker.cluster_dots_red.{n:02d}", "marker", "grid of small red circles")
seq([2075], "marker.badge_green.01", "marker")
seq([2076], "prop.bird_silhouette.01", "prop", "red flying-creature silhouette")
seq([2078], "prop.rock_mound_red.01", "prop")
seq([2079, 2091, 2092, 2093], "decoration.dashed_line.{n:02d}", "decoration")
seq(list(range(2080, 2084)), "decoration.crater_patch.{n:02d}", "decoration", "large mottled brown/green texture, bigger scale than other ground tiles")
seq([2084, 2085, 2086], "prop.wave_horizon.{n:02d}", "prop")
seq([2094, 2095, 2096, 2097, 2098, 2099, 2101, 2102, 2103, 2104, 2107, 2108, 2109,
     2112, 2113, 2114, 2161, 2162, 2163, 2164],
    "ui.icon.vehicle_mini.{n:02d}", "ui", "tiny vehicle icon, likely minimap/HUD unit marker")
seq([2100], "ui.icon.helicopter_mini.01", "ui")
seq([2105, 2110, 2115, 2117, 2120, 2123, 2158], "decoration.camo_swatch.{n:02d}", "decoration")
seq([2106, 2116, 2122], "ui.icon.ammo_bars.{n:02d}", "ui", "small vertical coloured bars")
seq([2111, 2121, 2156], "decoration.plant.flower_red.{n:02d}", "decoration")
seq([2118], "ui.icon.aircraft_mini.01", "ui", "small tan/gold airplane silhouette")
seq([2119], "ui.icon.helicopter_mini.02", "ui", "detailed side-view helicopter icon")
seq([2124], "ui.icon.panel_dark.01", "ui")
seq([2125], "ui.icon.checker_yellow.01", "ui")
seq(list(range(2126, 2140)), "character.trooper_portrait.{n:02d}", "character", "helmeted face portrait, repeated with minor variation")
seq([2140], "effect.static_noise.01", "effect")
seq(list(range(2142, 2146)), "character.trooper.orange.{n:02d}", "character")
for _digit, _idx in zip("0123456789", range(2146, 2156)):
    put(_idx, f"font.hud_digit.{_digit}", "font", "HUD numeric font glyph")
seq([2157, 2160], "prop.icon_small.{n:02d}", "prop")
seq([2159], "prop.rocket_small.01", "prop")


# ---- correction: team colour is tan/green, not tan/cyan (2026-09-06) ------------
# The user, who owns and has played the original, said the two player colours are
# tan and green. Checked against pixel data rather than taken on faith: every cel
# in three large, independent families (character.trooper_run, character.trooper_head.
# rotation, vehicle.hovercraft.rotation, plus prop.stalk_orb.rotation and
# prop.sentry_turret) is green-dominant by mean pixel colour -- these had been
# mislabeled "blue"/"cyan"/"teal" by an earlier colour heuristic that only compared b
# against r and never checked g at all. Fixed at each seq() call's own id_fmt string
# above (and in dominant_team_colour()'s return value) rather than patched here after
# the fact -- an earlier version of this correction used a stale on-disk registry
# snapshot to rename things post-hoc, which doesn't survive this script being re-run
# (each re-run replays the original, still-wrong seq() calls first), so the "fix"
# silently undid itself on the next batch. Renaming the actual source is the only
# version of this fix that's stable across reruns.
#
# Separately, the specific hull-ICON pieces at cels 173/178/193/198 (batch 3, tagged
# with a "possible team-colour lead" note) really are blue-dominant (b > g, checked) --
# unlike everything above, that finding does NOT match "tan and green" and is walked
# back below: still real duplicate-coloured art, just not evidence for the confirmed
# team-colour pair. Left as "cyan" since that's what they actually are; the note is
# corrected to stop calling them a team-colour lead.
with open(REGISTRY_JSON) as _f:
    _reg_for_fix = json.load(_f)

_TEAM_COLOUR_NOTE_FIX = ("blue-dominant hull/cab icon (checked: b > g), NOT part of the confirmed "
                          "tan/green team-colour pair (section 4 item 5, 2026-09-06) -- an earlier note "
                          "here called this a team-colour lead; that's now walked back since it doesn't "
                          "match the confirmed pair. Real duplicate-coloured art, purpose unconfirmed.")
for _idx in [173, 178, 193, 198]:
    _old = _reg_for_fix["cels"][str(_idx)]
    put(_idx, _old["id"], _old["category"], _TEAM_COLOUR_NOTE_FIX, _old["confidence"])

# A handful of individual mislabels caught while spot-checking the above (wrong colour
# bucket entirely, not the green/blue confusion) -- fixed here since they were found:
put(168, "vehicle.hovercraft.hull.02", "vehicle", "dark green pillar (re-checked after the section 1.6 palette fix -- was misread as 'dark-red' then 'dark blue-grey' under the wrong palette)")
put(384, "structure.bunker.tan.49", "structure", "tan/brown wall (corrected: was miscategorised into the teal list)")
put(301, "vehicle.cart.red.01", "vehicle", "solid red/dark tank-tread cart (corrected: was miscategorised as cyan)")
put(608, "prop.pipe_grey.01", "prop", "thin grey pipe/rod with a red tip (re-checked after the section 1.6 palette fix -- mostly grey, not a red panel)")
put(585, "prop.pipe_grey.02", "prop", "thin grey hook/pipe shape with small red accents (re-checked after the section 1.6 palette fix -- mostly grey, not red/orange)")


# ---- correction: palette-bug relabeling (2026-09-06) ---------------------------
# convert_car.py had a real colour bug (see its module docstring and
# docs/process/20-worked-example-palette-offset.md): raw pixel byte k decoded as
# shared_plut[k] instead of shared_plut[k-10], producing plausible-looking but
# wrong-hued output. Nothing crashed and nothing looked like noise, so the whole
# terrain classification pass (batch 1) named a few cels by their WRONG colour.
# Re-checked visually against the regenerated (correct) atlas; only entries whose
# semantic meaning actually changes are touched here -- most of batch 1 (shapes,
# autotile families) is unaffected since palette doesn't change geometry.
put(0, "terrain.ground.water_open.01", "terrain", "was misclassified as sand under the old wrong palette; actually open water", "visual")
put(1, "terrain.ground.water_open.02", "terrain", "was misclassified as sand under the old wrong palette; actually open water", "visual")
put(3, "terrain.ground.water_open.03", "terrain", "was misclassified as forest under the old wrong palette; actually open water", "visual")
put(52, "terrain.ground.water_open.04", "terrain", "was misclassified as forest under the old wrong palette; actually open water", "visual")
for n, idx in enumerate([84, 85, 86], start=1):
    put(idx, f"terrain.ground.wood_planks.{n:02d}", "terrain",
        "was misclassified as green furrow/hedge under the old wrong palette; actually brown wood planks", "visual")


# ---- correction: capture-flag is two team-coloured animations, and 4 frames were
# misclassified as an unrelated decoration (2026-09-06) -----------------------------
# Found while investigating section 4 item 1 (PORTING_PLAN.md) after the user described
# a capture-the-flag win condition: a hidden developer debug string in RFIRE.BIN reading
# "Flag in first building: %s" (FUN_004065c0's debug menu) makes marker.capture_flag's
# original "possible capture-point marker" guess above look right, so this was worth a
# closer re-render and look (document 6's rule 1) rather than leaving the old note as-is.
#
# That closer look found two things:
# 1. It's not one flag colour -- cels 1829-1841 are an orange/red waving-flag animation,
#    1842-1848 are the same animation in green. Two team-coloured flags, not a single
#    generic marker.
# 2. cels 1841-1844 were NOT in the original marker.capture_flag seq() call above at all --
#    they'd been swept into decoration.terrain_patch_blue.{n:02d} instead (that seq() call
#    explicitly lists 1841-1844 among its indices). Rendered and looked at directly: they
#    are unmistakably flag-on-a-pole frames (1841 orange, 1842-1844 green), not the
#    irregular ice-coloured terrain blobs the rest of that family actually is. A real
#    misclassification, not a borderline judgment call -- corrected here rather than left,
#    the same way document 20's palette-bug relabeling block above corrects entries that
#    turned out wrong. decoration.terrain_patch_blue keeps its original 24-item sequence
#    numbering as a frozen historical record (per this file's own convention -- see the
#    "individual mislabels" block above for the same approach); its family now has a
#    4-item numbering gap (.15-.18) as a cosmetic side effect of that choice, not a bug.
#
# Not yet confirmed by code (still "visual_group", not upgraded to "confirmed"): that
# THIS specific cel range is what RFIRE.BIN's flag-drop object (FUN_0042c290, object-type
# descriptor 0x44e3c0, see PORTING_PLAN.md section 4 item 1) actually renders. The debug
# string and the object's own dedicated (single-cross-reference) status make it a strong
# lead, not a traced certainty -- rendering these cels through a mock-up of that object,
# or reading FUN_0042c290's CCB/art field directly, would close that gap.
#
# This block only uses put() with hand-picked numbers, not seq()'s auto-numbering, so
# it's unaffected by the KNOWN BUG at the top of this file -- but running this file's
# OTHER, seq()-based calls in the same pass hit that bug (2026-09-06), so the actual
# registry on disk was hand-patched to match this block's output rather than produced by
# running this file wholesale. Re-running this file will reproduce this block correctly;
# check `git diff packs/registry/asset_ids.json` before trusting the rest of the output.
_FLAG_NOTE = ("waving flag on a pole; two team-coloured animations (red 01-13, green "
              "01-07). Strong candidate for RFIRE.BIN's flag object (section 4 item 1, "
              "2026-09-06): a hidden developer debug string reads \"Flag in first "
              "building: %s\", and the object-destruction handler this project already "
              "reimplements as TargetPool (section 1.5 / Phase 4 step 5) reads that same "
              "debug value before deciding whether to spawn a dedicated, single-use-site "
              "object -- not yet traced far enough to confirm this exact cel range is what "
              "that object renders, so still visual_group, not confirmed.")
for _n, _idx in enumerate([1829, 1830, 1831, 1832, 1833, 1834, 1835, 1836, 1837, 1838, 1839,
                           1840, 1841], start=1):
    put(_idx, f"marker.capture_flag.red.{_n:02d}", "marker", _FLAG_NOTE)
for _n, _idx in enumerate([1842, 1843, 1844, 1845, 1846, 1847, 1848], start=1):
    put(_idx, f"marker.capture_flag.green.{_n:02d}", "marker", _FLAG_NOTE)

# Correction (2026-09-06), found while diagnosing a user-reported "turning sprites" visual
# bug (a real Godot recording showed the vehicle's rotation sprite breaking into disconnected
# fragments partway through a turn -- see PORTING_PLAN.md section 4 item 10). Cel 226 was
# originally classified at line 159 above as `prop.debris_faint.226` (an 11-pixel, near-
# invisible fleck -- a reasonable-looking guess in isolation). Comparing it directly against
# its neighbours revealed it isn't debris at all: cels 218-225 are `vehicle.hovercraft.
# rotation.tan.01`-`.08`, a monotonically-thinning silhouette (220, 166, 69, 34 non-transparent
# pixels) as the vehicle turns edge-on -- and cel 226 continues that exact sequence at 11
# pixels, same hue, same shape family. Cels 227-231 (checked the same way) are genuinely
# fully-transparent padding, confirming 226 is the last real frame, not a fluke. This means
# the tan rotation set was one frame short of green's (`vehicle.hovercraft.rotation.green.01`-
# `.09`, cels 232-240, 9 frames) -- an asymmetry between the two teams' rotation sets that had
# no reason to exist and directly explains part of the reported bug: `vehicle.gd`'s
# `_frame_for_heading()` was stretching the same 8 frames (the last of which is already a
# disconnected-looking sliver) across the full 90-degree quarter-turn and then mirroring that
# same sliver frame across the quadrant boundary, instead of having a 9th, even-thinner real
# frame to hand off to first. `game/vehicle.gd` builds its frame list dynamically from every
# `vehicle.hovercraft.rotation.<team>.*` id already in the pack (`setup()`), so no code change
# is needed -- fixing the registry and regenerating the pack is the whole fix.
_ROTATION_GAP_NOTE = ("continues the vehicle.hovercraft.rotation.tan sequence (cels 218-225) "
                      "one frame further -- an 11-pixel, near-edge-on sliver. Originally "
                      "misclassified as prop.debris_faint (line 159 above) by the original "
                      "bulk pass; corrected 2026-09-06 after comparing pixel counts against "
                      "its neighbours (220, 166, 69, 34, 11 non-transparent pixels, "
                      "monotonically thinning) while diagnosing a user-reported turning-sprite "
                      "bug (PORTING_PLAN.md section 4 item 10). Cels 227-231 were checked the "
                      "same way and are genuinely blank padding, not further real frames.")
put(226, "vehicle.hovercraft.rotation.tan.09", "vehicle", _ROTATION_GAP_NOTE)

# --- 2026-09-06: real vehicle roster confirmed via a string table (RFIRE.BIN offset
# 0x00445280-ish: "MSV", "JEEP", "Tank", "Vehicle", "Destroyed Vehicle" -- plus a second,
# separate sound-cue-name table at ~0x004462c0: "HELI Death"/"Heli 1"/"Heli 2", "MSV
# Death"/"MSV 1", "Jeep Death"/"Jeep 1", "Tank Death"/"Tank 1/2/3"). This confirms the game
# has (at least) four distinct vehicle types -- not the one "hovercraft" this project had
# assumed throughout -- which directly resolves the old open question "no confirmed
# helicopter sprite exists despite that being Return Fire's best-known vehicle" (plan section
# 4 item 12): a real mini-map/radar icon set for exactly these vehicles sits at cels
# 2094-2114/2161-2164 (already bulk-classified generically as "ui.icon.vehicle_mini.NN"),
# found by searching for a helicopter's distinctive rotor-blade silhouette among the atlas's
# unusually long/thin cels, then recognising the surrounding icon family. This does NOT mean
# real playable rotation art for jeep/msv/heli has been located -- these are small map icons,
# not the 32x32-scale rotation cels vehicle.gd actually renders -- see PORTING_PLAN.md section
# 4 for that status.
_VEHICLE_ICON_NOTE = ("mini-map/radar icon, identified 2026-09-06 by matching its silhouette "
                      "against the real vehicle roster confirmed via RFIRE.BIN's own string "
                      "table (\"MSV\"/\"JEEP\"/\"Tank\"/\"HELI\", offset ~0x00445280 and "
                      "~0x004462c0) -- not the vehicle's actual in-game rotation art, which "
                      "renders at a different scale and has not been located for anything but "
                      "the tank. See docs/process/31-worked-example-vehicle-roster.md.")
put(2094, "ui.icon.tank_mini.tan", "vehicle", _VEHICLE_ICON_NOTE, confidence="visual")
put(2095, "ui.icon.tank_mini.green", "vehicle", _VEHICLE_ICON_NOTE, confidence="visual")
put(2096, "ui.icon.jeep_mini.tan", "vehicle", _VEHICLE_ICON_NOTE, confidence="visual")
put(2097, "ui.icon.jeep_mini.green", "vehicle", _VEHICLE_ICON_NOTE, confidence="visual")
put(2101, "ui.icon.heli_mini", "vehicle", _VEHICLE_ICON_NOTE, confidence="visual")
# Unclear which of the two remaining silhouette families is "MSV" specifically (a wheeled
# personnel-carrier-like shape) vs. some other unit/marker -- both are real vehicle icons, not
# guessed at further than that, honestly short of full identification.
put(2098, "ui.icon.wheeled_vehicle_mini_a.tan", "vehicle", _VEHICLE_ICON_NOTE)
put(2099, "ui.icon.wheeled_vehicle_mini_a.green", "vehicle", _VEHICLE_ICON_NOTE)
put(2107, "ui.icon.wheeled_vehicle_mini_b.tan", "vehicle", _VEHICLE_ICON_NOTE)
put(2108, "ui.icon.wheeled_vehicle_mini_b.green", "vehicle", _VEHICLE_ICON_NOTE)
put(2102, "ui.icon.tank_mini_alt.tan", "vehicle", _VEHICLE_ICON_NOTE)
put(2103, "ui.icon.tank_mini_alt.green", "vehicle", _VEHICLE_ICON_NOTE)
put(2112, "ui.icon.tank_mini_alt2.tan", "vehicle", _VEHICLE_ICON_NOTE)
put(2113, "ui.icon.tank_mini_alt2.green", "vehicle", _VEHICLE_ICON_NOTE)

# Confirmed wrong 2026-09-07, chasing a user-reported "trees don't look real" observation
# (docs/process/34, once written): cel 101 was classified as "decoration.tree" ("dark green
# canopy on a post/trunk") but a direct atlas crop shows no canopy/foliage at all -- a small
# gray structure with two flanking wall segments and a yellow/black hazard-striped base on a
# sand clearing. Renamed to something descriptive rather than guessing its gameplay role.
put(101, "terrain.structure.small_bunker", "terrain",
    "corrected 2026-09-07 (was misclassified as decoration.tree -- direct atlas crop shows a "
    "small gray structure with flanking wall segments and a yellow/black hazard-striped base "
    "on a sand clearing, no canopy/foliage anywhere; exact gameplay role unconfirmed, name is "
    "descriptive only)", confidence="visual")

# Confirmed wrong 2026-09-08, tracing the Tank's real 3D box model (document 37) all the way
# to RFIRE.BIN's own per-vehicle-type descriptor: cel 188 was classified as
# "decoration.stripe_band.01", but it's the green-team counterpart of cel 187
# (vehicle.hovercraft.hull.10, one of the Tank's six real faces) -- same rivet-detail shape,
# green instead of brown. Direct atlas crop confirms it visually.
put(188, "vehicle.hovercraft.hull.21", "vehicle",
    "corrected 2026-09-08 (was misclassified as decoration.stripe_band.01) -- confirmed by "
    "direct RE trace (document 37) as the green-team counterpart of cel 187 "
    "(vehicle.hovercraft.hull.10), one of the Tank real 3D box model's six real faces; same "
    "rivet-detail shape, green instead of brown", confidence="visual")

# --- 2026-09-08 (document 38): tools/registry/audit_code_referenced_cels.py cross-checked
# every cel now proven, by real code (tools/data/vehicle_type_parts.json, extracted from all 4
# vehicle-type descriptors, not just the Tank), to be part of a specific vehicle -- against this
# registry's own guess for that same cel. It found 29 cels for JEEP/MSV/HELI classified as
# something else entirely (character/prop/effect/marker/ui/pickup/decoration) -- not a
# vague-but-plausible guess like the Tank's old cel 188, but a flat category error, because
# nothing had ever traced these three vehicles' real parts before (JEEP/MSV/HELI's real geometry
# was extracted for the first time this session; only the Tank's had been fully decoded, in
# document 37). This is exactly the failure mode the user asked this audit to prevent from
# recurring. Renamed with a neutral "part.NN" sequence (numbered by their real part index in the
# descriptor, not a guess at what each panel visually depicts -- unlike the Tank's hull/track/
# wheel_hub names, no visual review pass has been done on these yet) rather than invent new
# descriptive names this audit has no visual basis for. confidence="code_verified" -- a
# strictly stronger claim than "confirmed" elsewhere in this file (which has sometimes just
# meant "eyeballed twice"): every cel below is proven by walking RFIRE.BIN's own vehicle-type
# descriptor data, not visual comparison. None of these 3 vehicles are rendered in 3D yet (only
# the Tank is, in game/vehicle_box_3d.gd) -- this is a registry-accuracy fix, not a rendering
# one.
#
# IMPORTANT re-run note: this whole block is a DOCUMENTATION record of what was applied, not
# the mechanism that applied it. Running this file's own main() to apply it hit the exact
# "known bug" this file's own header already warns about (a seq() family recomputing different
# numbers than what's on disk once a sibling cel's id changes -- here, cel 188's document-37
# correction freed up "decoration.stripe_band.01", shifting what the "decoration.stripe_band."
# seq() call at line ~337 computes as the next free number). The corrections below were applied
# by a small one-off script that edited packs/registry/asset_ids.json directly with these exact
# id/category/confidence/note values (bypassing ENTRIES/main() entirely) -- re-running this
# file's main() is still unsafe for the reason the file header already documents.
_JEEP_NOTE = ("real JEEP vehicle part, confirmed 2026-09-08 by walking RFIRE.BIN's own "
              "vehicle-type descriptor #1 (see tools/data/vehicle_type_parts.json, document "
              "39) -- corrects a flat category error, not a refinement of a plausible guess.")
put(422, "vehicle.jeep.part.01", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(432, "vehicle.jeep.part.02", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(437, "vehicle.jeep.part.03", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(442, "vehicle.jeep.part.04", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(417, "vehicle.jeep.part.05", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(427, "vehicle.jeep.part.06", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(447, "vehicle.jeep.part.07", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(452, "vehicle.jeep.part.08", "vehicle", _JEEP_NOTE, confidence="code_verified")
put(457, "vehicle.jeep.part.09", "vehicle", _JEEP_NOTE, confidence="code_verified")

_MSV_NOTE = ("real MSV vehicle part, confirmed 2026-09-08 by walking RFIRE.BIN's own "
             "vehicle-type descriptor #2 (see tools/data/vehicle_type_parts.json, document "
             "39) -- corrects a flat category error, not a refinement of a plausible guess.")
put(279, "vehicle.msv.part.01", "vehicle", _MSV_NOTE, confidence="code_verified")
put(284, "vehicle.msv.part.02", "vehicle", _MSV_NOTE, confidence="code_verified")
put(294, "vehicle.msv.part.03", "vehicle", _MSV_NOTE, confidence="code_verified")
put(314, "vehicle.msv.part.04", "vehicle", _MSV_NOTE, confidence="code_verified")
put(309, "vehicle.msv.part.05", "vehicle", _MSV_NOTE, confidence="code_verified")
put(324, "vehicle.msv.part.06", "vehicle", _MSV_NOTE, confidence="code_verified")
put(319, "vehicle.msv.part.07", "vehicle", _MSV_NOTE, confidence="code_verified")
# These 3 were already category="vehicle" (as "cart"/"mobile_gun" -- a guess that they were
# small standalone vehicles in their own right, not parts of a larger one) -- confirmed by
# document 38 to actually be MSV body parts instead. Left under their existing ids rather than
# folded into vehicle.msv.part.NN above: renaming risks fragmenting the "cart"/"mobile_gun"
# families' *other* members (e.g. cels 290/291/300/301/433/434), which this audit did not
# re-check and may or may not be MSV parts too -- that's a separate pass, not assumed here.
put(289, "vehicle.cart.tan.04", "vehicle",
    "confirmed 2026-09-08: actually an MSV body part (document 38), not a standalone small "
    "vehicle -- kept under its existing id, see this section's own note on why.",
    confidence="code_verified")
put(299, "vehicle.cart.tread.01", "vehicle",
    "confirmed 2026-09-08: actually an MSV body part (document 38), not a standalone small "
    "vehicle -- kept under its existing id, see this section's own note on why.",
    confidence="code_verified")
put(304, "vehicle.mobile_gun.detailed.01", "vehicle",
    "confirmed 2026-09-08: actually an MSV body part (document 38), not a standalone small "
    "vehicle -- kept under its existing id, see this section's own note on why.",
    confidence="code_verified")

_HELI_NOTE = ("real HELI vehicle part, confirmed 2026-09-08 by walking RFIRE.BIN's own "
              "vehicle-type descriptor #3 (see tools/data/vehicle_type_parts.json, document "
              "39) -- corrects a flat category error (several of these were classified as "
              "character/marker cels), not a refinement of a plausible guess. This is Return "
              "Fire's best-known vehicle and, until now, this project had never located any "
              "real part of it at all (PORTING_PLAN.md section 4 item 12).")
put(524, "vehicle.heli.part.01", "vehicle", _HELI_NOTE, confidence="code_verified")
put(529, "vehicle.heli.part.02", "vehicle", _HELI_NOTE, confidence="code_verified")
put(564, "vehicle.heli.part.03", "vehicle", _HELI_NOTE, confidence="code_verified")
put(539, "vehicle.heli.part.04", "vehicle", _HELI_NOTE, confidence="code_verified")
put(544, "vehicle.heli.part.05", "vehicle", _HELI_NOTE, confidence="code_verified")
put(574, "vehicle.heli.part.06", "vehicle", _HELI_NOTE, confidence="code_verified")
put(549, "vehicle.heli.part.07", "vehicle", _HELI_NOTE, confidence="code_verified")
put(554, "vehicle.heli.part.08", "vehicle", _HELI_NOTE, confidence="code_verified")
put(534, "vehicle.heli.part.09", "vehicle", _HELI_NOTE, confidence="code_verified")
put(569, "vehicle.heli.part.10", "vehicle", _HELI_NOTE, confidence="code_verified")
put(559, "vehicle.heli.part.11", "vehicle", _HELI_NOTE, confidence="code_verified")

# The Tank's own 10 already-correctly-categorized cels (6 from document 37's main text, 4 more
# from document 38) upgraded from "visual_group" to "code_verified" -- same real code trace,
# just recording that the category/id were already right, only the confidence tier was stale.
_TANK_VERIFIED_NOTE = ("category/id were already correct -- upgraded from visual_group to "
                       "code_verified 2026-09-08 (document 38) since this cel is now proven, "
                       "not guessed, to be a real Tank part.")
put(167, "vehicle.hovercraft.hull.01", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(172, "vehicle.hovercraft.hull.04", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(177, "vehicle.hovercraft.hull.07", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(182, "vehicle.hovercraft.track.01", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(187, "vehicle.hovercraft.hull.10", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(192, "vehicle.hovercraft.hull.12", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(197, "vehicle.hovercraft.hull.14", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(202, "vehicle.hovercraft.hull.16", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(207, "vehicle.hovercraft.hull.18", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")
put(212, "vehicle.hovercraft.wheel_hub.01", "vehicle", _TANK_VERIFIED_NOTE, confidence="code_verified")

# The ~30 coastal-decoration cels (document 35/36's coastal catalogue, tools/data/
# coastal_decorations.json) whose category was already "decoration" -- upgraded the same way,
# same reasoning: real code proves these are decoration parts, not just a visual guess anymore.
_DECORATION_VERIFIED_NOTE = ("category/id were already correct -- upgraded from visual/"
                             "visual_group to code_verified 2026-09-08 (document 38) since "
                             "tools/data/coastal_decorations.json proves this cel is a real "
                             "coastal-decoration part, not a guess.")
with open(REGISTRY_JSON) as _f:
    _on_disk_cels = json.load(_f)["cels"]
for _cel in (112, 113, 114, 115, 116, 117, 120, 121, 122, 124, 135, 136, 139, 140, 143, 144,
             145, 147, 154, 155, 156, 157, 158, 159, 160, 161, 162, 1001, 1003, 1025, 1937):
    # These ids were seeded by classify_batch1-3.py, not this file (ENTRIES only holds this
    # file's own put()/seq() calls) -- read the CURRENT on-disk id/category for each rather
    # than re-typing 30 ids by hand and risking a transcription mismatch that would silently
    # rename instead of just re-confirming.
    _existing = _on_disk_cels.get(str(_cel))
    if _existing is None:
        raise ValueError(f"cel {_cel} not already in the on-disk registry -- can't upgrade its "
                          f"confidence without knowing its current id/category")
    put(_cel, _existing["id"], _existing["category"], _DECORATION_VERIFIED_NOTE,
        confidence="code_verified")

# 4 more coastal-decoration cels this same audit found classified under a category that is
# *structurally* incompatible with being a decoration part, not just a plausible-either-way
# naming choice (unlike the ~100 structure/prop/marker/effect cels this audit deliberately left
# alone -- see document 38's own discussion of that distinction): "ui" cels are HUD overlays,
# never world-space geometry, and "pickup" cels are collectible objects with their own spawn/
# pickup logic, never a static part of something else. Both roles are mutually exclusive with
# "this cel is one immovable part of a decoration object", regardless of what the cel looks
# like -- confirmed by a direct atlas crop for each, same as the rest of this file's fixes.
put(125, "decoration.wreath_ring.01", "decoration",
    "corrected 2026-09-08 (document 38): was 'ui.radar.icon.01', but real code (coastal "
    "decoration 83) proves it's a world-space decoration part, not a HUD overlay -- those are "
    "mutually exclusive rendering paths. Direct atlas crop shows a green/gold ring with a tan "
    "centre -- read as a wreath or life-preserver-like ring shape, not a radar screen.",
    confidence="code_verified")
put(898, "decoration.arch_trim.01", "decoration",
    "corrected 2026-09-08 (document 38): was 'pickup.star.01', but real code (coastal "
    "decoration 47/48) proves it's a static decoration part, not a collectible. Direct atlas "
    "crop shows a small brown curved/arched shape (16x8px), not a star; exact identity beyond "
    "'small curved architectural trim piece' is unconfirmed.",
    confidence="code_verified")
put(900, "effect.blend_mask.01", "effect",
    "corrected 2026-09-08 (document 38): was 'pickup.star.03', but the atlas's own metadata "
    "says kind=effect_mask (a blend layer, not a drawable icon) -- consistent with cel "
    "1043/1061 (effect.shadow.hard.032/034), which the same audit found are also real "
    "decoration parts despite being masks, not objects. Real code (coastal decoration 47/48) "
    "proves it's used as a decoration part; 'pickup' was never plausible for a blend mask.",
    confidence="code_verified")
put(901, "decoration.splatter_red.01", "decoration",
    "corrected 2026-09-08 (document 38): was 'pickup.star.04', but real code (coastal "
    "decoration 64) proves it's a static decoration part, not a collectible. Direct atlas crop "
    "shows a red/brown starburst-like splatter shape, not a clean pickup-style star icon; "
    "exact identity unconfirmed.",
    confidence="code_verified")


def main():
    with open(REGISTRY_JSON) as f:
        registry = json.load(f)
    seen_ids = {v["id"]: int(k) for k, v in registry["cels"].items() if int(k) not in ENTRIES}
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
