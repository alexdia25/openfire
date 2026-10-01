# The hangar's spotlight mask (cel 2077 / effect.glow.002, documents 9, 80, 103, issue #64): a real PRE0=5
# background-recolour blend, not flat art -- the raw PNG stores the mask's 0-31 brighten-table index directly
# as alpha (importer/pack_builder.gd, tools/build_pack.py), and a generic shader (BackgroundRecolourBlend,
# game/shaders/background_recolour_2d.gdshader) reads it at draw time, strength from the sprite's own
# `recolour_step` pack data -- SelectorScreen no longer rescales the mask into a fake opacity itself. Run:
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
	var highlight_id := String(pack.selector_data["sprites"]["highlight"])
	var raw := pack.get_sprite_image(highlight_id)
	check("the raw mask has the pack", raw != null)
	var raw_max := 0.0
	for y in raw.get_height():
		for x in raw.get_width():
			raw_max = maxf(raw_max, raw.get_pixel(x, y).a)
	check("the raw mask's peak alpha is the un-rescaled 0-31 value, not a full 0-1 opacity (the shader reads it directly)", raw_max < 0.15, str(raw_max))

	var sprite := pack.get_sprite(highlight_id)
	check("the sprite's own pack data names the brighten blend (importer/pack_builder.gd, tools/build_pack.py)", String(sprite.get("recolour_mode", "")) == "brighten_add")
	var step := float(sprite.get("recolour_step", 0.0))
	check("...and the exact per-level step (document 9/80: +3 of 255 a level)", is_equal_approx(step, 3.0 / 255.0), str(step))

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
	check("SelectorScreen built the glow node", select._glow != null)
	if select._glow != null:
		var mat := select._glow.material as ShaderMaterial
		check("...with the generic background-recolour shader", mat != null and mat.shader != null)
		if mat != null:
			check("...parameterised with this sprite's own step, not a constant in the script", is_equal_approx(float(mat.get_shader_parameter("recolour_step")), step))
		check("...drawing the raw mask texture itself (no manual rescale)", select._glow_tex != null and select._glow_tex.atlas != null)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
