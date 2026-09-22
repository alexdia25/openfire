# Docking at the pad (document 77): a Tank, then a Heli, standing on the pad and pressing fire; the choice opens after the sinking; the confirm undocks.
#   godot --headless --path . --script tools/tests/dock_check.gd
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
	var pad := (Vector2(67, 67) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	print("start stock ", mc.vehicle_stock)
	for spec in [[0, Vector2(6, 0), false], [0, Vector2(2, 3), true], [3, Vector2(12, -10), true]]:
		var t: int = spec[0]
		var off: Vector2 = spec[1]
		if v.vehicle_type != t:
			v.set_vehicle_type(t)
		v.position = pad + off
		v.speed = 0.0
		v.moving = false
		v.frozen = false
		v.docked = false
		if t == 3:
			v.z = 50.0
			v.heli_spinup_stage = 0   # this Heli is meant to already be in flight (document 79's start-up is done, not in progress)
			v.rotor_speed_steps = 4.0
		Input.action_press("ui_accept")
		var n := 0
		while mc.dock_state == 0 and not mc.selecting and n < 5:
			mc._process(dt)
			v._process(dt)
			n += 1
		print("type ", t, " offset ", off, " within tolerance -> docking started ", mc.dock_state != 0, " (expect ", spec[2], ")")
		Input.action_release("ui_accept")
		if mc.dock_state == 0:
			continue
		var ticks := 0
		while not mc.selecting and ticks < 400:
			mc._process(dt)
			v._process(dt)
			ticks += 1
		print("  choice opened after ", ticks, " ticks, docked ", v.docked, " stock ", mc.vehicle_stock, " reserve ", mc.mine_reserve)
		mc.select_move(1)
		for i in 40:
			mc._process(dt)
		mc.confirm_selection()
		var g := 0
		while mc.undocking and g < 1000:
			mc._process(dt)
			g += 1
		print("  the confirm script took ", g, " ticks")
		print("  confirmed ", ["Tank", "Jeep", "MSV", "Heli"][v.vehicle_type], " at ", v.position - pad, " heading ", v.heading_deg, " docked ", v.docked, " stock ", mc.vehicle_stock)
	quit()
