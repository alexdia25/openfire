# Issue #22 / wiki document 117: FUN_004148f0 plays the sound named by the projectile type's record (+0x18) on every new projectile, with the
# projectile as its source: the Tank's shell (type 0) and the Heli's gun (type 7) play Cannon, the Heli's bomb (type 6) Missle, the MSV's
# rockets (type 8) LargeMissle. The weapon handlers play nothing of their own. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/launch_sound_check.gd
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
	mc.skip_start_hangar()
	var v := mc.vehicle
	var dt := 1.0 / Vehicle.TICK_HZ
	var cues: Array = []
	var types: Array = []
	mc.sound_at.connect(func(c, _at, _z): cues.append(c))
	v.shot.connect(func(s): types.append(int(s.get("type", -1))))
	var own: Array = []
	v.sound_cue.connect(func(c): own.append(c))

	var run := func(vehicle_type: int, heli_bomb: bool):
		v.set_vehicle_type(vehicle_type)
		v.position = Vector2(2160, 2160 + 320)
		if vehicle_type == 3:
			v.heli_spinup_stage = 0
			v.rotor_speed_steps = 4.0
			v.z = 0.0
			if heli_bomb != (v.heli_weapon_slot() == 1):
				v.toggle_heli_slot()
		cues.clear()
		types.clear()
		own.clear()
		Input.action_press("ui_accept")
		for i in 60:
			mc._process(dt)
			v._process(dt)
		Input.action_release("ui_accept")
	run.call(0, false)
	check("Tank shell (type 0): Cannon", types.size() > 0 and types[0] == 0 and cues.size() > 0 and cues[0] == "Cannon", "%s %s" % [types.slice(0, 2), cues.slice(0, 2)])
	check("... and the weapon handler itself plays nothing", not own.has("Cannon"), str(own))
	run.call(2, false)
	check("MSV rocket (type 8): LargeMissle", types.size() > 0 and types[0] == 8 and cues.size() > 0 and cues[0] == "LargeMissle", "%s %s" % [types.slice(0, 2), cues.slice(0, 2)])
	run.call(3, false)
	check("Heli gun (type 7): Cannon", types.size() > 0 and types[0] == 7 and cues.size() > 0 and cues[0] == "Cannon", "%s %s" % [types.slice(0, 2), cues.slice(0, 2)])
	run.call(3, true)
	check("Heli bomb (type 6): Missle", types.size() > 0 and types[0] == 6 and cues.size() > 0 and cues[0] == "Missle", "%s %s" % [types.slice(0, 2), cues.slice(0, 2)])
	check("the three cues are real pack entries", pack.audio.has("Cannon") and pack.audio.has("Missle") and pack.audio.has("LargeMissle"))
	quit(fails)
