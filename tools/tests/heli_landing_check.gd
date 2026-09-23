# Confirms the Heli's landing sequence (2026-09-23): once the automatic descent (document 77)
# reaches the ground, the rotor spins down to a floor of 0.5 (FUN_0040ecd0, playing "Servo"),
# then a second gear timer runs (FUN_0040ede0) before the vehicle is released to actually dock.
# Run:
#   godot --headless --path . --script tools/tests/heli_landing_check.gd
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
	v.set_vehicle_type(3)
	v.heli_spinup_stage = 0
	v.rotor_speed_steps = 4.0
	v.position = (Vector2(67, 67) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	v.z = 10.0  # a short automatic descent so the test finishes quickly
	var dt := 1.0 / Vehicle.TICK_HZ

	var cues: Array[String] = []
	v.sound_cue.connect(func(id): cues.append(id))

	mc._begin_dock()
	print("dock_state after begin: ", mc.dock_state, " (expect 1, the descent)")
	var seen_states: Array[int] = []
	var rotor_at_state3_start := -1.0
	for i in 2000:
		mc._process(dt)
		if seen_states.is_empty() or seen_states[-1] != mc.dock_state:
			seen_states.append(mc.dock_state)
			print("tick ", i, ": dock_state -> ", mc.dock_state, " rotor ", snappedf(v.rotor_speed_steps, 0.01),
					" gear ", snappedf(v.heli_landing_gear_progress, 0.01), " z ", snappedf(v.z, 0.1))
			if mc.dock_state == 3:
				rotor_at_state3_start = v.rotor_speed_steps
		if mc.dock_state == 2:
			break
	print("dock_state sequence: ", seen_states, " (expect 1, 3, 4, 2 in order)")
	print("rotor speed when spin-down began: ", rotor_at_state3_start, " (expect 4.0, full speed)")
	print("rotor speed floor reached: ", v.rotor_speed_steps <= 0.5001, " (expect true)")
	print("cues heard: ", cues, " (expect Servo somewhere after the descent, plus Raise at the dock sink)")
	print("done")
	quit()
