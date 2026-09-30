# The Jeep missile's landing record (document 61, addendum): FUN_00415730 calls FUN_0042f280 at the landing point,
# then, only for a SHALLOW point, refines it with FUN_0042f5b0 -- a +-12 unit box sampled at its four corners against
# class 0 (land). Any corner of land there means the shore is close enough to count as a ground impact, not a splash;
# deep water is always a splash regardless, and isolated shallow water (no land within the box) is too. Run:
#   godot --headless --path . --script tools/tests/missile_water_landing_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


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
	var tsz := float(pack.tile_size_px)

	# A 3x3 patch of shallow water (art 1) with no land tile anywhere near it: an isolated shallow spot at its centre.
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			level.set_art_id(50 + dx, 50 + dy, 1)
	var isolated := (Vector2(50, 50) + Vector2(0.5, 0.5)) * tsz
	check("isolated shallow water is genuinely shallow at the point test (not a bad fixture)",
		Water.class_at(level, pack, isolated) == 1)
	check("a box within it finds no land (a real 12-unit box, not a vacuous pass)", not mc._land_within(isolated, 12.0))

	var cues: Array = []
	mc.impact_effect.connect(func(record, _pos): cues.append(record))
	var p1 := Projectile.new()
	p1.position = isolated
	p1.lob = true
	mc._missile_lands(p1)
	check("a missile landing in isolated shallow water plays the water record", cues == ["0x4445e8"], str(cues))

	# The same shallow art, but with a land tile right next door: a point one unit from that edge has land in its box.
	level.set_art_id(60, 60, 1)      # shallow
	level.set_art_id(61, 60, 0)      # land, immediately to the east
	var near_shore := (Vector2(61, 60)) * tsz - Vector2(1.0, 0.0)   # one unit west of the shallow/land boundary
	check("the near-shore point is still shallow at the point test", Water.class_at(level, pack, near_shore) == 1)
	check("its box does find land (the fixture actually exercises the shore case)", mc._land_within(near_shore, 12.0))

	cues.clear()
	var p2 := Projectile.new()
	p2.position = near_shore
	p2.lob = true
	mc._missile_lands(p2)
	check("a missile landing in shallow water within 12 units of shore plays the ground record, not water",
		cues == ["0x444840"], str(cues))

	# Deep water is unconditionally a splash, box or no box.
	level.set_art_id(70, 70, 2)
	level.set_art_id(71, 70, 0)   # land right next door, but deep water never checks the box
	var deep_near_shore := (Vector2(71, 70)) * tsz - Vector2(1.0, 0.0)
	check("the deep-water fixture really is deep at the point test", Water.class_at(level, pack, deep_near_shore) == 2)
	cues.clear()
	var p3 := Projectile.new()
	p3.position = deep_near_shore
	p3.lob = true
	mc._missile_lands(p3)
	check("deep water plays the water record even one unit from shore (no box test for class 2)",
		cues == ["0x4445e8"], str(cues))

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
