# Prints the Jeep's compass value (document 71) for a flag at several bearings, then for the carried case (home). Run:
#   godot --headless --path . --script tools/tests/compass_values.gd
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
	v.set_vehicle_type(1)
	mc._spawn_flag("b", v.position + Vector2(200, 0))
	var flag: FlagMarker = mc.flags[1]
	for h in [0.0, 5.0, 11.0, 12.0, 30.0, 60.0, 89.0, 91.0, 180.0, -60.0]:
		v.heading_deg = h
		print("heading ", h, " (flag due east): value ", mc.compass_value(v))
	v.heading_deg = 0.0
	mc._attach_flag(flag, v)
	v.position += Vector2(300, 0)
	for h in [180.0, 90.0, 0.0]:
		v.heading_deg = h
		print("carrying, heading ", h, " (home due west): value ", mc.compass_value(v))
	quit()
