# The vehicles' engine loops (document 97): EngineLoop's maths, then the SoundManager choosing and pitching the loop for each vehicle type. Run:
#   godot --headless --path . --script tools/tests/engine_loop_check.gd
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
	var snd := SoundManager.new()
	get_root().add_child(snd)
	snd.setup(pack)
	snd.connect_vehicle(mc.vehicle)
	# the loops now live in the vehicle definitions (sounds.engine_loop, PORTING_PLAN.md 2.7.2)
	var tread: Dictionary = pack.vehicle_value(0, "sounds.engine_loop", {})
	var jeep: Dictionary = pack.vehicle_value(1, "sounds.engine_loop", {})
	var heli: Dictionary = pack.vehicle_value(3, "sounds.engine_loop", {})
	check("definitions carry the loops: tread, jeep_idle, tread, heli", tread.get("id") == "tread" and jeep.get("id") == "jeep_idle"
			and pack.vehicle_value(2, "sounds.engine_loop.id") == "tread" and heli.get("id") == "heli")
	check("tread at rest: 0x4ef = 1263 Hz", is_equal_approx(EngineLoop.pitch_hz(tread, 0.0, 0.0), 1263.0))
	check("tread at 1.0 unit a tick: 0x116a = 4458 Hz", is_equal_approx(EngineLoop.pitch_hz(tread, 1.0, 0.0), 4458.0))
	check("tread in reverse mirrors forward", is_equal_approx(EngineLoop.pitch_hz(tread, -0.4, 0.0), EngineLoop.pitch_hz(tread, 0.4, 0.0)))
	check("jeep idle: 7058 Hz at rest, 14860 at 1.0", is_equal_approx(EngineLoop.pitch_hz(jeep, 0.0, 0.0), 7058.0) and is_equal_approx(EngineLoop.pitch_hz(jeep, 1.0, 0.0), 14860.0))
	check("heli rotor: 0xa3d = 2621 Hz stopped, 5 x that at rotor speed 4.0", is_equal_approx(EngineLoop.pitch_hz(heli, 0.0, 0.0), 2621.0) and is_equal_approx(EngineLoop.pitch_hz(heli, 0.0, 4.0), 2621.0 * 5.0))
	check("volume: the descriptor's level 0xd55 is -10.6 dB, the Heli's 0x10a3 -7.8 dB", is_equal_approx(EngineLoop.volume_db(tread), (0xd55 / 3.0 - 2200.0) / 100.0) and absf(EngineLoop.volume_db(heli) + 7.8) < 0.05, "%f" % EngineLoop.volume_db(tread))
	var dt := 1.0 / Vehicle.TICK_HZ
	var v := mc.vehicle
	v.set_vehicle_type(0)
	v.docked = false
	snd._process(dt)
	check("a Tank plays the tread loop", snd._loop_key == "tread", snd._loop_key)
	v.set_vehicle_type(2)
	snd._process(dt)
	check("an MSV plays the tread loop", snd._loop_key == "tread", snd._loop_key)
	v.set_vehicle_type(1)
	v.speed = 0.5 * Vehicle.TICK_HZ
	snd._process(dt)
	check("a Jeep plays the idle loop, pitched by its speed", snd._loop_key == "jeep_idle" and absf(snd._loop_player.pitch_scale - (7058.0 + (14860.0 - 7058.0) * 0.5) / 11025.0) < 0.001, "%s %.3f" % [snd._loop_key, snd._loop_player.pitch_scale])
	v.set_vehicle_type(3)
	v.heli_spinup_stage = 1
	snd._process(dt)
	check("a Heli in the silent blade acceleration (stage 1) plays nothing", snd._loop_key == "", snd._loop_key)
	v.heli_spinup_stage = 2
	v.rotor_speed_steps = 4.0
	snd._process(dt)
	check("a Heli ramping its rotor plays the rotor loop", snd._loop_key == "heli", snd._loop_key)
	check("... at 5 x 2621 Hz in flight", absf(snd._loop_player.pitch_scale - 2621.0 * 5.0 / 11025.0) < 0.001, "%.3f" % snd._loop_player.pitch_scale)
	v.docked = true
	snd._process(dt)
	check("docked in the base: silent", snd._loop_key == "", snd._loop_key)
	v.docked = false
	v.alive = false
	snd._process(dt)
	check("destroyed: silent", snd._loop_key == "", snd._loop_key)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
