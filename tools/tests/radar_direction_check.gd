# The radar direction indicator / cursor (document 108's third addendum): FUN_004122d0's tail bearing from the player's
# own base (vehicle+0x5c) toward the nearest live enemy, quantized to 8 sectors (0-7), gated by a dead-zone rectangle
# (record+0x2ac, sector 8 = "no clear direction, draw the cel uncropped") and by record+0x298 (nonzero for Tank/MSV/Heli,
# zero for the Jeep, which has no radar at all). -1 means no indicator (no live enemy, or no cursor data for this type). Run:
#   godot --headless --path . --script tools/tests/radar_direction_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	check("player starts as the Tank (this test's expected setup)", mc.vehicle.vehicle_type == 0)
	check("RFMAP001 has no enemies at setup -- this test adds its own", mc.enemy_vehicles.is_empty())

	check("no live enemy at all -> no indicator", mc._compute_direction_sector() == -1)

	var enemy := EnemyVehicle.new()
	enemy.pack_path = "res://packs/original_pc"
	root.add_child(enemy)
	enemy.setup(pack)
	mc.enemy_vehicles.append(enemy)

	var base := mc._player_spawn_px
	var dz: Array = pack.hud_panels["panels"]["0"]["slot9"]["cursor"]["dead_zone"]

	enemy.position = base
	check("enemy sitting on the player's own base -> dead zone (sector 8)", mc._compute_direction_sector() == 8)

	enemy.alive = false
	check("the only enemy is dead -> no indicator", mc._compute_direction_sector() == -1)
	enemy.alive = true

	enemy.position = base + Vector2(dz[2] + 500.0, 0)
	check("due \"east\" of the base, well outside the dead zone -> sector 0", mc._compute_direction_sector() == 0)

	enemy.position = base + Vector2(0, dz[3] + 500.0)
	check("90 degrees around (screen-down) -> sector 2", mc._compute_direction_sector() == 2)

	enemy.position = base + Vector2(dz[0] - 500.0, 0)
	check("180 degrees around (screen-left) -> sector 4", mc._compute_direction_sector() == 4)

	enemy.position = base + Vector2(0, dz[1] - 500.0)
	check("270 degrees around (screen-up) -> sector 6", mc._compute_direction_sector() == 6)

	enemy.position = base + Vector2(dz[2] + 500.0, 0)   # back to due "east", sector 0
	var far := EnemyVehicle.new()
	far.pack_path = "res://packs/original_pc"
	root.add_child(far)
	far.setup(pack)
	far.position = base + Vector2(0, dz[3] + 5000.0)   # much farther away, a DIFFERENT bearing (sector 2)
	mc.enemy_vehicles.append(far)
	check("with two live enemies, the NEARER one's bearing wins, not the farther one's", mc._compute_direction_sector() == 0)

	var jeep_s9: Dictionary = pack.hud_panels["panels"]["1"]["slot9"]
	check("the Jeep's own panel has no cursor data at all (kind 8, the compass, not kind 6)", not jeep_s9.has("cursor"))

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
