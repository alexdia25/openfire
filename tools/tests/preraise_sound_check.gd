# Confirms the hangar confirm script's "sound" steps (document 78's tools/data/selector.json)
# play the real cues: index 0 = PreRaise, index 1 = Raise (document 85's addendum). Tank/Heli's
# script (with the extra platform_up step) plays PreRaise twice; Jeep/MSV once. Run:
#   godot --headless --path . --script tools/tests/preraise_sound_check.gd
extends SceneTree

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
	var v := mc.vehicle
	var dt := 1.0 / Vehicle.TICK_HZ

	for type_and_name in [[0, "Tank"], [1, "Jeep"]]:
		var t: int = type_and_name[0]
		mc._open_selection()
		mc.selection = t
		for i in 20:
			mc._process(dt)  # let the view fade in to 1.0 so confirm_selection() is accepted
		var cues: Array[String] = []
		var listener := func(id): cues.append(id)
		v.sound_cue.connect(listener)
		mc.confirm_selection()
		var g := 0
		while mc.undocking and g < 400:
			mc._process(dt)
			g += 1
		v.sound_cue.disconnect(listener)
		print(type_and_name[1], ": cues heard ", cues, " (expect PreRaise", " x2, Raise x1" if t == 0 else " x1, Raise x1", ")")
	print("done")
	quit()
