# The Jeep missile's target (FUN_00415b00, document 61; issue #25): an enemy vehicle below height 5.0 within 61.23 units; else the last tile that blocked
# the Jeep if it has hit points and is within range; else the last OBJECT of the other player that blocked it (state +0xa8, here a gate or a vehicle) if it is
# still the same live object, within range and no farther than that tile; else a random point ahead. Run:
#   godot --headless --path . --script tools/tests/missile_target_check.gd
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
	var tsz := float(pack.tile_size_px)
	var v: Vehicle = mc.vehicle
	v.set_vehicle_type(1)
	v.position = Vector2(60, 60) * tsz
	v.last_blocked_tile = Vector2i(-1, -1)
	v.last_touched = null

	# an enemy gate (the other player's colour) two tiles away
	var gate := Gate.new()
	gate.tile = Vector2i(61, 60)
	gate.variant = 1 - v.player_index()
	gate.centre = v.position + Vector2(40, 0)
	mc.gates[gate.tile] = gate
	v.last_touched = gate
	check("the last enemy object that blocked it, within range, is the target", mc._pick_missile_target(v) == gate.centre)

	gate.centre = v.position + Vector2(70, 0)
	var p := mc._pick_missile_target(v)
	check("...but not beyond 61.23 units (a random point ahead instead)", p != gate.centre)

	gate.centre = v.position + Vector2(40, 0)
	gate.variant = v.player_index()
	check("its own player's gate is not a target", mc._pick_missile_target(v) != gate.centre)
	gate.variant = 1 - v.player_index()

	gate.finished = true
	check("a gate that has gone (state +0xac no longer matches) is not a target", mc._pick_missile_target(v) != gate.centre)
	gate.finished = false

	# a tile with hit points that blocked it: the tile wins when it is nearer than the object
	var t := Vector2i(60, 60)
	var found := Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var c := Vector2i(60 + dx, 60 + dy)
			if level.get_coastal_id(c.x, c.y) != 0 and mc._tile_hp.get(c, mc._initial_tile_hp(c)) > 0 and found.x < 0:
				found = c
	if found.x >= 0:
		v.position = (Vector2(found) + Vector2(0.5, 0.5)) * tsz + Vector2(0, 20)
		v.last_blocked_tile = found
		gate.centre = v.position + Vector2(40, 0)
		var tile_centre := (Vector2(found) + Vector2(0.5, 0.5)) * tsz
		if pack.get_coastal_shapes(level.get_coastal_id(found.x, found.y)).get("jitter", false):
			tile_centre += level.jitter_at(found.x, found.y)
		check("the tile when it is nearer than the object", mc._pick_missile_target(v) == tile_centre)
		gate.centre = v.position + Vector2(10, 0)
		check("the object when it is no farther than the tile", mc._pick_missile_target(v) == gate.centre)
	else:
		check("(no coastal tile with hit points near the fixture: tile cases skipped)", true)

	# an enemy vehicle in the air is not the first rule's target
	v.last_blocked_tile = Vector2i(-1, -1)
	v.last_touched = null
	var enemy := Vehicle.new()
	enemy.team = "green" if v.team == "tan" else "tan"
	enemy.setup(pack)
	enemy.set_vehicle_type(0)
	enemy.alive = true
	enemy.position = v.position + Vector2(30, 0)
	root.add_child(enemy)
	mc.enemy_vehicles.append(enemy)
	check("an enemy vehicle on the ground within range is the target", mc._pick_missile_target(v) == enemy.position)
	enemy.z = 10.0
	check("...but not when it is above height 5 (a Heli in the air)", mc._pick_missile_target(v) != enemy.position)
	enemy.z = 0.0
	v.last_touched = enemy
	enemy.position = v.position + Vector2(100, 0)
	check("a vehicle that blocked it and has since gone out of range is no target", mc._pick_missile_target(v) != enemy.position)
	print("missile_target_check: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
