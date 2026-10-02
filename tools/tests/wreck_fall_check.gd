# The wreck sequence on the real pack (documents 87 and 118, issues #29 and #70): a vehicle's death emits a value snapshot (`Vehicle.wrecked`) immune to
# a same-frame respawn resetting the same node's fields; the pack carries the traced Destroyed Vehicle numbers and the three death explosion records; a
# Wreck made from the snapshot falls as the original's does (gravity 0x51e a tick, 1.0 a tick at most), draws the dying vehicle's own body while it
# does, and a Heli hit but not killed is pushed by FUN_0040e830's reaction. Needs the real pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/wreck_fall_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var root := Node2D.new()
	get_root().add_child(root)

	var cfg: Dictionary = pack.vehicle_value(0, "wreck", {})
	_check(is_equal_approx(float(cfg.get("gravity", 0.0)), 0x51e / 65536.0) and float(cfg.get("terminal_velocity", 0.0)) == 1.0, "the pack has gravity 0x51e and the fall limit 1.0")
	_check(int(cfg.get("settle_ticks", 0)) == 8 and int(cfg.get("lifetime_ticks", 0)) == 720 and float(cfg.get("overkill_hp", 0.0)) == -40.0, "and the 8-tick wait, the 720-tick life, the -40 hit points")
	_check(is_equal_approx(float(pack.vehicle_value(3, "wreck.friction", 0.0)), 0x7ae / 65536.0) and is_equal_approx(float(cfg.get("friction", 0.0)), 0x1999 / 65536.0), "friction per type (record +0x25c): 0x1999, the Heli's 0x7ae")
	var records := []
	for t in 4:
		var r := String(pack.vehicle_value(t, "wreck.explosion", ""))
		records.append(r)
		_check(not pack.get_explosion(r).is_empty() and pack.get_explosion(r).get("parts", []).size() > 0, "type %d's death explosion %s is a record with parts" % [t, r])
	_check(records == ["0x444c80", "0x444d90", "0x444ea0", "0x444c80"], "the death explosions are table 0x4453d8's")
	_check(not pack.get_explosion("0x444ee8").is_empty() and not pack.get_explosion("0x444618").is_empty(), "the sinking and landing splash records exist")

	var v := Vehicle.new()
	root.add_child(v)
	v.setup(pack)
	var snapshots: Array = []
	v.wrecked.connect(func(info): snapshots.append(info))
	v.destroyed.connect(func(_v): v.respawn(Vector2(999.0, 999.0)))  # simulates match_controller's immediate respawn
	var death_pos := v.position
	var death_heading := v.heading_deg
	v.hp = 1.0
	v.take_damage(100.0)
	_check(v.alive and v.position == Vector2(999.0, 999.0), "the tank respawned")
	_check(snapshots[0]["position"] == death_pos and snapshots[0]["heading_deg"] == death_heading and snapshots[0]["z"] == 0.0, "the snapshot is unaffected by the respawn")
	_check(not snapshots[0]["fuel_out"] and snapshots[0]["hp"] < 0.0, "it says the tank was shot, not out of fuel")

	var tank := Wreck.new(snapshots[0], cfg, func(_p, _z): return 0)
	var tank_view := Wreck3D.new()
	root.add_child(tank_view)
	tank_view.setup(pack, tank)
	var tank_hull := 0
	for part in tank_view._body._parts:
		if not part["data"].has("modes"):   # the water pictures (issue #25) are drawn in their own views only
			tank_hull += 1
	_check(tank_view._body != null and tank_hull == 14, "the dying tank is drawn as its 14-part body")
	for i in 20:
		tank.tick(1.0)
	tank_view._process(0.016)
	_check(tank.mark and tank_view._decal.visible and not tank_view._ghost.alive, "and as the decal once it has settled")

	# a Heli shot down mid-flight
	v.set_vehicle_type(3)
	v.z = 60.0
	v.speed = 0.8 * Vehicle.TICK_HZ
	v.hp = 1.0
	v.take_damage(v.armor + 2.0)   # hit points -1: not the overkill below -40, which bursts an airborne wreck at once
	_check(snapshots[1]["z"] == 60.0 and is_equal_approx(snapshots[1]["speed"], 0.8), "the heli's snapshot has its height and speed (per tick)")
	var heli := Wreck.new(snapshots[1], pack.vehicle_value(3, "wreck", {}), func(_p, _z): return 0)
	var heli_view := Wreck3D.new()
	root.add_child(heli_view)
	heli_view.setup(pack, heli)
	_check(heli_view._body._parts.size() == 12, "the dying heli is drawn as its 12 body parts, without the rotor (%d)" % heli_view._body._parts.size())
	var lands := -1
	for i in 200:
		heli.tick(1.0)
		if lands < 0 and heli.z <= 0.0:
			lands = heli.age
	_check(lands >= 84 and lands <= 87, "from 60 units it lands after about 85 ticks (%d)" % lands)
	_check(heli.phase == Wreck.Phase.DECAL and heli.mark, "as the decal, and then it is a mark")
	heli_view._process(0.016)
	_check(heli_view._decal.visible and not heli_view._ghost.alive, "which Wreck3D shows")

	# the flying wreckage (issue #81): the pack's piece records, and the Heli's seven pieces
	_check(pack.debris["rows"]["high"] == {"1": "0x44a850", "2": "0x44a864"} and pack.debris["rows"]["low"] == {"1": "0x44a890", "2": "0x44a8a4"}, "the pack has the piece table rows")
	var rec: Dictionary = pack.debris["records"]["0x44a850"]
	_check(is_equal_approx(float(rec["rate"]), 0x2888 / 65536.0) and rec["duration"] == 19 and rec["ops"].size() == 8 and rec["frames"]["sprites"].size() == 8, "and record 0x44a850: rate 0x2888, 19 units, 8 ops, 8 burn-out frames")
	_check(not pack.debris["records"]["0x44a864"].has("frames") and is_equal_approx(float(pack.debris["records"]["0x44a890"]["rate"]), 0x5111 / 65536.0), "0x44a864 has no frames; the low row is faster")
	var made := 0
	for part in pack.vehicle_def(3)["render"]["parts"]:
		if ((int(part["flags"]) >> 8) & 3) in [1, 2]:
			made += 1
	_check(made == 7, "seven of the Heli's twelve body parts make a piece (flags 0x108 and 0x208); the tank, jeep and msv make none")
	for t in 3:
		for part in pack.vehicle_def(t)["render"]["parts"]:
			made += 1 if ((int(part["flags"]) >> 8) & 3) != 0 else 0
	_check(made == 7, "no ground vehicle part is marked")

	# the Heli's hit reaction on the real vehicle definition
	v.alive = true
	v.hp = 100.0
	v.heli_vel = Vector2.ZERO
	v.take_damage(10.0, 0.0)
	_check(v.heli_vel.length() >= 0.25 - 1e-6 and v.heli_vel.length() <= 0.75 + 1e-6 and v.heli_vel.x > 0.0, "a hit that leaves the heli alive pushes it along the hitter's heading")
	v.set_vehicle_type(0)
	v.hp = 100.0
	v.take_damage(10.0, 0.0)
	_check(v.alive and v.drive.get_script().resource_path.ends_with("ground_drive.gd"), "a tank takes the same hit without a reaction (its drive has none)")
	print("wreck_fall_check: %d failures" % _failures)
	quit(_failures)
