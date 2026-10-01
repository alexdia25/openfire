# Headless check for the render descriptors (PORTING_PLAN.md 2.7.2, step 5): every moving part of the four vehicles -- the Tank's
# turret and barrel cluster, the Jeep's wheel strips and swim ring, the MSV's rack and canisters, the Heli's rotor and tilt -- is
# a binding in the vehicle definition's `render` block that game/vehicle_render_3d.gd evaluates against `Vehicle.channel()`.
# This is Return Fire's own data checked; the descriptor vocabulary itself, on a synthetic vehicle with no vehicle type
# anywhere, is openfire-engine's tests/render_descriptor_check.gd (issue #65). Run:
#   godot --headless --path . --script tools/tests/render_descriptor_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _made(pack: Pack, type: int) -> Array:   # [vehicle, renderer]
	var v := Vehicle.new()
	v.team = "tan"
	v.setup(pack)
	v.set_vehicle_type(type)
	var r := VehicleRender3D.new()
	get_root().add_child(r)
	r.setup(v, pack)
	return [v, r]


func _part(r: VehicleRender3D, cel: int, nth := 0) -> Dictionary:
	var n := 0
	for p in r._parts:
		if int(p["data"]["cel"]) == cel:
			if n == nth:
				return p
			n += 1
	return {}


func _near(a: Vector3, b: Vector3) -> bool:
	return a.distance_to(b) < 0.001


func _init() -> void:
	var pack := ModLoader.load_game_pack()

	# the channels each original vehicle's parts bind to, in the order the preview lists them
	var expected := [["turret_deg", "gun_elev_deg"], ["position_x", "swim_amount"], ["gun_elev_deg", "salvo_reload_remaining", "salvo_index"],
			["pitch_deg", "bank_deg", "rotor_speed_steps", "heli_spinup_progress"]]
	for t in 4:
		var used := VehicleRender3D.channels_used(pack.vehicle_def(t)["render"])
		_check(used == expected[t], "%s binds %s" % [pack.vehicle_def(t)["name"], used])
		var v := Vehicle.new()
		v.setup(pack)
		v.set_vehicle_type(t)
		var ok := true
		for c in used:
			ok = ok and is_finite(v.channel(String(c)))
		_check(ok, "%s: every channel it binds reads as a number" % pack.vehicle_def(t)["name"])
		v.free()

	# the Tank: the turret group turns with turret_deg; the barrel's tip and the muzzle ring are the rig R(elevation) * base + offset
	var m := _made(pack, 0)
	var v: Vehicle = m[0]
	var r: VehicleRender3D = m[1]
	v.turret_deg = 90.0
	r._process(0.0)
	_check(is_equal_approx(r._groups["turret"]["node"].rotation_degrees.y, -90.0), "the turret group follows turret_deg")
	# elevation 0: rig point 1 (the barrel tip) is base (0, -6.75, 2) + offset (0, -5.25, 7)
	var barrel := _part(r, 202)
	_check(_near(r._corners(barrel["data"], {})[2], Vector3(0.0, -12.0, 9.0)), "barrel tip at elevation 0 is base + offset: (0, -12, 9)")
	v.gun_elev_deg = 25.0
	var raised: Vector3 = r._corners(barrel["data"], {})[2]
	_check(raised.z > 9.0 + 2.0 and raised.y > -12.0 and is_equal_approx(raised.x, 0.0), "raising the gun lifts the tip (%s) and pulls it back" % raised)
	r._process(0.0)
	_check(r._parts[0]["key"] != null and r._groups.size() == 1 and r._parts.size() == 14, "six hull faces and eight turret parts, one group")
	r.free()
	v.free()

	# the Jeep: the wheel strip frame is the integer x position mod 4, the swim row the whole of swim * 8; the ring shows from row 4
	m = _made(pack, 1)
	v = m[0]
	r = m[1]
	var wheel := _part(r, 457, 0)
	for x in [0.2, 1.7, 2.5, 3.9, 4.1, -0.5]:
		v.position.x = x
		_check(r._sprite_id(wheel["data"]) == "vehicle.jeep.p457.frame_%02d" % (posmod(floori(x), 4) + 1), "wheel frame at x = %s" % x)
	v.swim_amount = 0.5
	var row4: Array = r._corners(wheel["data"], {})
	_check(_near(row4[0], Vector3(-2.25, -12.0, 2.0)) and _near(row4[2], Vector3(-8.25, 12.0, 1.0)), "swim 0.5 picks table row 4 (a=2.25, c=2, d=8.25, f=1)")
	var swim_ring := _part(r, 2074)
	v.swim_amount = 0.4
	r._process(0.0)
	_check(not swim_ring["mesh"].visible, "the ring is hidden below row 4")
	v.swim_amount = 0.5
	r._process(0.0)
	_check(swim_ring["mesh"].visible and _near(r._corners(swim_ring["data"], {})[0], Vector3(6.0, -6.0, 0.0)), "and shown from row 4 at half size (12 * swim)")
	r.free()
	v.free()

	# the MSV: the canister strip drops a cel per rocket fired; the two front corners slide while it reloads
	m = _made(pack, 2)
	v = m[0]
	r = m[1]
	var canisters := _part(r, 324)
	for fired in 3:
		v._salvo_index = fired
		_check(r._sprite_id(canisters["data"]) == "vehicle.msv.p324.canisters_%d" % (3 - fired), "%d rockets fired shows canisters_%d" % [fired, 3 - fired])
	v._salvo_reload = 0.0
	var idle: Vector3 = r._corners(canisters["data"], {})[1]   # rig point 4
	v._salvo_reload = 40.0
	var reloading: Vector3 = r._corners(canisters["data"], {})[1]
	_check(is_equal_approx(reloading.y - idle.y, 6.0), "reloading slides the front corners 6 units (%s -> %s)" % [idle.y, reloading.y])
	r.free()
	v.free()

	# the Heli: the rotor group accumulates rate * speed a tick; the blade shape and the folded pair swap by rotor_mode; the body tilts
	m = _made(pack, 3)
	v = m[0]
	r = m[1]
	v.heli_spinup_stage = 0
	v.rotor_speed_steps = 4.0
	r._process(1.0 / Vehicle.TICK_HZ)
	r._process(1.0 / Vehicle.TICK_HZ)
	_check(is_equal_approx(r._groups["rotor"]["node"].rotation_degrees.y, -45.0), "the rotor turns 22.5 degrees a tick at speed 4")
	var blade := _part(r, 584)
	var folded := _part(r, 588, 0)
	_check(blade["mesh"].visible and not folded["mesh"].visible, "at speed 4 the blade bar shows, the folded pair does not")
	v.heli_spinup_stage = 1
	r._process(0.0)
	_check(not blade["mesh"].visible and folded["mesh"].visible, "during the start-up's silent phase it is the other way round")
	v.bank_steps = 2.0
	r._process(0.0)
	_check(is_equal_approx(r.rotation_degrees.z, 11.25), "the body banks with bank_steps")
	r.free()
	v.free()

	print("render_descriptor_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
