# The Heli's ground shadow (issue #26, wiki document 120): the pack's `shadow` table (Heli only) and what VehicleShadow3D draws for it: two body layers
# and no rotor shadow in the start-up (mode 4), the tail pulled in by 18 x (1 - progress); one body layer and a wide rotor bar once the rotor's whole
# speed is 4 or more; the offset 0.332 x height and -0.5 x height from the vehicle. Needs the real pack. Run:
#   godot --headless --path . --script tools/tests/heli_shadow_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	for t in 3:
		_check(not pack.vehicle_def(t).has("shadow"), "type %d casts no shadow" % t)
	var cfg: Dictionary = pack.vehicle_def(3).get("shadow", {})
	_check(not cfg.is_empty() and is_equal_approx(float(cfg["offset_per_height"][0]), 0x55 * 256 / 65536.0) and float(cfg["offset_per_height"][1]) == -0.5, "the Heli's shadow sits at x + 0.332 z, y - 0.5 z")
	_check(cfg["alpha"] == 5.0 / 32.0 and cfg["body"]["sprite"] == "effect.shadow.hard.heli_body" and cfg["rotor"]["sprites"].size() == 2, "translucent 5/32, cel 579 for the body, two cels for the rotor bar")
	var root := Node3D.new()
	get_root().add_child(root)
	var v := Vehicle.new()
	v.setup(pack)
	v.set_vehicle_type(3)
	v.position = Vector2(100.0, 100.0)
	v.z = 40.0
	var sh := VehicleShadow3D.new()
	root.add_child(sh)
	sh.setup(v, pack)
	v.heli_spinup_stage = 1
	v._heli_spinup_progress = 0.5
	sh._process(0.016)
	_check(sh.visible and is_equal_approx(sh.position.x, 100.0 + 0.33203125 * 40.0) and is_equal_approx(sh.position.z, 100.0 - 20.0), "the shadow is offset from the Heli by its height")
	_check(sh._meshes.size() == 2, "in the start-up: two body layers, no rotor shadow (%d)" % sh._meshes.size())
	v.heli_spinup_stage = 0
	v.heli_landing_gear_progress = 1.0
	v.rotor_speed_steps = 4.0
	sh._process(0.016)
	_check(sh._meshes.size() == 3, "at full rotor speed: one body layer and the two rotor cels (%d)" % sh._meshes.size())
	v.rotor_speed_steps = 2.5
	sh._process(0.016)
	_check(sh._meshes.size() == 4, "below speed 4: two body layers and the rotor bar (%d)" % sh._meshes.size())
	v.alive = false
	sh._process(0.016)
	_check(not sh.visible, "a dead vehicle casts none")
	v.free()
	print("heli_shadow_check: %d failures" % _failures)
	quit(_failures)
