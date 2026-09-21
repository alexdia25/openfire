# Sweeps the Jeep over the ruin tile (75,56 = coastal 63 after the building falls) and reports which cells and headings are blocked, and whether
# the flag pick-up box can be reached. Run: godot --headless --path . --script tools/tests/ruin_access.gd
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
	level.set_coastal_id(75, 56, 63)
	level.set_art_id(75, 56, 111)
	mc.tile_state_applied(Vector2i(75, 56))
	var v := mc.vehicle
	v.set_vehicle_type(1)
	print("jeep half w/l ", v.hit_half_width, " ", v.hit_half_length)
	var c := (Vector2(75, 56) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	for hd in [0.0, 90.0, 180.0, 270.0]:
		print("heading ", hd, " (rows y from -24 to +24 step 3; # blocked, . free), x from -24 to +24 step 3")
		for dy in range(-24, 25, 3):
			var row := ""
			for dx in range(-24, 25, 3):
				row += "#" if mc.vehicle_blocked(v, c + Vector2(dx, dy), hd) else "."
			print("  ", "%3d " % dy, row)
	# drive the Jeep at the ruin from four sides with the flag on it: contact with a post alone must grab the flag (FUN_00432d80)
	for side in [Vector2(0, -1), Vector2(0, 1), Vector2(0, 1), Vector2(0, 0.6)]:
		for f in mc.flags.values():
			f.carrier = null
			f.dropper = null
		mc._spawn_flag("b", c) if mc.flags.is_empty() else null
		mc.flags[1].position = c
		v.position = c + side * 60.0
		v.heading_deg = rad_to_deg((-side).angle())
		v.speed = 0.0
		var ticks := 0
		while mc.flags[1].carrier == null and ticks < 400:
			Input.action_press("ui_up")
			v._process(1.0 / Vehicle.TICK_HZ)
			mc._process(1.0 / Vehicle.TICK_HZ)
			ticks += 1
		Input.action_release("ui_up")
		print("from ", side, ": grabbed ", mc.flags[1].carrier == v, " after ", ticks, " ticks at ", v.position - c)
	quit()
