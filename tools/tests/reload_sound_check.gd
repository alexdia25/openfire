# Issue #22 / wiki document 117: FUN_0040d520 (the MSV's rocket salvo) plays "Reload" (descriptor 0x44b658, Servo.SDT) when the third
# rocket of a salvo has gone and ammunition is left. Holds the fire button for a whole stock of 100: 100 rockets, a Reload after
# rockets 3, 6, ... 99 (33), none after the last. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/reload_sound_check.gd
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
	v.set_vehicle_type(2)
	v.position = Vector2(2160, 2160 + 320)
	var shots := [0]
	var reloads := [0]
	v.shot.connect(func(_s): shots[0] += 1)
	v.sound_cue.connect(func(c): if c == "Reload": reloads[0] += 1)
	var dt := 1.0 / Vehicle.TICK_HZ
	Input.action_press("ui_accept")
	for i in 12000:
		mc._process(dt)
		v._process(dt)
	Input.action_release("ui_accept")
	check("the MSV fires its whole stock of rockets", shots[0] == 100, str(shots[0]))
	check("and 'Reload' plays after every third one with ammunition left (33)", reloads[0] == 33, str(reloads[0]))
	check("the cue is a real pack entry", pack.audio.has("Reload") and pack.get_sound_path("Reload") != "")
	quit(fails)
