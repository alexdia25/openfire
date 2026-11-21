# Weapons, gun mount and cooldowns on the 16.16 simulation (alexdia25/openfire#133 stage S6.3, wiki document 173), on the real pack: a slot
# fires only when its ready tick is past and then waits its cooldown, so shots come cooldown + 1 ticks apart (Tank 21, MSV 31, Heli gun 16,
# bombs 31, mines 141); the Tank's gun rises to 0x3b8e39 and a raised shot leaves at pitch 0x38e38f; both shoulder buttons recentre the
# turret; an empty gun clicks at the same pace; the MSV reloads for 41 ticks after a salvo of three (level rockets carry pitch 0x4f5c); the
# Heli's downward gun leaves at pitch 0x71c71; the Tank and MSV roll off the pad for 15 ticks without firing and the Jeep sits for 99
# busy ticks, then sets off at half its top speed. Needs the real pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/weapons_fx_check.gd
extends SceneTree


class ScriptedControls extends PlayerControls:
	var plan: Callable
	var t := 0

	func poll() -> int:
		prev_word = word
		word = plan.call(t)
		t += 1
		return word

	func read_word() -> int:
		return word

	func state() -> int:
		return InputWord.decode(word, prev_word)

var _failures := 0
var mc: MatchController
var pack: Pack
var events: Array = []   # [tick, kind, payload]
var tick := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _fresh(type: int, plan: Callable, skip: bool, setup := Callable()) -> Vehicle:
	if mc != null:
		mc.free()
	var level := LevelData.new()
	level.load_from(pack.level_dir("RFMAP002"), pack.level_override_paths("RFMAP002"))
	mc = MatchController.new()
	mc.match_seed = 1996
	mc.computer_fills_sides = false
	get_root().add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", get_root())
	mc.skip_start_hangar()
	mc._drone_cap_override = 0
	var v := mc.vehicle
	v.set_vehicle_type(type)
	v.docked = false
	v.frozen = false
	if skip:
		v.skip_start()
		if type == 3:
			v.rotor_speed_steps = 4.0
			v.heli_landing_gear_progress = 1.0
	var ctl := ScriptedControls.new()
	ctl.plan = plan
	v.controls = ctl
	mc.slots[0].controls = ctl
	events = []
	v.shot.connect(func(s): events.append([tick, "shot", s]))
	v.mine_dropped.connect(func(at): events.append([tick, "mine", at]))
	v.empty_click.connect(func(): events.append([tick, "click", null]))
	v.sound_cue.connect(func(c): events.append([tick, "cue", c]))
	v.position = mc.slots[0].spawn_px + Vector2(0, -80)
	v.heading_fx = 0
	if setup.is_valid():
		setup.call(v)
	return v


func _run(type: int, ticks: int, plan: Callable, skip := true, setup := Callable(), each := Callable()) -> Vehicle:
	var v := _fresh(type, plan, skip, setup)
	for i in ticks:
		tick = i
		mc.step()
		if each.is_valid():
			each.call(i, v)
	return v


func _ticks(kind: String, payload: Variant = null) -> Array:
	var r := []
	for e in events:
		if e[1] == kind and (payload == null or e[2] == payload):
			r.append(e[0])
	return r


func _shots() -> Array:
	var r := []
	for e in events:
		if e[1] == "shot":
			r.append(e[2])
	return r


