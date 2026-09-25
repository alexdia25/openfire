# Crushing a bush plays its sound once (the crush record's `SOUND 13` = BushCrush, run once per crush), not once per collision test while the tank overlaps the tile. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/crush_sound_check.gd
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
	var v := mc.vehicle
	v.set_vehicle_type(0)
	var tsz := float(pack.tile_size_px)
	# a tile whose callback is the bush's, with a shape the tank hits
	var found := Vector2i(-1, -1)
	for y in level.height:
		for x in level.width:
			var id := level.get_coastal_id(x, y)
			if id != 0 and String(pack.get_coastal_shapes(id).get("callback", "")) == "0x436640" and pack.get_coastal_shapes(id).get("shapes", []).size() > 0:
				found = Vector2i(x, y)
				break
		if found.x >= 0:
			break
	check("found a bush tile", found.x >= 0, str(found))
	var cues: Array = []
	v.sound_cue.connect(func(c): cues.append(c))
	var at := (Vector2(found) + Vector2(0.5, 0.5)) * tsz
	v.position = at
	v.speed = 1.0 * Vehicle.TICK_HZ   # faster than the crush speed (0.5 units a tick)
	for i in 20:
		mc.vehicle_blocked(v, at, v.heading_deg)   # the drive code tests up to three positions a tick, for as long as the tank overlaps the tile
	var n := cues.count("BushCrush")
	check("twenty collision tests against the same bush give one BushCrush, not one each", n == 1, "%d cues %s" % [n, cues])
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
