# The Heli's take-off and automatic landing on integers (alexdia25/openfire#133 stage S6.2, wiki document 172), on the real pack (RFMAP002):
#  - the start-up: FUN_0040e8c0 runs 56 ticks (state+0x58 by 0x49b past 0x10000), FUN_0040e930 ramps the rotor by 0x666 to 0x40000;
#  - the take-off FUN_0040e9c0: no control (keys held do nothing, no shots), +0x4000 along x and 0x8000 up a tick, the heading spinning
#    by +-0x4000, the pitch and bank from the tables by whole units of height; at the ceiling they are 0 and flight begins;
#  - the landing: the dock press starts FUN_0040eb00 the next tick; the brake (FUN_0040eb40) holds the buttons off until the velocity is 0;
#    the descent (FUN_0040ec30) falls 0x8000 a tick and puts the Heli at the pad + offset x whole units and the heading at 0x180000 +
#    offset x the same, so it lands on the pad's centre at heading step 24; its buttons fire meanwhile;
#  - the rotor spin-down (FUN_0040ecd0) to 0x8000 then round to angle 0 ("Servo"), the gear stage (FUN_0040ede0) 56 ticks, then the dock.
# Needs the real pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/heli_takeoff_fx_check.gd
extends SceneTree

const CLIMB_PITCH := [0, 1, 1, 1, 2, 2, 3, 4, 5, 6, 6, 6, 7, 7, 7, 7, 7, 6, 6, 6, 6, 6, 6, 5, 5, 5, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2,
		2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const CLIMB_BANK := [0, 0, 0, -1, -1, -1, -1, -1, -1, -2, -2, -2, -1, -1, -1, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 3, 3, 2, 2,
		1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

var _failures := 0
var mc: MatchController
var pack: Pack
var level: LevelData
var shots := 0
var cues: Array[String] = []


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


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _fresh(plan: Callable, startup: bool) -> Vehicle:
	if mc != null:
		mc.queue_free()
	level = LevelData.new()
	level.load_from(pack.level_dir("RFMAP002"), pack.level_override_paths("RFMAP002"))
	mc = MatchController.new()
	mc.match_seed = 1996
	mc.computer_fills_sides = false
	get_root().add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", get_root())
	mc.skip_start_hangar()
	mc._drone_cap_override = 0
	var v := mc.vehicle
	v.set_vehicle_type(3)
	v.docked = false
	v.frozen = false
	if not startup:
		v.heli_spinup_stage = 0
		v.heli_rotor_fx = 0x40000
		v.heli_gear_fx = 0x10000
	var ctl := ScriptedControls.new()
	ctl.plan = plan
	v.controls = ctl
	mc.slots[0].controls = ctl
	shots = 0
	cues.clear()
	v.shot.connect(func(_s): shots += 1)
	v.sound_cue.connect(func(id): cues.append(id))
	v.pos_fx = _pad()
	return v


func _pad() -> Vector2i:
	var p := mc.slots[0].spawn_px
	return Vector2i(roundi(p.x * 65536.0), roundi(p.y * 65536.0))


func _signed22(a: int) -> int:
	a &= 0x3fffff
	return a - 0x400000 if a > 0x1fffff else a


func _takeoff() -> void:
	var v := _fresh(func(_t): return InputWord.UP | InputWord.RIGHT | InputWord.A, true)
	var n1 := 0
	while v.heli_spinup_stage == 1 and n1 < 1000:
		mc.step()
		n1 += 1
	_check(n1 == 56 and v.heli_gear_fx == 0x10000 and cues.has("Heli"), "FUN_0040e8c0 lasts 56 ticks and ends at 0x10000 with \"Heli\" (%d, %d)" % [n1, v.heli_gear_fx])
	var n2 := 0
	while v.heli_spinup_stage == 2 and n2 < 1000:
		mc.step()
		n2 += 1
	var want2 := 0
	while 0x666 * want2 <= 0x3ffff:
		want2 += 1
	_check(n2 == want2 and v.heli_rotor_fx == 0x40000, "FUN_0040e930 ramps the rotor by 0x666 to 0x40000 in %d ticks (%d)" % [want2, n2])
	_check(v.pos_fx == _pad() and v.height_fx == 0 and v.speed_fx == 0, "nothing moves during the spin-up, keys held")
	var spin := v.heli_spin_fx
	_check(spin == 0x4000 or spin == -0x4000, "the take-off's spin is +-0x4000 (%d)" % spin)
	var ok_step := true
	var ok_tab := true
	var n3 := 0
	while v.heli_spinup_stage == 3 and n3 < 1000:
		var p0 := v.pos_fx
		var h0 := v.heading_fx
		var z0 := v.height_fx
		mc.step()
		n3 += 1
		if v.pos_fx != p0 + Vector2i(0x4000, 0) or v.heading_fx != ((h0 + spin) & 0x3fffff) or v.height_fx != mini(z0 + 0x8000, 0x320000) or v.speed_fx != 0:
			ok_step = false
		if v.heli_spinup_stage == 3:
			var u := v.height_fx >> 16
			if v.heli_climb_pitch_fx != int(CLIMB_PITCH[u]) << 15 or v.bank_fx != int(CLIMB_BANK[u]) << 16:
				ok_tab = false
	_check(ok_step, "FUN_0040e9c0 a tick: +0x4000 along x, 0x8000 up, the heading +-0x4000, no speed")
	_check(ok_tab, "the pitch and bank follow the tables 0x4454a0 / 0x4454d8 by whole units of height")
	_check(n3 == 100 and v.height_fx == 0x320000 and v.bank_fx == 0 and v.heli_climb_pitch_fx == 0, "it reaches the ceiling in 100 ticks, level (%d)" % n3)
	_check(shots == 0, "no shots while starting up and taking off, A held (%d)" % shots)
	for i in 30:
		mc.step()
	_check(v.speed_fx > 0 and shots > 0, "then it flies: the keys and buttons work (speed %d, shots %d)" % [v.speed_fx, shots])


func _landing(fire: bool) -> void:
	var press := 2
	var v := _fresh(func(t): return InputWord.A if t == press or (fire and t > 20 and t % 7 == 0) else 0, false)
	var ps := mc.slots[0]
	var pad := _pad()
	v.height_fx = 0x320000
	v.pos_fx = pad + Vector2i(0x10000, -0x20000)
	v.heading_fx = 0x100000
	v.heli_vel_fx = Vector2i(0x4000, 0x2000)   # drifting: the brake has something to stop
	for i in press + 1:
		mc.step()
	_check(ps.dock_state == 1 and v.heli_landing == 1 and v.heli_drive == 0, "the dock press: the landing's handler from next tick")
	mc.step()
	_check(v.heli_drive == 1 and v.heli_landing == 0, "FUN_0040eb00 the tick after: the drive is the brake")
	var shots_brake := shots
	var n := 0
	while v.heli_drive == 1 and n < 400:
		mc.step()
		n += 1
	_check(v.heli_drive == 2 and v.heli_vel_fx == Vector2i.ZERO and shots == shots_brake, "the brake ends with the velocity exactly 0, no shots meanwhile")
	var rate := v.heli_land_rate_fx
	var turn := v.heli_land_turn_fx
	var ok := true
	var shots_desc := shots
	var ticks := 0
	while v.heli_landing != 3 and ticks < 400:
		var z0 := v.height_fx
		mc.step()
		ticks += 1
		var u := v.height_fx >> 16
		if v.height_fx != maxi(z0 - 0x8000, 0) or v.pos_fx != pad + rate * u or v.heading_fx != ((turn * u + 0x180000) & 0x3fffff):
			ok = false
	_check(ok, "FUN_0040ec30 a tick: 0x8000 down, at the pad + offset x units, heading 0x180000 + offset x units")
	_check(v.pos_fx == pad and v.heading_fx == 0x180000 and v.height_fx == 0, "it lands on the pad's centre at heading step 24")
	if fire:
		_check(shots > shots_desc, "its buttons fire during the descent (%d shots)" % (shots - shots_desc))
	var r0 := v.heli_rotor_fx
	ok = true
	while v.heli_landing == 3 and ticks < 2000:
		mc.step()
		ticks += 1
		if v.heli_landing == 3 and v.heli_rotor_fx != maxi(r0 - 0x666, 0x8000):
			ok = false
		r0 = v.heli_rotor_fx
	_check(ok and v.heli_landing == 4 and v.heli_rotor_fx == 0 and v.heli_rotor_angle_fx == 0 and cues.has("Servo"),
			"FUN_0040ecd0: the rotor slows by 0x666 to 0x8000, steps round to angle 0, \"Servo\"")
	var g := 0
	while v.heli_landing == 4 and g < 400:
		mc.step()
		g += 1
	_check(g == 56 and v.heli_gear_fx == 0, "FUN_0040ede0: 56 ticks of 0x49b down to 0 (%d)" % g)
	for i in 3:
		mc.step()
	_check(ps.dock_state == 2, "then it docks (dock_state %d)" % ps.dock_state)


func _init() -> void:
	pack = Pack.new()
	pack.load_from("res://packs/original_pc")
	_takeoff()
	_landing(false)
	_landing(true)
	print("heli_takeoff_fx_check: %s" % ("ok" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)
