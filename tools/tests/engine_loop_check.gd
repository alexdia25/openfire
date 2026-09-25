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
	check("loops.json loaded: tread, jeep_idle, heli", snd._loops.has("tread") and snd._loops.has("jeep_idle") and snd._loops.has("heli"))
	var tread: Dictionary = snd._loops["tread"]
	var jeep: Dictionary = snd._loops["jeep_idle"]
	var heli: Dictionary = snd._loops["heli"]
	check("tread at rest: 0x4ef = 1263 Hz", is_equal_approx(EngineLoop.pitch_hz(tread, 0.0, 0.0), 1263.0))
	check("tread at 1.0 unit a tick: 0x116a = 4458 Hz", is_equal_approx(EngineLoop.pitch_hz(tread, 1.0, 0.0), 4458.0))
	check("tread in reverse mirrors forward", is_equal_approx(EngineLoop.pitch_hz(tread, -0.4, 0.0), EngineLoop.pitch_hz(tread, 0.4, 0.0)))
	check("jeep idle: 7058 Hz at rest, 14860 at 1.0", is_equal_approx(EngineLoop.pitch_hz(jeep, 0.0, 0.0), 7058.0) and is_equal_approx(EngineLoop.pitch_hz(jeep, 1.0, 0.0), 14860.0))
	check("heli rotor: 0xa3d = 2621 Hz stopped, 5 x that at rotor speed 4.0", is_equal_approx(EngineLoop.pitch_hz(heli, 0.0, 0.0), 2621.0) and is_equal_approx(EngineLoop.pitch_hz(heli, 0.0, 4.0), 2621.0 * 5.0))
	check("volume: 210/255 for 10 ticks, then 100/255", is_equal_approx(EngineLoop.volume(tread, 9.0), 210.0 / 255.0) and is_equal_approx(EngineLoop.volume(tread, 10.0), 100.0 / 255.0))
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
