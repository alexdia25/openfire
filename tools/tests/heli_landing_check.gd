# Confirms the Heli's landing sequence (2026-09-23; run by the Heli itself since wiki document 172): the brake and the
# automatic descent (FUN_0040eb40 / FUN_0040ec30), then the rotor spins down to a floor of 0.5 and round to angle 0
# (FUN_0040ecd0, playing "Servo"), then the gear timer runs (FUN_0040ede0) before the vehicle actually docks.
# heli_takeoff_fx_check.gd asserts the same on integers.
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
	mc.skip_start_hangar()
	var v := mc.vehicle
	v.set_vehicle_type(3)
	v.docked = false
	v.frozen = false
	v.heli_spinup_stage = 0
	v.rotor_speed_steps = 4.0
	v.heli_landing_gear_progress = 1.0
	v.position = (Vector2(67, 67) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	v.z = 10.0  # a short automatic descent so the test finishes quickly
	var dt := 1.0 / Vehicle.TICK_HZ

	var cues: Array[String] = []
	v.sound_cue.connect(func(id): cues.append(id))

	mc._begin_dock(mc.slots[0])
	print("dock_state after begin: ", mc.dock_state, " (expect 1, the descent)")
	var seen: Array[String] = []
	var rotor_at_spin_down := -1.0
	for i in 2000:
		mc._process(dt)
		var s := "ds%d/land%d/drive%d" % [mc.dock_state, v.heli_landing, v.heli_drive]
		if seen.is_empty() or seen[-1] != s:
			seen.append(s)
			print("tick ", i, ": ", s, " rotor ", snappedf(v.rotor_speed_steps, 0.01),
					" gear ", snappedf(v.heli_landing_gear_progress, 0.01), " z ", snappedf(v.z, 0.1))
			if v.heli_landing == 3 and rotor_at_spin_down < 0.0:
				rotor_at_spin_down = v.rotor_speed_steps
		if mc.dock_state == 2:
			break
	print("sequence: ", seen, " (expect the press, the brake drive1, the descent drive2, land3 rotor down, land4 gear, land5, ds2)")
	print("rotor speed when spin-down began: ", rotor_at_spin_down, " (expect about 4.0, full speed less one step)")
	print("rotor speed floor reached: ", v.rotor_speed_steps <= 0.5001, " (expect true)")
	print("cues heard: ", cues, " (expect Servo somewhere after the descent, plus Raise at the dock sink)")
	print("done")
	quit()