func _init() -> void:
	pack = Pack.new()
	pack.load_from("res://packs/original_pc")
	var A := InputWord.A
	var B := InputWord.B
	var C := InputWord.C

	# the Tank: level shots 21 ticks apart, 12 ahead and 7 up along the heading
	var v := _run(0, 90, func(t): return A)
	_check(_ticks("shot") == [0, 21, 42, 63, 84], "the Tank's level shots come every 21 ticks (cooldown 20 + 1): %s" % [_ticks("shot")])
	var s: Dictionary = _shots()[0]
	_check(s["heading_fx"] == 0 and not s.has("pitch_fx") and s["position_fx"] == v.pos_fx + Vector2i(0, -(12 << 16)) and s["z_fx"] == v.height_fx + (7 << 16),
			"a level shell leaves along the heading from (0, -12, 7): %s %s" % [s["position_fx"], s["z_fx"]])

	# raised: the gun climbs to 0x3b8e39 (one step on the press tick), the shell leaves at pitch 0x38e38f
	var elev := []
	v = _run(0, 40, func(t): return B, true, Callable(), func(i, vv): elev.append(vv.gun_elev_fx))
	_check(_ticks("shot") == [14, 35], "the first raised shell leaves on tick 14, then every 21: %s" % [_ticks("shot")])
	_check(elev[0] == 0x400000 - 0x4ccc and elev[13] > 0x3b8e39 and elev[14] == 0x3b8e39 and v.gun_elev_fx == 0x3b8e39, "the gun rises 0x4ccc a tick (negative is up) to 0x3b8e39 on tick 14 and stays (%x, %x)" % [elev[0], elev[14]])
	_check(_shots()[0].get("pitch_fx", 0) == 0x38e38f, "a raised shell's pitch is 0x38e38f (40 degrees up)")

	# both shoulders: the turret goes back to the hull
	var tur := []
	v = _run(0, 40, func(t): return InputWord.R if t < 10 else (InputWord.R | InputWord.L), true, Callable(), func(i, vv): tur.append(vv.turret_fx))
	_check(tur[9] == 10 * 0x4ccc and v.turret_fx == 0 and v.turret_target_fx == 0, "one shoulder turns the turret 0x4ccc a tick, both bring it back to 0 (%x)" % tur[9])

	# empty: the click at the same pace
	v = _run(0, 90, func(t): return A, true, func(vv): vv.ammo[0] = 2)
	_check(_ticks("shot") == [0, 21] and _ticks("click") == [42, 63, 84], "an empty gun clicks every 21 ticks: %s %s" % [_ticks("shot"), _ticks("click")])

	# the MSV: three rockets 31 ticks apart, the Reload cue, 41 ticks of reload
	v = _run(2, 200, func(t): return A)
	_check(_ticks("shot") == [0, 31, 62, 103, 134, 165] and _ticks("cue", "Reload") == [62, 165], "the MSV fires three rockets 31 apart, then reloads for 41 ticks: %s" % [_ticks("shot")])
	_check(_shots()[0]["pitch_fx"] == 0x4f5c and _shots()[0]["type"] == 8, "a level rocket is type 8 with pitch 0x4f5c")
	v = _run(2, 200, func(t): return A, true, func(vv): vv.ammo[0] = 4)
	_check(_ticks("shot") == [0, 31, 62, 103] and _ticks("click") == [134, 165, 196], "an MSV out of rockets clicks every 31 ticks, reload or not: %s" % [_ticks("click")])

	# the Heli: guns 16 apart from alternating mounts, the downward gun at pitch 0x71c71; bombs 31 apart
	v = _run(3, 70, func(t): return A)
	_check(_ticks("shot") == [0, 16, 32, 48, 64], "the Heli's gun fires every 16 ticks: %s" % [_ticks("shot")])
	_check(_shots()[0]["pitch_fx"] == 0x71c71 and _shots()[0]["position_fx"].x != _shots()[1]["position_fx"].x, "the downward gun leaves at pitch 0x71c71, from alternating mounts")
	v = _run(3, 70, func(t): return B)
	_check(_shots()[0]["pitch_fx"] == 0, "the level gun leaves at pitch 0")
	v = _run(3, 140, func(t): return C if t == 0 else A)
	_check(_ticks("shot").slice(0, 3) == [1, 32, 63] and _shots()[0]["type"] == 6 and _shots()[0]["pitch_fx"] == 0x3fffff, "bombs every 31 ticks, the downward one with pitch 0x3fffff: %s" % [_ticks("shot")])

	# mines: every 141 ticks
	v = _run(2, 300, func(t): return C | InputWord.UP, true, func(vv): vv.mine_layer_enabled = true)
	_check(_ticks("mine") == [0, 141], "mines are laid every 141 ticks: %s" % [_ticks("mine")])

	# starting: the Tank rolls off for 15 ticks and fires nothing until then; the MSV the same; the Jeep waits 99 busy ticks
	var phase := []
	v = _run(0, 40, func(t): return A, false, Callable(), func(i, vv): phase.append(vv.start_phase))
	_check(phase[13] == 1 and phase[14] == 0 and _ticks("shot") == [15, 36], "the Tank rolls off for 15 ticks, then fires: %s" % [_ticks("shot")])
	v = _run(2, 40, func(t): return B, false)
	_check(_ticks("shot") == [29], "the MSV's first raised rocket comes after the roll (15) and the rise (14): %s" % [_ticks("shot")])
	var speeds := []
	v = _run(1, 110, func(t): return InputWord.UP, false, Callable(), func(i, vv): speeds.append(vv.speed_fx))
	_check(speeds.slice(0, 98).max() == 0 and speeds[98] == v.max_forward_fx >> 1 and v.start_phase == 0,
			"the Jeep ignores the throttle for 98 ticks, then sets off at half its top speed (%d)" % speeds[98])

	mc.free()
	print("FAILURES: %d" % _failures)
	quit(1 if _failures > 0 else 0)
