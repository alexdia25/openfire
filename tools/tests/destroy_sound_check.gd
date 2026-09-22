# Confirms the tile-destroy and mine-explosion sounds resolved in document 84 (coastal id -> cue,
# and the mine's explosion record 0x445058 -> ExplLarge). Run:
#   godot --headless --path . --script tools/tests/destroy_sound_check.gd
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

	var expect := {1: "SmallBoom", 12: "Boom", 39: "ExplLarge", 47: "BushCrush", 64: "SmDirtHit"}
	var all_ok := true
	for cid in expect:
		var got: Array[String] = []
		var conn := func(id): got.append(id)
		mc.vehicle.sound_cue.connect(conn)
		var t := Vector2i(200 + cid, 200)
		mc._tile_hp[t] = 10   # bypass needing a real coastal shape at this synthetic tile
		mc._damage_tile_amount(t, cid, 9999.0)
		mc.vehicle.sound_cue.disconnect(conn)
		var ok: bool = got.size() >= 1 and got[0] == expect[cid]
		all_ok = all_ok and ok
		print("coastal ", cid, " -> ", got, " (expect ", expect[cid], "): ", "OK" if ok else "MISMATCH")

	var got_mine: Array[String] = []
	var conn2 := func(id): got_mine.append(id)
	mc.vehicle.sound_cue.connect(conn2)
	mc._on_mine_dropped(Vector2(500, 500), mc.vehicle)
	var m: Mine = mc.mines[0]
	mc._detonate_mine(m)
	print("mine explosion -> ", got_mine, " (expect to include ExplLarge and a ThrowGrenade1 variant)")
	print("all correct: ", all_ok)
	print("done")
	quit()
