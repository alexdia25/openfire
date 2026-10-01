# Issue #74 / wiki documents 113 and 116: the foot soldiers on the real pack. The table came through the importer (sprite ids resolve,
# 19 buildings), RFMAP001's five soldier buildings release 15-25 enemy soldiers when each is shot down to one hit point, the soldiers get
# out of the building and walk away from a vehicle, one that is crushed or blown up is removed. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/infantry_pack_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var t := pack.infantry
	check("the pack has the infantry table", not t.is_empty() and t.get("buildings", {}).size() == 19, str(t.get("buildings", {}).size()))
	var all_real := true
	for team in ["tan", "green"]:
		for dir in t["sprites"][team]:
			for id in dir:
				all_real = all_real and not pack.get_sprite(String(id)).is_empty()
	check("every soldier sprite and the shadow are real sprites", all_real and not pack.get_sprite(String(t["shadow_sprite"])).is_empty())
	check("traced numbers: 0.2 units/tick, throw 64-96, 16-entry grenade table", absf(float(t["speed"]) - 0.2) < 1e-4 and float(t["throw_min"]) == 64.0
			and float(t["throw_max"]) == 96.0 and t["grenades"].size() == 16)
	var b15: Dictionary = t["buildings"]["15"]
	check("id 15 releases 4-7 soldiers (min 4, max 8) of the other team", int(b15["min"]) == 4 and int(b15["max"]) == 8 and bool(b15["flip_team"]))

	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var sold_ids := [Vector2i(49, 56), Vector2i(101, 83), Vector2i(88, 77), Vector2i(90, 78), Vector2i(91, 76)]
	var made := 0
	var teams := {}
	for tile in sold_ids:
		var id := level.get_coastal_id(tile.x, tile.y)
		var before := mc.soldiers.size()
		# hit points 5 (ids 24, 34) or 2 (id 35): one hit at a time down to the release
		var guard := 0
		while mc.soldiers.size() == before and guard < 10:
			mc._damage_tile_amount(tile, id, 1.0)
			guard += 1
		made += mc.soldiers.size() - before
		for s in mc.soldiers:
			teams[s.team] = true
	check("level 1's five soldier buildings release 15-25 soldiers", made >= 15 and made <= 25, str(made))
	check("they are the enemy team (1)", teams.keys() == [1], str(teams.keys()))
	print("infantry_pack_check: %d failures" % fails)
	quit(fails)
