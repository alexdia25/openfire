# Issue #80 / wiki document 117 addendum: the original's vehicle object is created when the undock object's rise ends (FUN_0042edfc ->
# FUN_0040b1c0), so its "created" sound (JeepStart for the Jeep, Servo for the Heli) plays with the game view already faded in. The side weight
# of a sourced voice is the view's fade level, so a sound at the confirm (view fade 0) would be silent. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/created_sound_check.gd
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
	var dt := 1.0 / Vehicle.TICK_HZ
	for i in 40:
		mc._process(dt)
	check("the match starts at the vehicle choice", mc.selecting)
	var cues: Array = []
	var fades: Array = []
	mc.vehicle.sound_cue.connect(func(c): cues.append(c); fades.append(mc.view_fade))
	mc.selection = 1   # the Jeep
	mc.confirm_selection()
	check("confirming plays no creation sound yet", not cues.has("JeepStart"), str(cues))
	var ticks := 0
	while not cues.has("JeepStart") and ticks < 1200:
		mc._process(dt)
		mc.vehicle._process(dt)
		ticks += 1
	check("JeepStart plays when the pad rise ends", cues.has("JeepStart") and not mc.pad_rising, "after %d ticks, cues %s" % [ticks, cues])
	check("... once, with the game view fully faded in (weight 1.0)", cues.count("JeepStart") == 1 and fades.size() > 0 and fades[cues.find("JeepStart")] >= 0.999, str(fades))
	quit(fails)
