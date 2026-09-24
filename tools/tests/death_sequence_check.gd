# The loss sequence (document 88): a player vehicle's death runs the wreck delay (120 ticks, the Heli 200), the skull spinning in (30), the view darkening at
# 1310/65536 a tick with `Laugh` once dark, the 201-tick mouth animation, then a skull fade-out, and only then the replacement appears. Run:
#   godot --headless --path . --script tools/tests/death_sequence_check.gd
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
	for type in [0, 3]:
		v.set_vehicle_type(type)
		v.respawn(v.position)
		mc.view_fade = 1.0
		var cues: Array[String] = []
		var listener := func(id): cues.append(id)
		v.sound_cue.connect(listener)
		v.hp = 1.0
		v.take_damage(100.0)
		var seen: Array[int] = []
		var at := {}
		var frames: Array[int] = []
		var t := 0
		while mc.death_phase != 0 and t < 2000:
			mc._process(dt)
			t += 1
			if seen.is_empty() or seen[-1] != mc.death_phase:
				seen.append(mc.death_phase)
				at[mc.death_phase] = t
			if mc.death_phase == 4 and (frames.is_empty() or frames[-1] != mc.skull_frame()):
				frames.append(mc.skull_frame())
		v.sound_cue.disconnect(listener)
		print(["Tank", "Jeep", "MSV", "Heli"][type], ": phases ", seen, " starting at ticks ", at, " (expect 1, 2 after ", [120, 120, 120, 200][type], ", 3 after +31, 4 after +50, then 5, done)")
		print("  total ticks ", t, " skull scale ", snappedf(mc.skull_scale(), 0.001), " (expect 1.2) angle ", mc.skull_angle_deg(), " (expect 0: upright) cues ", cues, " (expect [Laugh])")
		print("  mouth frames seen while laughing: ", frames.slice(0, 12), " ... (", frames.size(), " changes; table starts 1,2,3,4,5,6,5,6,...)")
		print("  alive again ", v.alive, " selecting ", mc.selecting, " view_fade ", snappedf(mc.view_fade, 0.01), " (expect true, true, 0: the vehicle choice is open on the black screen, document 95)")
	print("done")
	quit()
