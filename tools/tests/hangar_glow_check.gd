# The hangar's spotlight mask (cel 2077, document 103's hangar addendum): the raw PNG stores the mask's 0-31 brighten-table
# index directly as alpha (tools/convert_car.py), so drawn as-is its brightest pixel is ~12% opaque -- effectively invisible.
# SelectorScreen rescales it once at setup to a full 0-255 range. Run:
#   godot --headless --path . --script tools/tests/hangar_glow_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var raw := pack.get_sprite_image(String(pack.selector_data["sprites"]["highlight"]))
	check("the raw mask has the pack", raw != null)
	var raw_max := 0.0
	for y in raw.get_height():
		for x in raw.get_width():
			raw_max = maxf(raw_max, raw.get_pixel(x, y).a)
	check("the raw mask's peak alpha is low (the un-rescaled 0-31 value, not a full 0-1 opacity)", raw_max < 0.15, str(raw_max))

	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var select := SelectorScreen.new()
	root.add_child(select)
	select.setup(mc)
	check("SelectorScreen built a rescaled glow texture", select._glow_tex != null)
	if select._glow_tex != null:
		var img := select._glow_tex.get_image()
		var peak := 0.0
		for y in img.get_height():
			for x in img.get_width():
				peak = maxf(peak, img.get_pixel(x, y).a)
		check("the rescaled glow's peak alpha is visible (the real mask tops out at 24/31, document 9)", peak > 0.6, str(peak))
		check("the rescaled glow keeps white RGB (the approximation's colour, unchanged)", img.get_pixel(img.get_width() / 2, img.get_height() / 2).r == 1.0)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
