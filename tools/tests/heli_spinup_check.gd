# The Heli's start-up (document 79): silent blade accel, then the rotor visibly ramps to full speed, then (already-existing logic) it climbs. Run:
#   godot --headless --path . --script tools/tests/heli_spinup_check.gd
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
	v.position = Vector2(2160, 2160 + 320)
	v.set_vehicle_type(3)
	var dt := 1.0 / Vehicle.TICK_HZ
	print("just created: stage ", v.heli_spinup_stage, " rotor ", v.rotor_speed_steps, " z ", v.z)
	Input.action_press("ui_up")   # thrust held throughout: it must have no effect until the spin-up ends
	var stage1_end := -1
	var stage2_end := -1
	for i in 400:
		v._process(dt)
		if stage1_end < 0 and v.heli_spinup_stage != 1:
			stage1_end = i
		if stage2_end < 0 and v.heli_spinup_stage == 0:
			stage2_end = i
		if i in [10, 60, 100, 150, 200, 250]:
			print("tick ", i, " stage ", v.heli_spinup_stage, " rotor ", snappedf(v.rotor_speed_steps, 0.01), " z ", snappedf(v.z, 0.01), " speed ", v.speed)
	print("stage 1 (blade accel) ended at tick ", stage1_end, " (expect ~56)")
	print("stage 2 (rotor ramp) ended at tick ", stage2_end, " (expect ~216)")
	print("z after spin-up is over: ", v.z, " (0 right when it ends; the climb then proceeds on its own)")
	quit()
