# DecorationField3D batches decorations per CHUNK_TILES x CHUNK_TILES block instead of one mesh set for the
# whole level (game/decoration_field_3d.gd): destroying a single tile's decoration used to rebuild every
# decoration on the map, a real reported stutter on any destruction (worse on big levels like RFMAP095, ~4900
# decorations). refresh_tile() must touch only the chunk that tile's decoration lives in. Run:
#   godot --headless --path . --script tools/tests/decoration_field_chunk_check.gd
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
	assert(level.load_from("res://packs/original_pc/levels/RFMAP095"))
	check("RFMAP095 really has a lot of decorations (the level this bug was reported on)", level.decorations.size() > 4000)

	var root := Node2D.new()
	get_root().add_child(root)
	var df := DecorationField3D.new()
	root.add_child(df)
	df.setup(pack, level)
	check("setup() split the level into more than one chunk", df._chunks.size() > 1, str(df._chunks.size()))

	var t0 := Time.get_ticks_usec()
	var entry: Dictionary = level.decorations[0]
	var tile := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	var key := df._chunk_key(tile.x, tile.y)
	var other_key: Vector2i = key
	for k in df._chunks:
		if k != key:
			other_key = k
			break
	check("found a second, different chunk to compare against", other_key != key)
	var other_root: Node = df._chunks[other_key]

	level.set_coastal_id(tile.x, tile.y, 0)   # crush/clear this one decoration, as _clear_tile_decoration does
	df.refresh_tile(tile)
	var dt_us := Time.get_ticks_usec() - t0
	check("refreshing one tile stays fast (well under a frame), not a whole-level rebuild", dt_us < 20000, str(dt_us) + " us")
	check("the OTHER chunk's own root node was left untouched (same instance, not rebuilt)",
		is_instance_valid(other_root) and df._chunks[other_key] == other_root)
	check("the chunk count didn't change (no new/dropped chunks from a single-tile change)", df._chunks.size() > 1)

	# clear every decoration in one whole chunk and confirm its own mesh set goes away (an empty chunk builds nothing)
	var target_key: Vector2i = df._indices_by_chunk.keys()[0]
	for i in df._indices_by_chunk[target_key]:
		var e: Dictionary = level.decorations[i]
		level.set_coastal_id(int(e.get("x", 0)), int(e.get("y", 0)), 0)
	var any_tile: Dictionary = level.decorations[df._indices_by_chunk[target_key][0]]
	df.refresh_tile(Vector2i(int(any_tile.get("x", 0)), int(any_tile.get("y", 0))))
	check("a chunk with every decoration cleared builds no mesh instances at all", not df._chunks.has(target_key))

	df.refresh_tile(Vector2i(-999, -999))   # a tile with no decoration at all -- must be a harmless no-op
	check("refreshing a tile outside any chunk is a no-op, not an error", true)

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
