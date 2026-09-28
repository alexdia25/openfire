# Adjacent building decorations are commonly one continuous structure spanning several tiles, and their
# walls/shadows/marker signs routinely reach across the tile boundary into a neighbour's own footprint -- a
# real coplanar tie between TWO SEPARATE decoration instances (not just within one decoration's own parts,
# already fixed by SHADOW_Z_BIAS/decoration_shadow_z_check.gd). Reported: two close buildings flickering,
# alternating which small pieces show, as the camera moves (level 32, "The OK Corral"). Confirms every real
# close building pair in RFMAP032 is free of it now that DecorationField3D computes CoplanarParts.shifts()
# across a whole chunk, not per decoration. Run:
#   godot --headless --path . --script tools/tests/decoration_building_coplanar_check.gd
extends SceneTree

var fails := 0
const BUILDING_IDS := [14, 15, 16, 17, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 49, 50, 62, 63, 68, 90]


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


## The same corners DecorationField3D._build_chunk() computes for one decoration's parts, before the
## chunk-wide CoplanarParts shift.
func _raw_quads(pack: Pack, level: LevelData, tile: Vector2i) -> Array:
	var out: Array = []
	var tile_px := float(pack.tile_size_px)
	var cid := level.get_coastal_id(tile.x, tile.y)
	var parts: Array = pack.get_decoration_parts(cid)
	var cx := (float(tile.x) + 0.5) * tile_px
	var cz := (float(tile.y) + 0.5) * tile_px
	var jit: Vector2 = level.jitter_at(tile.x, tile.y)
	for part in parts:
		if not part.has("corners"):
			continue
		var sprite_id: String = part.get("sprite_id", "")
		var s := pack.get_sprite(sprite_id)
		if s.is_empty():
			continue
		var kind := String(s.get("kind", "sprite"))
		var off: Array = part.get("offset", [0.0, 0.0])
		var j := jit if part.get("jitter", false) else Vector2.ZERO
		var zoff: float = part.get("zoff", 0.0)
		var ground_y: float = DecorationField3D.SHADOW_Z_BIAS if kind == "effect" else 0.5
		var corners: Array[Vector3] = []
		for c in part["corners"]:
			corners.append(Vector3(cx + j.x + off[0] + c[0], c[2] + zoff + ground_y, cz + j.y + off[1] + c[1]))
		out.append(corners)
	return out


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP032"))

	var by_tile := {}
	for e in level.decorations:
		by_tile[Vector2i(int(e["x"]), int(e["y"]))] = int(e.get("coastal_id", 0))

	var close_pairs: Array = []
	for tile in by_tile:
		if not BUILDING_IDS.has(by_tile[tile]):
			continue
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var other: Vector2i = tile + Vector2i(dx, dy)
				if by_tile.has(other) and BUILDING_IDS.has(by_tile[other]) and (tile.x < other.x or (tile.x == other.x and tile.y < other.y)):
					close_pairs.append([tile, other])
	check("RFMAP032 really has a lot of close building pairs (the level this was reported on)", close_pairs.size() > 20, str(close_pairs.size()))

	var pairs_with_raw_ties := 0
	var pairs_still_tied_after_fix := 0
	for pr in close_pairs:
		var qa := _raw_quads(pack, level, pr[0])
		var qb := _raw_quads(pack, level, pr[1])
		var raw: Array = qa + qb
		if not CoplanarParts.covered_pairs(raw).is_empty():
			pairs_with_raw_ties += 1
		var shifts := CoplanarParts.shifts(raw)
		var shifted: Array = []
		for i in raw.size():
			var c: Array[Vector3] = (raw[i] as Array).duplicate()
			for k in c.size():
				c[k] += shifts[i]
			shifted.append(c)
		if not CoplanarParts.covered_pairs(shifted).is_empty():
			pairs_still_tied_after_fix += 1

	check("really found real ties before the fix (not a false alarm)", pairs_with_raw_ties > 20, str(pairs_with_raw_ties))
	check("no close building pair ties another's plane any more, chunk-wide shift applied", pairs_still_tied_after_fix == 0, str(pairs_still_tied_after_fix) + " still tied")

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
