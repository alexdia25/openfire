# The home pad's hole, lid and rise (document 89): dock a Tank on the pad, then confirm a Jeep.
#   godot --headless --path . --script tools/tests/pad_hatch_check.gd
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
	var t := Vector2i(67, 67)
	print("start: art ", level.get_art_id(t.x, t.y) & 0x7F, " open ", mc.pad_open, " leaf ", mc.pad_leaf_offset())
	v.position = (Vector2(t) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	v.speed = 0.0
	v.moving = false
	Input.action_press("ui_accept")
	var n := 0
	while mc.dock_state == 0 and n < 5:
		mc._process(dt)
		v._process(dt)
		n += 1
	Input.action_release("ui_accept")
	print("docking: art ", level.get_art_id(t.x, t.y) & 0x7F, " (expect 92) open ", mc.pad_open, " leaf ", mc.pad_leaf_offset(), " (expect -1: retracted)")
	var first_visible := -1
	var ticks := 0
	while not mc.selecting and ticks < 400:
		mc._process(dt)
		v._process(dt)
		ticks += 1
		if first_visible < 0 and mc.pad_leaf_offset() >= 0.0:
			first_visible = ticks
			print("  leaves appear at tick ", first_visible, " offset ", snappedf(mc.pad_leaf_offset(), 0.01), " (expect tick ~10, offset ~23)")
		if ticks in [30, 60, 69]:
			print("  tick ", ticks, " leaf offset ", snappedf(mc.pad_leaf_offset(), 0.01), " age ", snappedf(mc.pad_age, 0.1))
	print("choosing after ", ticks, " ticks: art ", level.get_art_id(t.x, t.y) & 0x7F, " leaf ", snappedf(mc.pad_leaf_offset(), 0.01), " (expect 5: closed) z ", v.z)
	mc.select_move(1)
	for i in 40:
		mc._process(dt)
	mc.confirm_selection()
	var g := 0
	while mc.undocking and g < 1000:
		mc._process(dt)
		g += 1
	print("script done after ", g, " ticks: rising ", mc.pad_rising, " z ", v.z, " frozen ", v.frozen, " leaf ", snappedf(mc.pad_leaf_offset(), 0.01), " (expect 5)")
	var r := 0
	var hidden_at := -1
	while mc.pad_rising and r < 400:
		mc._process(dt)
		r += 1
		if hidden_at < 0 and mc.pad_leaf_offset() < 0.0:
			hidden_at = r
		if r in [30, 60]:
			print("  rise tick ", r, " z ", snappedf(v.z, 0.01), " leaf ", snappedf(mc.pad_leaf_offset(), 0.01))
	print("rise took ", r, " ticks (expect ~107), leaves hidden from tick ", hidden_at, " (expect ~60)")
	print("done: art ", level.get_art_id(t.x, t.y) & 0x7F, " (expect 90) open ", mc.pad_open, " frozen ", v.frozen, " z ", v.z, " type ", v.vehicle_type)
	quit()
