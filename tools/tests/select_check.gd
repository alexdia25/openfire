# The vehicle-choice grid's cursor logic (document 76). Run: godot --headless --path . --script tools/tests/select_check.gd
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
	mc.vehicle.moving = false
	mc.switch_player_vehicle()
	print("opened ", mc.selecting, " cursor ", mc.selection, " stock ", mc.vehicle_stock)
	for d in [1, 2, 0, 3, 3, 1, 1]:
		mc.select_move(d)
		print("move ", ["left", "right", "up", "down"][d], " -> ", ["Tank", "Jeep", "MSV", "Heli"][mc.selection])
	mc.vehicle_stock[2] = 0   # no MSV left: a move onto it is skipped
	mc.selection = 1
	mc.select_move(2)
	print("Jeep up with no MSV -> ", ["Tank", "Jeep", "MSV", "Heli"][mc.selection], " (stays: MSV's other neighbours are itself / Jeep)")
	mc.selection = 3
	mc.select_move(1)
	print("Heli right with no MSV -> ", ["Tank", "Jeep", "MSV", "Heli"][mc.selection])
	mc.selection = 3
	mc.confirm_selection()
	print("confirmed: type ", mc.vehicle.vehicle_type, " stock ", mc.vehicle_stock, " selecting ", mc.selecting)
	quit()
