# Issue #75 / wiki documents 113 and 114: the gun turrets on the real pack. The table came through the importer (the head's five quads are real
# sprites, ids 49 and 50), the levels have turret tiles (level 1 none, level 2 sixty, 200 of 204 in all), a tile's facing is the traced
# 16 x 16 block, and in RFMAP002 a vehicle driven up to a hostile turret tile wakes it, is tracked, and is shot at with the tracer and the
# missile; shells that hit the tile destroy it and the object with it. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/turret_pack_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _turret_tiles(level: LevelData) -> Array:
	var out := []
	for e in level.decorations:
		if int(e["coastal_id"]) == 49 or int(e["coastal_id"]) == 50:
			out.append(e)
	return out


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var t := pack.turret
	check("the pack has the turret table", not t.is_empty() and t["head"].size() == 5 and t["tiles"].size() == 2)
	var real := true
	for part in t["head"]:
		for k in 4:
			real = real and not pack.get_sprite(String(part["variant_sprite_ids"][k])).is_empty()
	check("every head quad and its four team variants are real sprites", real)
	check("traced numbers: 70 degrees/s, range 192, 60 ticks, types 3 and 4", absf(float(t["turn_steps_per_tick"]) * 5.625 * 62.5 - 70.0) < 0.5
			and float(t["range"]) == 192.0 and int(t["cooldown_ticks"]) == 60 and int(t["projectiles"][0]) == 3 and int(t["projectiles"][1]) == 4)
	check("the muzzle heights are 24.5 and 29.5", float(t["tiles"]["49"]["muzzle"][2]) == 24.5 and float(t["tiles"]["50"]["muzzle"][2]) == 29.5)

	var l1 := LevelData.new()
	assert(l1.load_from("res://packs/original_pc/levels/RFMAP001"))
	var l2 := LevelData.new()
	assert(l2.load_from("res://packs/original_pc/levels/RFMAP002"))
	check("level 1 has no turret tiles, level 2 has 60", _turret_tiles(l1).size() == 0 and _turret_tiles(l2).size() == 60, str(_turret_tiles(l2).size()))
	var f := l2.facing_at(41, 35)
	check("a tile's facing is a heading step and a pitch of at most 3 steps", f.x >= 0.0 and f.x < 64.0 and absf(f.y) <= 3.0, str(f))

	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, l2, "res://packs/original_pc", root)
	var woke := []
	var shots := []
	mc.turret_woke.connect(func(tu): woke.append(tu))
	mc.projectile_spawned.connect(func(p): shots.append(p))
	var v := mc.vehicle
	v.docked = false
	v.frozen = false
	var tile := Vector2i(45, 44)   # a team 1 turret tile of id 49
	var e := {}
	for d in l2.decorations:
		if int(d["x"]) == tile.x and int(d["y"]) == tile.y:
			e = d
	check("RFMAP002 has a hostile turret tile at (45, 44)", int(e.get("coastal_id", 0)) == 49 and int(e.get("variant", 0)) == 1 and v.player_index() == 0)
	v.position = (Vector2(tile) + Vector2(0.5, 0.5)) * 32.0 + Vector2(0.0, 120.0)   # 120 units south of it
	mc._update_turrets(1.0 / 62.5)
	check("a vehicle in view wakes it (and its neighbours)", mc.turrets.has(tile) and woke.size() >= 1, str(woke.size()))
	check("none wakes beyond the extent", woke.all(func(tu): return absf(tu.position.x - v.position.x) <= 288.0 and absf(tu.position.y - v.position.y) <= 288.0))
	for i in 900:
		mc._update_turrets(1.0 / 62.5)
	var tu: Turret = mc.turrets[tile]
	var want := Soldier.heading_to(tu.position, v.position)
	check("it is turned to the vehicle (heading %d, wanted %d)" % [tu.draw_heading(), want], tu.heading == float(want))
	check("it has shot at it with both types", shots.any(func(p): return p.type_id == 3) and shots.any(func(p): return p.type_id == 4), str(shots.size()))
	var hits_before := v.hp
	# the shells fly in the real world (a few seconds of frames) and damage the vehicle when they hit it
	for p in shots:
		if is_instance_valid(p):
			p.queue_free()
	# shooting the tile: five 1.0 hits destroy it and the object goes with it
	for i in 4:
		mc._damage_tile_amount(tile, 49, 1.0)
	check("four hits leave it standing", mc.turrets.has(tile))
	mc._damage_tile_amount(tile, 49, 1.0)
	check("the fifth destroys the tile and removes the object", not mc.turrets.has(tile))

	print("turret_pack_check: %s" % ("all ok" if fails == 0 else "%d FAILED" % fails))
	quit(fails)
