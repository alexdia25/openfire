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

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")

ENTRIES = {}


def put(idx, id_, category, note=None, confidence="visual_group"):
    ENTRIES[idx] = {"id": id_, "category": category, "confidence": confidence, **({"note": note} if note else {})}


def seq(indices, id_fmt, category, note=None, start=1):
    for n, idx in enumerate(indices, start=start):
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
seq([320, 321], "prop.debris_faint.{n:02d}", "prop", start=3)
seq([322], "prop.fuel_canister.single.01", "prop", "single vertical capsule, blue body tan cap")
seq([323], "prop.fuel_canister.cluster_red.01", "prop", "bundled vertical capsules, red/blue")
seq([324], "prop.fuel_canister.cluster_blue.01", "prop", "bundled vertical capsules, blue/tan")
seq([226], "prop.debris_faint.{n:02d}", "prop", start=5)
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
    "prop.debris_faint.{n:02d}", "prop", start=6)
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
seq([470, 505, 506, 507, 508, 515, 523, 525], "prop.debris_faint.{n:02d}", "prop", start=22)
seq([509, 510, 511], "effect.explosion_large.{n:02d}", "effect", start=10,
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
seq([575, 576, 577], "effect.beam.{n:02d}", "effect", start=5)
seq([580, 581], "prop.brick_red.{n:02d}", "prop")
seq([584], "prop.hook_pipe.tan.01", "prop", "curved pipe/hook shape")
seq([585], "prop.hook_pipe.cyan.01", "prop")
seq([588], "prop.bar_dark_red.01", "prop")
seq([606], "prop.spike_ball.01", "prop", "red spiky ball, possibly a mine")
seq([607], "prop.panel_solid.tan.01", "prop")
seq([608], "prop.panel_solid.cyan.01", "prop")
seq([610, 611], "prop.diamond_pattern.{n:02d}", "prop", "red/orange diamond-checker strip")
seq([614, 622, 623], "vehicle.hovercraft.wheel_hub.{n:02d}", "vehicle", start=4)
seq([615, 624], "prop.dome_small.tan.{n:02d}", "prop", "small mushroom/dome shape, red top")
seq([625], "prop.dome_small.cyan.01", "prop")
seq([609], "prop.hook_claw.red.01", "prop", "small claw/hook shape, yellow tip")
seq([613], "prop.hook_claw.cyan.01", "prop")
seq([616, 617], "prop.riveted_panel_red.{n:02d}", "prop", "large mottled red panel with rivet-like dots")
seq([618], "prop.panel_solid.tan.02", "prop", "large solid tan panel")
seq([619], "prop.panel_solid.cyan.02", "prop", "large solid cyan panel")


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
