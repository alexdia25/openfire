# Counts the mines scattered at the start for levels of different LEVL / M (document 75). Run:
#   godot --headless --path . --script tools/tests/start_mines.gd
extends SceneTree

func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	for name in ["RFMAP001", "RFMAP002", "RFMAP008", "RFMAP040", "RFMAP100"]:
		var level := LevelData.new()
		if not level.load_from("res://packs/original_pc/levels/" + name):
			continue
		var root := Node2D.new()
		get_root().add_child(root)
		var mc := MatchController.new()
		root.add_child(mc)
		mc.setup(pack, level, "res://packs/original_pc", root)
		print(name, " LEVL ", level.levl_value, " M ", level.vehicle_params.get("M"), " -> mines ", mc.mines.size(), " tiles ", mc.mine_tiles.size())
	quit()
