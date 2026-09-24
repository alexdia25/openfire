# Vehicle stock (document 73): the level's T / J / A / H, one spent per vehicle created, lost when all are gone. Run:
#   godot --headless --path . --script tools/tests/stock_check.gd
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
	var lost := [false]
	mc.out_of_vehicles.connect(func(): lost[0] = true)
	print("params ", level.vehicle_params, " stock at start ", mc.vehicle_stock, " (Tank spent one)")
	var n := 0
	while not lost[0] and n < 40:
		mc.vehicle.destroyed.emit(mc.vehicle)
		var g := 0
		while mc.death_phase != 0 and g < 2000:  # the loss sequence (document 88) runs before the replacement / the loss
			mc._process(1.0 / Vehicle.TICK_HZ)
			g += 1
		n += 1
		print("destroyed ", n, " -> stock ", mc.vehicle_stock, " now type ", mc.vehicle.vehicle_type, " lost ", lost[0])
	quit()
