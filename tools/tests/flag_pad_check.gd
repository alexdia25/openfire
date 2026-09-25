# The flag and the pad (document 99): a flag taken plays Ding; a Jeep docking with its own team's flag returns it; the lift's shared update (FUN_0042ec50) destroys mines at the
# pad, returns the pad team's flag lying by it and counts the other team's as captured. Run:
#   godot --headless --path . --script tools/tests/flag_pad_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _match(pack: Pack, level_id: String) -> MatchController:
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/" + level_id))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	return mc


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var tile := float(pack.tile_size_px)

	# level 1: the enemy flag, a mine and the pad
	var mc := _match(pack, "RFMAP001")
	var v := mc.vehicle
	v.set_vehicle_type(1)
	var cues: Array = []
	v.sound_cue.connect(func(c): cues.append(c))
	mc._spawn_flag("b", v.position + Vector2(200, 0))
	var flag: FlagMarker = mc.flags[1]
	mc._attach_flag(flag, v)
	check("taking a flag plays Ding", cues == ["Ding"], str(cues))
	flag.carrier = null
	mc._on_mine_dropped(v.position + Vector2(5, 5), v)
	mc._on_mine_dropped(v.position + Vector2(100, 0), v)
	mc._pad_centre = v.position
	mc._pad_clear()
	check("the pad being closed clears nothing", mc.mines.size() == 2 and not mc.match_finished)
	mc.pad_open = true
	mc._pad_clear()
	check("an open pad destroys the mine within 20 units and leaves the one 100 away", mc.mines.size() == 1, str(mc.mines.size()))
	flag.position = v.position + Vector2(tile * 1.2, 0)
	mc._pad_clear()
	check("the OTHER team's flag lying by the open pad is a capture: the pad's team wins", mc.match_finished and mc.winner_idx == 0, "finished %s winner %d" % [mc.match_finished, mc.winner_idx])

	# a two-player level: the own flag
	var id2 := ""
	for id in pack.list_levels():
		var lv := LevelData.new()
		lv.load_from("res://packs/original_pc/levels/" + id)
		if lv.spawn_points.size() >= 2 and not lv.candidate_pools.get("a", []).is_empty() and not lv.candidate_pools.get("b", []).is_empty():
			id2 = id
			break
	check("found a two-player level with own-pool candidates", id2 != "", id2)
	var m2 := _match(pack, id2)
	var j := m2.vehicle
	j.set_vehicle_type(1)
	var cues2: Array = []
	j.sound_cue.connect(func(c): cues2.append(c))
	var idx := j.player_index()   # the player's side in this level (the own pool is "a" for side 0, "b" for side 1)
	var pool_id := "a" if idx == 0 else "b"
	var pool: TargetPool = m2.pools[pool_id]
	pool.active_index = -1
	m2._spawn_flag(pool_id, j.position)
	var own: FlagMarker = m2.flags[idx]
	own.carrier = j
	m2._return_own_flag(j)
	check("a Jeep carrying its own flag: Ding, the flag is removed and a target is active again", cues2 == ["Ding"] and not m2.flags.has(idx) and pool.active_index >= 0, "%s %s %d" % [cues2, m2.flags.has(idx), pool.active_index])
	# with no intact candidate the flag moves to a candidate tile
	m2._spawn_flag(pool_id, j.position)
	var own2: FlagMarker = m2.flags[idx]
	own2.carrier = j
	for i in pool.intact.size():
		pool.intact[i] = false
	pool.active_index = -1
	m2._return_own_flag(j)
	var t := Vector2i(int(own2.position.x / tile), int(own2.position.y / tile))
	check("... and with none intact it moves onto a candidate tile", m2.flags.has(idx) and own2.carrier == null and pool.candidates.has(t), str(t))
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
