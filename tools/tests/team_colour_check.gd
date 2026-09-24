# Headless check for team recolouring (PORTING_PLAN.md 2.7.7): the pack's team sets resolve to the original art for
# tan and green, generated sprites for other colours; a green generated from the tan art is close to the real green
# (the rule's accuracy); pixels the two teams share are never touched; generation is cheap enough to do at map load.
# Run:
#   godot --headless --path . --script tools/tests/team_colour_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var p := Pack.new()
	_check(p.load_from("res://packs/original_pc"), "pack loads")
	_check(p.team_sets.size() > 200, "team sets loaded (%d)" % p.team_sets.size())
	_check(p.team_colours.has("tan") and p.team_colours.has("green") and p.team_colours.has("red"), "colours loaded")

	var hull := "vehicle.tank.hull.04"
	var hull_green := "vehicle.tank.hull.05"
	_check(p.team_sprite(hull, "tan") == hull and p.team_sprite(hull, "green") == hull_green, "original colours return the drawn art")
	_check(p.team_sprite(hull_green, "tan") == hull, "the green member resolves to the same set")
	_check(p.team_sprite("vehicle.tank.track.01", "red").ends_with("@red"), "any team set member gets a generated id")
	_check(p.team_sprite("terrain.ground.sand_plain.01", "red") == "terrain.ground.sand_plain.01", "non-team art is unchanged")
	_check(p.team_sprite(hull, "no_such_colour") == hull, "an unknown colour is unchanged")

	var red_id := p.team_sprite(hull, "red")
	_check(red_id == hull + "@red" and not p.get_sprite(red_id).is_empty(), "red hull generated")
	var tan_img := p.get_sprite_image(hull)
	var green_img := p.get_sprite_image(hull_green)
	var red_img := p.get_sprite_image(red_id)
	var shared_same := true
	var red_px := 0
	for y in tan_img.get_height():
		for x in tan_img.get_width():
			var a := tan_img.get_pixel(x, y)
			if a == green_img.get_pixel(x, y):
				shared_same = shared_same and red_img.get_pixel(x, y) == a
			elif a.a > 0.0:
				var r := red_img.get_pixel(x, y)
				if r.r > r.g and r.r > r.b:
					red_px += 1
	_check(shared_same, "pixels shared by tan and green are untouched")
	_check(red_px > 500, "team pixels are red (%d)" % red_px)

	# The rule's accuracy: rebuild green from tan with green's own measured mean and compare with the real green art.
	p.team_colours["green_rebuilt"] = {"source": "check", "hsv": p.team_colours["green"]["hsv"]}
	var err := 0.0
	var n := 0
	for tan in ["vehicle.tank.hull.04", "vehicle.tank.turret.top.01", "vehicle.tank.track.01", "vehicle.tank.hull.01"]:
		var gen := p.get_sprite_image(p.team_sprite(tan, "green_rebuilt"))
		var real := p.get_sprite_image(String(p.team_sets[tan]))
		var src := p.get_sprite_image(tan)
		for y in src.get_height():
			for x in src.get_width():
				if src.get_pixel(x, y).a > 0.0 and src.get_pixel(x, y) != real.get_pixel(x, y):
					var g := gen.get_pixel(x, y)
					var q := real.get_pixel(x, y)
					err += (absf(g.r - q.r) + absf(g.g - q.g) + absf(g.b - q.b)) / 3.0
					n += 1
	var mean_err := err / maxf(n, 1) * 255.0
	_check(mean_err < 12.0, "green rebuilt from tan is within %.1f / 255 of the real green" % mean_err)

	var t := Time.get_ticks_msec()
	p.prepare_team_colours(["red", "blue", "yellow", "grey"])
	var ms := Time.get_ticks_msec() - t
	_check(p.sprites.has("vehicle.heli.rotor.a.tan@blue") and p.sprites.has("structure.hangar_leaf.left.tan@grey"), "prepare makes every set")
	_check(ms < 5000, "four colours prepared in %d ms" % ms)
	print("pages %d, sprites %d" % [p.atlas_textures.size(), p.sprites.size()])

	_check_masked_art()

	print("team_colour_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _write_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(data))


## Masked art (a mod's new vehicle: one drawing plus a team-paint mask). The hull is drawn with grey team paint on its
## left half and dark metal on its right; the mask covers the left half. The fin is drawn in blue and declared so.
func _check_masked_art() -> void:
	var mod := ProjectSettings.globalize_path("user://team_colour_check/mask_mod")
	DirAccess.make_dir_recursive_absolute(mod.path_join("sprites/mod"))
	_write_json(mod.path_join("pack.json"), {"id": "mask_mod", "name": "masked art test", "base_pack": "original_pc"})
	var hull := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var hull_mask := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			if x < 4:
				hull.set_pixel(x, y, Color.from_hsv(0.0, 0.0, 0.3 + 0.08 * y))   # grey shades
				hull_mask.set_pixel(x, y, Color.WHITE)
			else:
				hull.set_pixel(x, y, Color(0.1, 0.1, 0.12))                       # metal, not team paint
	hull.save_png(mod.path_join("sprites/mod/hull.png"))
	hull_mask.save_png(mod.path_join("sprites/mod/hull_mask.png"))
	var fin := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	fin.fill(Color.from_hsv(0.61, 0.7, 0.55))
	fin.save_png(mod.path_join("sprites/mod/fin.png"))
	var fin_mask := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	fin_mask.fill(Color.WHITE)
	fin_mask.save_png(mod.path_join("sprites/mod/fin_mask.png"))
	var frame := func(f: String, w: int, h: int) -> Dictionary: return {"file": f, "w": w, "h": h, "pivot_x": w / 2.0, "pivot_y": h / 2.0}
	_write_json(mod.path_join("sprites/sprites.json"), {"atlas_pages": [], "sprites": {
		"mod.hovertank.hull": frame.call("mod/hull.png", 8, 8), "mod.hovertank.hull.mask": frame.call("mod/hull_mask.png", 8, 8),
		"mod.hovertank.fin": frame.call("mod/fin.png", 4, 4), "mod.hovertank.fin.mask": frame.call("mod/fin_mask.png", 4, 4)}})
	_write_json(mod.path_join("sprites/team_sets.json"), {"masks": {
		"mod.hovertank.hull": "mod.hovertank.hull.mask",
		"mod.hovertank.fin": {"mask": "mod.hovertank.fin.mask", "drawn_as": "blue"}}})

	var p := Pack.new()
	_check(p.load_from(mod), "masked mod loads")
	var red := p.team_sprite("mod.hovertank.hull", "red")
	_check(red == "mod.hovertank.hull@red" and not p.get_sprite(red).is_empty(), "masked hull generated in red")
	var src := p.get_sprite_image("mod.hovertank.hull")
	var out := p.get_sprite_image(red)
	var paint_red := true
	var metal_same := true
	for y in 8:
		for x in 8:
			var c := out.get_pixel(x, y)
			if x < 4:
				paint_red = paint_red and c.r > c.g * 1.5 and c.r > c.b * 1.5 and c.s > 0.5
			else:
				metal_same = metal_same and c == src.get_pixel(x, y)
	_check(paint_red, "grey-drawn team paint takes the colour's saturation (not left grey)")
	_check(metal_same, "unmasked pixels are untouched")
	_check(out.get_pixel(0, 7).v > out.get_pixel(0, 0).v, "the drawing's shading is kept")
	_check(p.team_sprite("mod.hovertank.hull", "tan").ends_with("@tan") and p.team_sprite("mod.hovertank.hull", "green").ends_with("@green"),
			"masked art is generated in the original colours too")
	_check(p.team_variant(["mod.hovertank.hull", "mod.hovertank.hull", "x.flash"], "green") == "mod.hovertank.hull@green",
			"team_variant goes through the mask, not the list index")
	_check(p.team_sprite("mod.hovertank.fin", "blue") == "mod.hovertank.fin", "drawn_as returns the drawing itself")
	var fin_red := p.get_sprite_image(p.team_sprite("mod.hovertank.fin", "red")).get_pixel(1, 1)
	_check(fin_red.r > fin_red.b, "a colour-drawn part is recoloured by hue (blue -> red)")
	p.prepare_team_colours(["tan", "green", "yellow"])
	_check(p.sprites.has("mod.hovertank.hull@yellow") and p.sprites.has("mod.hovertank.fin@tan"), "prepare includes masked art")
	_check(p.team_sprite("vehicle.tank.hull.04", "green") == "vehicle.tank.hull.05", "original pairs unaffected in the same stack")
