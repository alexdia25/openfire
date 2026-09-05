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
    """tan vs blue, by mean RGB of an cel's non-transparent pixels -- used where a
    long run of near-identical frames alternates between the two known team hues
    (see the 655-754 trooper-run family) and eyeballing a downscaled contact sheet
    risks mis-transcribing which frame is which colour."""
    c = atlas_cels[idx]
    crop = atlas_img.crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
    pixels = [p for p in crop.getdata() if p[3] > 0]
    r = sum(p[0] for p in pixels) / len(pixels)
    b = sum(p[2] for p in pixels) / len(pixels)
    return "blue" if b > r else "tan"


def put(idx, id_, category, note=None, confidence="visual_group"):
    ENTRIES[idx] = {"id": id_, "category": category, "confidence": confidence, **({"note": note} if note else {})}


_family_next = {}  # id-family prefix -> next free sequence number, lazily seeded


def _ensure_seeded(family):
    if family not in _family_next:
        with open(REGISTRY_JSON) as f:
            existing = json.load(f)["cels"]
        used = [int(v["id"][len(family):]) for v in existing.values()
                 if v["id"].startswith(family) and v["id"][len(family):].isdigit()]
        _family_next[family] = (max(used) + 1) if used else 1


def seq(indices, id_fmt, category, note=None, start=None):
    """start is an optional manual override; by default the next number for this
    id family is looked up from the registry + entries assigned so far this run,
    so batches never need to hand-track collisions across sections."""
    family = id_fmt.split("{n")[0]
    _ensure_seeded(family)
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
seq([232, 233, 234, 235, 236, 237, 238, 239, 240], "vehicle.hovercraft.rotation.cyan.{n:02d}", "vehicle")
seq(list(range(246, 258)), "prop.stalk_orb.rotation.tan.{n:02d}", "prop",
    "rotating ball-on-a-stalk shape, identity unconfirmed (antenna/buoy/sensor)")
seq(list(range(258, 269)), "prop.stalk_orb.rotation.green.{n:02d}", "prop", "same prop, green-tinted variant")
seq([269, 270, 271, 272], "prop.stalk_orb.rotation.cyan.{n:02d}", "prop", "same prop, thin/distant cyan frames")
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
seq([342, 343, 344, 345, 346, 347], "prop.sentry_turret.teal.{n:02d}", "prop",
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
seq([477, 478, 479, 480, 481, 482, 483, 484], "character.trooper_head.rotation.teal.{n:02d}", "character")
seq(list(range(491, 505)), "character.trooper_head.rotation.teal_alt.{n:02d}", "character",
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
# blue team colours -- almost certainly the on-foot infantry unit (Return Fire's
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

_run_counts = {"tan": 0, "blue": 0}
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
seq([1075], "decoration.foliage.bush_blue.12", "decoration")


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
