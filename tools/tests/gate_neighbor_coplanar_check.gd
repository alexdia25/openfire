# A gate tile is always embedded in a wall/fence run, and the gate's own light-housing part (cel 857/858)
# sits at the same height (z=19) as a neighbouring fence's own top rail -- a real coplanar tie between the
# gate (game/gate_view_3d.gd) and DecorationField3D's own geometry, reported as the gate's light box
# flickering against the wall it's set into (level 95). Confirms every real gate placement in RFMAP095 (the
# level this was reported on) is now free of it, the same way tank_coplanar_check/gate_coplanar_check confirm
# their own parts are. Run:
#   godot --headless --path . --script tools/tests/gate_neighbor_coplanar_check.gd
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
	var tile_px := float(pack.tile_size_px)

	var gate_tiles: Array = []
	for e in level.decorations:
		var cid := int(e.get("coastal_id", 0))
		if cid == 43 or cid == 44:
			gate_tiles.append([Vector2i(int(e["x"]), int(e["y"])), cid])
	check("RFMAP095 really has a lot of real gate placements (the level this was reported on)", gate_tiles.size() > 100, str(gate_tiles.size()))

	var total_gate_pairs := 0
	var checked_with_neighbors := 0
	for gi in gate_tiles.size():
		var gate_tile: Vector2i = gate_tiles[gi][0]
		var gate_id: int = gate_tiles[gi][1]
		var gd: Dictionary = pack.gates[str(gate_id)]
		var g := Gate.new()
		g.setup(gate_tile, gate_id, gd, 0, tile_px, null)
		var view := GateView3D.new()
		get_root().add_child(view)
		view.setup(pack, g)

		var gate_quads: Array = []
		for p in view._parts:
			var d: Dictionary = g.data["descs"][p["di"]]
			var part: Dictionary = d["parts"][p["pi"]]
			var c: Array[Vector3] = view._corners(d, part, 16.0)
			for i in c.size():
				c[i] += (p["shift"] as Vector3)
			gate_quads.append(c)

		var neighbor_quads: Array = []
		for entry in level.decorations:
			var ex := int(entry.get("x", 0))
			var ey := int(entry.get("y", 0))
			if absi(ex - gate_tile.x) > 2 or absi(ey - gate_tile.y) > 2:
				continue
			var cid := int(entry.get("coastal_id", 0))
			if cid == 0 or cid == 43 or cid == 44:
				continue
			var parts: Array = pack.get_decoration_parts(cid)
			var cx := (float(ex) + 0.5) * tile_px
			var cz := (float(ey) + 0.5) * tile_px
			var jit: Vector2 = level.jitter_at(ex, ey)
			for part in parts:
				if not part.has("corners"):
					continue
				var off: Array = part.get("offset", [0.0, 0.0])
				var j := jit if part.get("jitter", false) else Vector2.ZERO
				var zoff: float = part.get("zoff", 0.0)
				var sid: String = part.get("sprite_id", "")
				var s := pack.get_sprite(sid)
				var kind := String(s.get("kind", "sprite"))
				var ground_y: float = DecorationField3D.SHADOW_Z_BIAS if kind == "effect" else 0.5
				var quad: Array[Vector3] = []
				for c in part["corners"]:
					quad.append(Vector3(cx + j.x + off[0] + c[0], c[2] + zoff + ground_y, cz + j.y + off[1] + c[1]))
				neighbor_quads.append(quad)
		if not neighbor_quads.is_empty():
			checked_with_neighbors += 1

		var all_quads: Array = gate_quads + neighbor_quads
		var pairs := CoplanarParts.covered_pairs(all_quads)
		for pr in pairs:
			if int(pr[0]) < gate_quads.size() or int(pr[1]) < gate_quads.size():
				total_gate_pairs += 1
		view.free()

	check("most gates really do have a decoration within 2 tiles (a real test, not a vacuous pass)", checked_with_neighbors > gate_tiles.size() / 2, str(checked_with_neighbors))
	check("no gate placement ties the plane of a neighbouring decoration any more", total_gate_pairs == 0, str(total_gate_pairs) + " ties remain")

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
