# Confirms VehicleRender3D picks the traced rotor mode (document 63) from the Heli's spin-up
# state: mode 4 (the static, non-spinning single blade, cel 588 "rotor.c") during stage 1's
# silent phase, then widening blade-bar modes 0-3 as rotor_speed_steps ramps through stage 2,
# settling on mode 3 (the full width this file always drew before) once flying. Run:
#   godot --headless --path . --script tools/tests/heli_rotor_mode_check.gd
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
	v.set_vehicle_type(3)  # Heli

	var render := VehicleRender3D.new()
	root.add_child(render)
	render.setup(v, pack)

	var dt := 1.0 / Vehicle.TICK_HZ
	print("tick 0: stage ", v.heli_spinup_stage, " rotor_speed ", v.rotor_speed_steps, " mode ", render._heli_rotor_mode(), " (expect stage 1, mode 4)")
	var seen_modes: Array[int] = []
	for i in 260:
		v._process(dt)
		render._process(dt)
		var m: int = render._rotor_mode
		if seen_modes.is_empty() or seen_modes[-1] != m:
			seen_modes.append(m)
			print("tick ", i, ": stage ", v.heli_spinup_stage, " rotor_speed ", snappedf(v.rotor_speed_steps, 0.01), " -> mode ", m)
	print("mode sequence: ", seen_modes, " (expect 4 then 0,1,2,3 in order, ending on 3)")
	print("done")
	quit()
