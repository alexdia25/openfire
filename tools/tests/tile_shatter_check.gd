# A collapsing tile throws its decoration as flying pieces (document 121, issue #81): op 17 of a tile's collapse script (FUN_0042d790) runs FUN_0042b4e0 over the
# tile's parts, row n of the table at 0x44aa80. The pack carries the five tile-collapse records and the three rows; every collapse record that uses op 17
# (SHATTER) names a row the pack has; the building of RFMAP001 (coastal id 22) breaks into its eight class 1 parts, which bounce (fall and fold flat) and
# are gone after the record's duration; the effect's script fires the shatter after its wait, not at once. Needs the real pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/tile_shatter_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var rows: Dictionary = pack.debris.get("tile_rows", {})
	_check(rows.keys().size() == 3 and rows["4"] == {"1": "0x44a998", "2": "0x44a998"} and rows["6"] == {"1": "0x44aa30", "2": "0x44aa44"} and rows["7"] == {"1": "0x44aa58", "2": "0x44aa6c"}, "the pack has the tile rows 4, 6 and 7")
	var rec: Dictionary = pack.debris["records"]["0x44a998"]
	_check(is_equal_approx(float(rec["rate"]), 1.0) and rec["duration"] == 90 and rec["fade_start"] == 40 and rec["ops"][0]["op"] == "bounce" and rec["ops"][0]["start"] == 5 and rec["ops"][0]["settle_end"], "record 0x44a998: a tick a unit, 90 units, bounce from 5 ending flat")
	_check(not pack.debris["records"]["0x44aa44"]["ops"][0]["settle_end"] and pack.debris["records"]["0x44aa58"]["ops"].size() == 1 and pack.debris["records"]["0x44aa58"]["duration"] == 40, "0x44aa44 stays where it lands; the crush records (row 7) are 40 units and have no tint")
	var used := {}
	for addr in pack.explosions["records"]:
		for op in pack.explosions["records"][addr]["script"]:
			if op[0] == "SHATTER":
				used[addr] = int(op[1])
	_check(used == {"0x443b90": 6, "0x443ee8": 4, "0x443f30": 4, "0x444778": 4, "0x4451b8": 7}, "five records have a SHATTER op, with rows 6, 4, 4, 4, 7")
	for addr in used:
		_check(rows.has(str(used[addr])), "row %d of %s is in the pack" % [used[addr], addr])

	var level := LevelData.new()
	level.load_from(pack.level_dir("RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, pack.pack_dir, root)
	var made: Array = []
	mc.debris_created.connect(func(p): made.append(p))
	var tile := Vector2i(75, 56)
	_check(level.get_coastal_id(tile.x, tile.y) == 22, "RFMAP001 has the building (coastal id 22) at (75, 56)")

	# the effect's script: sound, wait 3, glow, wait 4 (24 ticks at 1/6 a tick), then SHATTER 4, then TILE_STATE
	var fx := ExplosionEffect3D.spawn(root, pack, pack.get_destroy_effect(22), Vector2(75.5, 56.5) * float(pack.tile_size_px))
	var rows_seen: Array = []
	var at_tick: Array = []
	var clock := [0]   # a lambda copies plain locals
	fx.shatter.connect(func(r): rows_seen.append(r); at_tick.append(clock[0]); mc.shatter_tile(r, tile, 22))
	for i in 120:
		clock[0] = i
		fx._process(1.0 / 62.5)
	_check(rows_seen == [4] and at_tick[0] >= 22 and at_tick[0] <= 26, "the effect shatters the building once, row 4, after its first 24 ticks (tick %s)" % [at_tick])
	_check(made.size() == 8 and mc.debris.size() == 8, "into the eight class 1 parts of the building (%d)" % made.size())
	var centre := (Vector2(tile) + Vector2(0.5, 0.5)) * float(pack.tile_size_px)
	var near := true
	var high := 0.0
	for p in made:
		near = near and p.position.distance_to(centre) < 40.0
		high = maxf(high, p.z)
	_check(near and high > 5.0, "each starts at the building, up to %.1f units high" % high)
	var ended := 0
	var all_done := false
	for i in 200:
		mc._update_debris(1.0 / Vehicle.TICK_HZ)
		ended += 1
		if mc.debris.is_empty():
			all_done = true
			break
	_check(all_done and ended >= 30 and ended <= 91, "the pieces fall, lie flat and are gone before the record's 90 units (%d ticks)" % ended)
	print("tile_shatter_check: %d failures" % _failures)
	quit(_failures)
