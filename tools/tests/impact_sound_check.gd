# Confirms MatchController.impact_effect's record address resolves to the right sound cue
# (document 82's cross-reference of explosion_records.json's SOUND opcodes against the master
# index table at 0x44b9a0). Run:
#   godot --headless --path . --script tools/tests/impact_sound_check.gd
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

	var expect := {
		"0x444740": ["SmDirtHit"], "0x444840": ["DirtHit"],
		"0x4445b8": ["SmSplash"], "0x4445e8": ["Splash"],
		"0x444968": ["SmConcreteHit"], "0x444a30": ["ConcreteHit"],
		"0x444ac8": ["SmallBoom"],
		"0x444b68": ["MetalHit1", "MetalHit2", "MetalHit3", "MetalHit4"],
	}
	var all_ok := true
	for record in expect:
		var got: Array[String] = []
		var conn := func(id): got.append(id)
		mc.vehicle.sound_cue.connect(conn)
		mc.impact_effect.emit(record, Vector2.ZERO)
		mc.vehicle.sound_cue.disconnect(conn)
		var ok: bool = got.size() == 1 and expect[record].has(got[0])
		all_ok = all_ok and ok
		print(record, " -> ", got, " (expect one of ", expect[record], "): ", "OK" if ok else "MISMATCH")
	print("all correct: ", all_ok)
	print("done")
	quit()
