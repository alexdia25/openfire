# Issue #68 / wiki document 112: the submarine is the map-edge guard. On the real pack: the guard table and the type-10 homing
# numbers came through the importer, only the Heli carries the trigger flag, and a Heli sent past the map's edge on a real level
# gets the whole traced cycle (hunt 240 ticks, rise, aim 180 ticks, one homing rocket, a kill, the dive, the removal). Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/edge_guard_pack_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var eg := pack.edge_guard
	check("the pack has the guard table with 25 frames", eg.get("frames", []).size() == 25 and eg["frames"][0] == "vehicle.submarine.01" and eg["frames"][24] == "vehicle.submarine.25")
	check("every frame is a real sprite", eg["frames"].all(func(id): return not pack.get_sprite(String(id)).is_empty()))
	check("traced timings: 240 hunt ticks, 180 aim ticks, rocket type 10", int(eg["hunt_ticks"]) == 240 and int(eg["aim_ticks"]) == 180 and int(eg["projectile"]) == 10)
	var t10: Dictionary = pack.projectile_types[10]
	check("projectile type 10 is the 400-damage homing rocket", float(t10["damage"]) == 400.0 and t10.has("homing") and not pack.projectile_types[9].has("homing"))
	check("the rocket's launch sound and smoke are real pack entries", t10.get("sound", "") == "LargeMissle" and pack.audio.has("LargeMissle")
			and not pack.get_explosion(String(t10["homing"].get("smoke_record", ""))).is_empty())
	check("the off-map tile is tile 2, water_open.02, 12 tiles deep", int(pack.off_map.get("art", -1)) == 2 and int(pack.off_map.get("margin_tiles", 0)) == 12
			and pack.get_tile_sprite_id(2) == "terrain.ground.water_open.02")
	var flagged := []
	for i in pack.vehicle_order.size():
		var v := Vehicle.new()
		v.pack = pack
		v.vehicle_type = i
		if v.triggers_edge_guard():
			flagged.append(i)
		v.free()
	check("only the Heli (type 3) triggers it", flagged == [3], str(flagged))

	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var v := mc.vehicle
	v.set_vehicle_type(3)
	v.docked = false
	v.frozen = false
	v.z = 50.0
	var edge := level.width * float(pack.tile_size_px)
	var dt := 1.0 / Vehicle.TICK_HZ
	v.position = Vector2(-80.0, 600.0)   # 80 units past the west edge, at altitude
	var created_at := -1
	var launched_at := -1
	var killed_at := -1
	var max_frame := 0
	for i in 2000:
		for q in mc._projectiles:
			if is_instance_valid(q) and not q.is_queued_for_deletion():
				q._process(dt)
		mc._process(dt)
		if created_at < 0 and mc.edge_guard != null:
			created_at = i
		if mc.edge_guard != null:
			max_frame = maxi(max_frame, mc.edge_guard.shown_frame())
		if launched_at < 0 and not mc._projectiles.is_empty():
			launched_at = i
		if killed_at < 0 and not v.alive:
			killed_at = i
			break
	check("the guard appears as soon as the Heli is 80 units out", created_at == 0, str(created_at))
	check("it rises through all the frames up to the loop", max_frame >= 23, str(max_frame))
	check("the rocket is launched after hunt + rise + aim (about 520 ticks)", launched_at >= 500 and launched_at <= 540, str(launched_at))
	check("and it kills the Heli (hit points %s, damage 400)" % v.max_hp, killed_at > launched_at, "launched %d, killed %d" % [launched_at, killed_at])
	check("the music's Sub flag was on while it lived", mc.submarine_present)
	quit(fails)
