# The radar grid overlay (document 107): cel 1963, drawn unconditionally over everything else (including the ping), approximated
# as an additive white overlay the same way the hangar spotlight already is (document 103), sized to exactly fill the window. Run:
#   godot --headless --path . --script tools/tests/radar_grid_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	check("the pack has the grid data (tools/extract_radar.py)", pack.radar_data.get("grid", {}).size() > 0)
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)

	var radar := RadarView.new()
	root.add_child(radar)
	radar.setup(mc)
	check("RadarView built the grid overlay", radar._grid != null)
	check("...sized to the window, matching the base radar image", radar._grid.size == radar.size)
	check("...got a real texture (cel 1963, effect.tint.colour.006)", radar._grid.texture != null and radar._grid.texture.get_size() == Vector2(32, 32))
	check("...always visible (drawn unconditionally, unlike the ping)", radar._grid.visible)
	check("the grid is added after the ping, so it draws on top", radar.get_child_count() >= 2 and radar._grid.get_index() > radar._ping.get_index())

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
