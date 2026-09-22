# Confirms Vehicle.set_vehicle_type(1) (the Jeep) plays "JeepStart" once (FUN_0040b980's
# panel-activation block, record+0x240 -- the same mechanism traced for the Heli's "Servo" and
# confirmed generic by checking all four vehicle types' own +0x240 field). Other types must not
# emit it. Run:
#   godot --headless --path . --script tools/tests/jeep_start_check.gd
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

	for t in [0, 1, 2, 3, 1]:
		var cues: Array[String] = []
		var listener := func(id): cues.append(id)
		v.sound_cue.connect(listener)
		v.set_vehicle_type(t)
		v.sound_cue.disconnect(listener)
		print("type ", t, " (", ["Tank", "Jeep", "MSV", "Heli"][t], "): cues ", cues,
				" (expect [\"JeepStart\"] only when t == 1)")
	print("done")
	quit()
