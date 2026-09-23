# Confirms Vehicle.set_vehicle_type() plays each type's own record+0x240 "created" sound once
# (FUN_0040b980's panel-activation block): "JeepStart" for the Jeep, "Servo" for the Heli (also
# fired at creation, distinct from the separately-traced "Heli" spin-up chime ~56 ticks later).
# Tank/MSV share an address that isn't one of the 42 traced cues, so neither should emit anything
# here. Run:
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

	var expect := {0: [], 1: ["JeepStart"], 2: [], 3: ["Servo"]}
	for t in [0, 1, 2, 3, 1, 3]:
		var cues: Array[String] = []
		var listener := func(id): cues.append(id)
		v.sound_cue.connect(listener)
		v.set_vehicle_type(t)
		v.sound_cue.disconnect(listener)
		print("type ", t, " (", ["Tank", "Jeep", "MSV", "Heli"][t], "): cues ", cues, " (expect ", expect[t], ")")
	print("done")
	quit()
