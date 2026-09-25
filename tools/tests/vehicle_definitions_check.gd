# Headless check for vehicle definitions (PORTING_PLAN.md 2.7.2, step 3): the four originals load from
# vehicles/<id>/vehicle.json in bay order; every table that moved out of the code into them still has the traced value
# the code used to hard-code (dock tolerance +0x254, death wait +0x260, created sound +0x240, the camera swoop table
# 0x4452c0, the wreck descriptors); the flat per-type view the older code reads matches tools/data/vehicle_types.json;
# and a mod can change one vehicle or add a new one on top without touching the originals. Run:
#   godot --headless --path . --script tools/tests/vehicle_definitions_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


class FiringVehicle extends Vehicle:
	func _wants_to_fire() -> bool:
		return true
	func _get_controls() -> Vector2:
		return Vector2(0.0, 1.0)


func _init() -> void:
	var p := Pack.new()
	_check(p.load_from("res://packs/original_pc"), "pack loads")
	_check(p.vehicle_order == ["rf.tank", "rf.jeep", "rf.msv", "rf.heli"], "the four originals in bay order: %s" % [p.vehicle_order])
	_check(p.vehicle_roster.map(func(e): return e["stock_key"]) == ["T", "J", "A", "H"], "roster stock letters T J A H")
	var col := func(path: String) -> Array: return range(4).map(func(i): return p.vehicle_value(i, path))
	_check(col.call("stats.dock_tolerance") == [4.0, 9.0, 4.0, 32.0], "dock tolerance, record +0x254")
	_check(col.call("stats.death_wait_ticks") == [120.0, 120.0, 120.0, 200.0], "death wait, record +0x260")   # JSON numbers load as floats
	_check(col.call("camera.swoop_height") == [-170.0, -170.0, -170.0, -100.0], "camera swoop height, table 0x4452c0")
	_check(col.call("events.on_create.sound") == [null, "JeepStart", null, "Servo"], "created sound, record +0x240")
	_check(p.vehicle_value(0, "events.on_create.descriptor") == "0x44b520" and p.vehicle_value(0, "events.on_create.loop") == "tread"
			and p.vehicle_value(0, "sounds.engine_loop.descriptor") == "0x44b520",
			"the Tank's created-sound descriptor 0x44b520 is its Tread engine loop (document 97)")
	_check(col.call("selector.script") == ["Tank", "Jeep", "MSV", "Heli"], "selector script names")
	_check(p.vehicle_value(3, "wreck.quads", []).size() == 1 and p.vehicle_value(0, "wreck.quads", []).size() == 3, "wreck quads per vehicle")

	# behaviour modules (step 4): every one a definition names exists, and every channel a module declares is a Vehicle field
	var probe := Vehicle.new()
	var modules_ok := true
	for i in 4:
		var d := p.vehicle_def(i)
		var names := [String(d["drive"].get("model", "ground")), String(d["aim"].get("model", "none")), String(d["water"].get("model", "hull_water"))]
		for w in d["weapons"].get("slots", []):
			names.append(String(w["handler"]))
		for n in names:
			if n == "none":
				continue
			var sc := VehicleModules.schema(n)
			if sc.is_empty():
				modules_ok = false
				print("   %s names unknown module %s" % [d["id"], n])
				continue
			for ch in sc.get("channels", []):
				if probe.get(String(ch)) == null and not String(ch) in ["position"]:
					modules_ok = false
					print("   module %s declares channel %s, not a Vehicle field" % [n, ch])
			for k in sc.get("params", {}):
				if not sc["params"][k].has("provenance"):
					modules_ok = false
					print("   module %s parameter %s has no provenance" % [n, k])
	probe.free()
	_check(modules_ok, "every named module exists; its channels are Vehicle fields; every parameter has a provenance")
	_check(VehicleModules.names_for_slot("weapon").size() == 5 and VehicleModules.names_for_slot("drive") == ["ground", "rotor"], "the module library by slot")

	# the flat view equals the traced table, field for field
	var traced: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/data/vehicle_types.json"))["types"]
	var same := true
	for t in 4:
		for f in ["hit_points", "armor", "fuel", "sink_depth", "max_forward_per_tick", "max_reverse_per_tick", "accel_per_tick2",
				"friction_per_tick2", "turn_steps_per_tick", "ammo", "weapon_cooldown_ticks", "shape"]:
			var want: Variant = traced[str(t)][f]
			var got: Variant = p.vehicle_types[str(t)][f]
			if f == "weapon_cooldown_ticks" or f == "ammo":
				want = Array(want).map(func(x): return float(x))
				got = Array(got).map(func(x): return float(x))
			if want != got:   # compared as values (a Dictionary's key order doesn't matter)
				same = false
				print("   type %d %s: %s vs %s" % [t, f, want, got])
	_check(same, "the per-type view matches the traced table")

	# a mod: changes the Jeep's dock tolerance only (a full definition with one field different), adds a new vehicle
	var mod := ProjectSettings.globalize_path("user://vehicle_definitions_check/mod")
	if DirAccess.dir_exists_absolute(mod):
		OS.move_to_trash(mod)
	PackWriter.write_json(mod.path_join("pack.json"), {"id": "defmod", "name": "definitions test", "base_pack": "original_pc"})
	var jeep: Dictionary = p.vehicle_def(1).duplicate(true)
	jeep["stats"]["dock_tolerance"] = 16.0
	PackWriter.write_json(mod.path_join("vehicles/rf.jeep/vehicle.json"), jeep)
	var hover: Dictionary = p.vehicle_def(0).duplicate(true)
	hover["id"] = "defmod.hovertank"
	hover["name"] = "Hovertank"
	hover["stats"]["hit_points"] = 30.0
	hover["drive"]["model"] = "rotor"   # recombined: the Tank's gun mount and cannon on the Heli's rotor drive
	PackWriter.write_json(mod.path_join("vehicles/defmod.hovertank/vehicle.json"), hover)
	var m := Pack.new()
	_check(m.load_from(mod), "mod loads")
	_check(m.vehicle_value(1, "stats.dock_tolerance") == 16.0 and m.vehicle_value(0, "stats.dock_tolerance") == 4.0, "the mod changes the Jeep only")
	_check(m.vehicle_index("defmod.hovertank") == 4 and m.vehicle_types["4"]["hit_points"] == 30.0, "a new vehicle gets the next index, after the roster")
	_check(m.vehicle_roster.size() == 4, "a new vehicle is not in the roster unless the mod puts it there")
	_check(p.vehicle_value(1, "stats.dock_tolerance") == 9.0, "the original pack is unaffected")

	# the recombined vehicle runs: the rotor start-up, then it climbs and fires its cannon
	var fly := FiringVehicle.new()
	fly.setup(m)
	fly.set_vehicle_type(m.vehicle_index("defmod.hovertank"))
	var shots := [0]
	fly.shot.connect(func(_s): shots[0] += 1)
	for t in 400:
		fly._process(1.0 / 62.5)
	_check(fly.drive.has_method("tick_startup") and fly.aim != null and fly.z > 10.0 and shots[0] > 0,
			"a flying tank (rotor drive + gun mount + cannon) climbs to %.1f and fires %d shots" % [fly.z, shots[0]])
	fly.free()

	print("vehicle_definitions_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
