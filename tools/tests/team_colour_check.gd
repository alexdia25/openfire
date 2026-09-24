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

	print("team_colour_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
