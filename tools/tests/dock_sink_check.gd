# The dock's visible sink (document 81): z falls at 0.3/tick, the view fades past -16, and it finishes only once BOTH z<=-32
# AND the 70-tick timer are done (the depth is slower: ~107 ticks). Run:
#   godot --headless --path . --script tools/tests/dock_sink_check.gd
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
	v.position = pad + Vector2(2, 3)
	Input.action_press("ui_accept")
	var n := 0
	while mc.dock_state == 0 and n < 5:
		mc._process(dt); v._process(dt); n += 1
	Input.action_release("ui_accept")
	var fade_tick := -1
	var min_depth_tick := -1
	var ticks := 0
	while mc.dock_state == 2 and ticks < 300:
		mc._process(dt)
		v._process(dt)
		ticks += 1
		if fade_tick < 0 and v.z <= mc.DOCK_FADE_DEPTH:
			fade_tick = ticks
		if min_depth_tick < 0 and v.z <= mc.DOCK_MIN_DEPTH:
			min_depth_tick = ticks
		if ticks in [1, 20, 53, 55, 106, 107, 108]:
			print("tick ", ticks, " z ", snappedf(v.z, 0.01), " view_fade ", snappedf(mc.view_fade, 0.01), " visible-ish(alive&&!docked) ", v.alive and not v.docked)
	print("passed -16 at tick ", fade_tick, " (expect ~53)")
	print("reached -32 at tick ", min_depth_tick, " (expect ~107)")
	print("sink phase total ticks ", ticks, " (expect ~107, the depth is the bottleneck, not the 70-tick timer)")
	print("final z ", v.z, " docked ", v.docked, " selecting ", mc.selecting)
	quit()
