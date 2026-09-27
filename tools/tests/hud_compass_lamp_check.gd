# The Jeep's compass is a lamp (document 103): the cel by the sign of the value, the palette step by |value|, and the pack's lamp sheet (tools/extract_compass_lamps.py)
# holds the 17 faded palettes (the footage: green at the flag, dim red when the nose is off home, bright red with a halo when it points at it). Run:
#   godot --headless --path . --script tools/tests/hud_compass_lamp_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	check("value -16 is the flag lamp at the last step", HudPanel.lamp_region(-16) == Rect2i(256, 0, 16, 16))
	check("value 0 is the home lamp at the first step", HudPanel.lamp_region(0) == Rect2i(0, 16, 16, 16))
	check("value 12 is the home lamp at step 12", HudPanel.lamp_region(12) == Rect2i(192, 16, 16, 16))
	check("a value beyond 16 clamps to the last step", HudPanel.lamp_region(40) == Rect2i(256, 16, 16, 16) and HudPanel.lamp_region(-40) == Rect2i(256, 0, 16, 16))

	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var sheet := Image.load_from_file("res://packs/original_pc/hud/compass_lamps.png")
	check("the pack has the lamp sheet, 17 x 2 lamps of 16", sheet != null and sheet.get_size() == Vector2i(272, 32))
	if sheet != null:
		var flag_lit := sheet.get_pixel(256 + 7, 7)   # the centre pixel (the cels' index 8 / 12), fully lit
		var home_lit := sheet.get_pixel(256 + 7, 16 + 7)
		var home_dim := sheet.get_pixel(7, 16 + 7)
		check("the flag lamp is green when lit", flag_lit.g > flag_lit.r and flag_lit.g > flag_lit.b, str(flag_lit))
		check("the home lamp is red when lit", home_lit.r > home_lit.g and home_lit.r > home_lit.b, str(home_lit))
		check("the home lamp is darker at step 0 than at step 16", home_dim.r < home_lit.r or home_dim.get_luminance() < home_lit.get_luminance(), str(home_dim))
		check("the halo ring (cel index 7) is lighter at the bright end", sheet.get_pixel(1, 16 + 3) != sheet.get_pixel(256 + 1, 16 + 3))

	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	mc.vehicle.set_vehicle_type(1)   # Jeep
	var panel := HudPanel.new()
	root.add_child(panel)
	panel.setup(mc)
	panel._process(0.1)
	var want := HudPanel.lamp_region(mc.compass_value(mc.vehicle))
	var at := panel._compass.texture as AtlasTexture
	check("the Jeep's panel shows the lamp for the current value", at != null and Rect2i(at.region) == want, str(at.region if at != null else null) + " want " + str(want))
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
