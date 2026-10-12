# Issue #76 / wiki documents 115 and 130: the Drone on the real pack. The table came through the importer (the draw descriptor's fifteen parts are real
# sprites, the team variants too, the shadow's cel, the radar blip's colours), the budget follows the level, a vehicle that stays on one tile for 360 ticks has
# a Drone sent against it from the border of the rectangle round it, the Drone flies at the vehicle and strafes it with the pitched pair of guns in turn, a
# hit of 1.0 or more kills it (explosion, flying pieces that carry its velocity), a lighter one does not, and hostile turrets in view keep it away. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/drone_pack_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var t := pack.drone
	check("the pack has the Drone table", not t.is_empty() and t["art"]["parts"].size() == 15 and t["art"]["orders"].size() == 8)
	var real := true
	for part in t["art"]["parts"]:
		real = real and not pack.get_sprite(String(part["sprite_id"])).is_empty()
		if int(part["flags"]) & 8:
			for k in 2:
				real = real and not pack.get_sprite(String(part["variant_sprite_ids"][k])).is_empty()
	check("every part and its two team variants are real sprites", real)
	check("the shadow is a real sprite", not pack.get_sprite(String(t["shadow"]["sprite_id"])).is_empty())
	check("the radar has the blip and the colours' RGB", pack.radar_data.has("drone_blip") and pack.radar_data["rgb"].has("205") and pack.radar_data["rgb"].has("104"))
	check("traced numbers: 360 ticks, 3 turrets, 50 units, speed 1.5, window 5 degrees, types 11 and 3", int(t["camp"]["ticks"]) == 360 and int(t["camp"]["hostile_turret_limit"]) == 3
			and float(t["spawn"]["z"]) == 50.0 and float(t["flight"]["speed_cap"]) == 1.5 and absf(float(t["gun"]["aim_window_steps"]) * 5.625 - 5.0) < 0.01
			and int(t["gun"]["projectile"]) == 11 and int(t["gun"]["probe"]) == 3 and int(t["gun"]["interval_ticks"]) == 10)
	check("the death explosion record and the Heli's piece rows exist", not pack.get_explosion("0x444c80").is_empty() and pack.debris["rows"]["high"].has("1"))

	var l2 := LevelData.new()
	assert(l2.load_from("res://packs/original_pc/levels/RFMAP002"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, l2, "res://packs/original_pc", root)
	check("the budget: unset takes the difficulty's table, a given unk4 wins, never above 5", _caps(mc, 0, 255) == 0 and _caps(mc, 3, 255) == 1 and _caps(mc, 5, 255) == 2
			and _caps(mc, 8, 255) == 3 and _caps(mc, 8, 2) == 2 and _caps(mc, 0, 9) == 5)

	mc.level.levl_value = 5   # two Drones a side
	mc.level.vehicle_params["unk4"] = 255
	var spawned := []
	var shots := []
	var highs := []
	var pieces := []
	mc.drone_created.connect(func(d): spawned.append(d))
	mc.projectile_spawned.connect(func(p): shots.append(p))
	mc.impact_effect_high.connect(func(rec, at, h): highs.append([rec, at, h]))
	mc.debris_created.connect(func(p): pieces.append(p))
	var v := mc.vehicle
	v.docked = false
	v.frozen = false
	v.position = Vector2(1000.0, 1000.0)
	for i in 300:
		mc._update_drones(1.0 / 62.5)
	check("300 ticks standing still: no Drone yet", spawned.is_empty())
	for i in 70:
		mc._update_drones(1.0 / 62.5)
	check("past 360 ticks on one tile: one Drone", spawned.size() == 1, str(spawned.size()))
	var d: Drone = spawned[0]
	var off := d.position - v.position
	check("it is for the other side, 50 units up, on the Tank's 512-unit border", d.team == 1 and d.z == 50.0 and (absf(absf(off.x) - 512.0) < 6.0 or absf(absf(off.y) - 512.0) < 6.0)
			and absf(off.x) <= 518.0 and absf(off.y) <= 518.0, str(off))
	for i in 700:
		mc._update_drones(1.0 / 62.5)
	check("it reached full speed 1.5", absf(d.speed - 1.5) < 1e-6)
	# any Drone's shots count: the camp timer fires again at tick 722, inside this window, and whether that second Drone has fired yet depends on its random lane
	var bad := shots.filter(func(p): return p.type_id != 11 or not spawned.has(p.shooter))
	check("it has strafed with type 11 only, from both guns in turn", shots.size() > 0 and bad.is_empty(), "%d shots, %d bad %s" % [shots.size(), bad.size(), str(bad.map(func(p): return [p.type_id, p.shooter]))])
	var xs := []
	for p in shots:
		xs.append(p.global_position)
	check("it stays alive, over 80 units off or in a pass", not d.finished and d.position.distance_to(v.position) < 700.0, str(d.position.distance_to(v.position)))

	# the timer restarts on a tile change; the budget caps; hostile turrets in view keep it away
	check("another 360 ticks standing: a second Drone (the budget is 2)", spawned.size() == 2, str(spawned.size()))
	for i in 800:
		mc._update_drones(1.0 / 62.5)
	check("the side's pool is empty: no third", spawned.size() == 2 and mc.drones.size() == 2)

	# a hit of 0.95 is ignored, 1.0 kills: explosion up where it was, one piece for each part of class 1 or 2, carrying the velocity
	var p := Projectile.new()
	p.damage = 0.95
	p.z = d.z
	check("a hit of 0.95 is ignored", not mc._shell_hits_drone(p, d.position - Vector2(20, 0), d.position) and mc.drones.has(d))
	p.damage = 1.0
	p.z = d.z + 1.0
	check("a hit of 1.0 passes outside the box", not mc._shell_hits_drone(p, d.position + Vector2(40, 0), d.position + Vector2(60, 0)))
	var vel := d.vel
	check("a hit of 1.0 kills it", mc._shell_hits_drone(p, d.position - Vector2(20, 0), d.position) and not mc.drones.has(d) and d.killed)
	var rec_ok := highs.any(func(h): return h[0] == "0x444c80" and absf(float(h[2]) - 50.0) < 1.0)
	check("the death explosion plays 50 units up", rec_ok)
	var want_parts := 0
	for part in pack.drone["art"]["parts"]:
		if ((int(part["flags"]) >> 8) & 3) in [1, 2]:
			want_parts += 1
	check("one flying piece for each of the %d parts of class 1 or 2" % want_parts, pieces.size() == want_parts)
	check("the pieces start with the Drone's velocity", pieces.all(func(q): return q.drift == vel))
	for i in 200:
		mc._update_debris(1.0 / 62.5)
	check("the pieces finish", mc.debris.is_empty())
	p.free()

	# hostile turrets in view: three of them keep Drones away
	for k in 3:
		var tile := Vector2i(70 + k, 70)
		var tu := Turret.new(pack.turret, tile, 49, 1, Vector2(tile) * 32.0, Vector2.ZERO, v)
		tu.age = 0.0
		mc.turrets[tile] = tu
	var before := spawned.size()
	for i in 400:
		mc._update_drones(1.0 / 62.5)
	check("three hostile turrets in view: no Drone", spawned.size() == before and mc._hostile_turrets_in_view(v) == 3)
	mc.turrets.clear()
	for i in 400:
		mc._update_drones(1.0 / 62.5)
	check("none in view: one comes", spawned.size() == before + 1)

	# a target that is gone: it drifts and is removed 60 ticks after it was last drawn
	var d2: Drone = spawned[spawned.size() - 1]
	v.alive = false
	for i in 5:
		mc._update_drones(1.0 / 62.5)
	check("the vehicle gone: the Drone drifts", d2.state == Drone.State.DRIFT)
	for i in 600:
		mc._update_drones(1.0 / 62.5)
	check("and goes", not mc.drones.has(d2) and d2.finished and not d2.killed)

	print("drone_pack_check: ", "all ok" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails > 0 else 0)


func _caps(mc: MatchController, levl: int, unk4: int) -> int:
	mc.level.levl_value = levl
	mc.level.vehicle_params["unk4"] = unk4
	return mc._drone_cap()
