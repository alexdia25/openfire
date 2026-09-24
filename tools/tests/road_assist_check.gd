# The Jeep's road-following steering (document 94): unit checks of RoadAssist, then a Jeep on level 1's roads.
#   godot --headless --path . --script tools/tests/road_assist_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	# the mask table and the target rule
	check("mask of art 73 (straight N/S)", RoadAssist.mask_for_tile(73, 0) == 3)
	check("mask of art 79 (straight E/W)", RoadAssist.mask_for_tile(79, 0) == 0xc)
	check("no mask off the road art range", RoadAssist.mask_for_tile(0x48, 0) == 0 and RoadAssist.mask_for_tile(0x5a, 0) == 0)
	check("coastal 0x4a gives 0xc, 0x4b gives 3", RoadAssist.mask_for_tile(0, 0x4a) == 0xc and RoadAssist.mask_for_tile(0, 0x4b) == 3)
	var t := RoadAssist.target_compass_deg(3, 10.0, Vector2(16, 16))
	check("north on the centre line: target 0", absf(t) < 0.001, str(t))
	t = RoadAssist.target_compass_deg(3, 10.0, Vector2(24, 16))
	check("north, 8 units east of centre: target -11.25 (348.75)", absf(t - 348.75) < 0.001, str(t))
	t = RoadAssist.target_compass_deg(3, 190.0, Vector2(24, 16))
	check("south, 8 units east of centre: target 191.25", absf(t - 191.25) < 0.001, str(t))
	t = RoadAssist.target_compass_deg(0xc, 100.0, Vector2(16, 24))
	check("east, 8 units south of centre: target 78.75", absf(t - 78.75) < 0.001, str(t))
	t = RoadAssist.target_compass_deg(0xc, 260.0, Vector2(16, 24))
	check("west, 8 units south of centre: target 281.25", absf(t - 281.25) < 0.001, str(t))
	check("outside the window nothing", RoadAssist.target_compass_deg(3, 60.0, Vector2(16, 16)) < 0.0)
	check("a mask without that direction: nothing", RoadAssist.target_compass_deg(0xc, 0.0, Vector2(16, 16)) < 0.0)

	# a Jeep on level 1's roads
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
	var ns := Vector2i(-1, -1)
	var ew := Vector2i(-1, -1)
	for y in level.height:
		for x in level.width:
			var a := level.get_art_id(x, y)
			if a == 73 and ns.x < 0:
				ns = Vector2i(x, y)
			if a == 79 and ew.x < 0:
				ew = Vector2i(x, y)
	print("first N/S road tile ", ns, " first E/W road tile ", ew)
	var dt := 1.0 / Vehicle.TICK_HZ
	var tile := float(pack.tile_size_px)

	# thrust with no turn key on a N/S road, 6 units east of the centre line, heading 20 degrees east of north
	v.position = Vector2(ns) * tile + Vector2(22, 16)
	v.heading_deg = 20.0 - 90.0
	v.speed = 0.0
	Input.action_press("ui_up")
	for i in 15:
		v._process(dt)
	Input.action_release("ui_up")
	var compass := fposmod(v.heading_deg + 90.0, 360.0)
	var target := 360.0 - 6.0 * 22.5 / 16.0   # the lateral offset drifts a little as it drives: a couple of degrees of slack
	check("thrust on a road pulls the heading to the lateral target", absf(wrapf(compass - target, -180.0, 180.0)) < 3.0, "compass %.2f (target about %.2f, moved %.1f px)" % [compass, target, v.position.distance_to(Vector2(ns) * tile + Vector2(22, 16))])

	# a turn key held: the heading turns freely
	v.position = Vector2(ns) * tile + Vector2(16, 16)
	v.heading_deg = 0.0 - 90.0
	Input.action_press("ui_right")
	for i in 20:
		v._process(dt)
	Input.action_release("ui_right")
	compass = fposmod(v.heading_deg + 90.0, 360.0)
	check("a held turn key is not overridden", compass > 20.0 and compass < 60.0, "compass %.2f after 20 ticks turning right" % compass)

	# outside the window (60 degrees off north): left alone
	v.position = Vector2(ns) * tile + Vector2(16, 16)
	v.heading_deg = 60.0 - 90.0
	v._road_mask = 3
	v._process(dt)
	check("60 degrees off the road: not pulled", absf(fposmod(v.heading_deg + 90.0, 360.0) - 60.0) < 0.01)

	# off the road: with a fresh mask (thrust) nothing is pulled
	v.position = Vector2(60, 60) * tile
	v.heading_deg = 20.0 - 90.0
	v._road_mask = 3
	Input.action_press("ui_up")
	v._process(dt)
	Input.action_release("ui_up")
	check("off the road the thrust clears the mask", v._road_mask == 0, str(v._road_mask))
	check("off the road the heading is untouched", absf(fposmod(v.heading_deg + 90.0, 360.0) - 20.0) < 0.01)

	# a Tank on the road is not steered
	v.set_vehicle_type(0)
	v.position = Vector2(ns) * tile + Vector2(22, 16)
	v.heading_deg = 20.0 - 90.0
	Input.action_press("ui_up")
	for i in 3:
		v._process(dt)
	Input.action_release("ui_up")
	check("a Tank is not steered by roads", absf(fposmod(v.heading_deg + 90.0, 360.0) - 20.0) < 0.01)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
