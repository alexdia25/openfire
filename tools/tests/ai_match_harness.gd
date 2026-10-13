# The computer players' harness (alexdia25/openfire#77, wiki documents 142 and 145): two computer players against each other on Return
# Fire's two-sided maps, headless, no level scene, fixed ticks. Per map: whether they met (came within sight), how close they got, how
# often they got stuck, the path searches and tiles worked out, the time the brains took, and how the match stood at the end.
# Seeded, so a run repeats.
#   RF_AI_LEVELS=RFMAP101,RFMAP150   the maps (default: every 10th two-sided map); "all" = all two-sided maps
#   RF_AI_TICKS=6000                 ticks per map (62.5 a second)
#   RF_AI_CHECK=1                    exit 1 when one stayed stuck, or the players never met though a land route joins the bases that is
#                                    short enough to drive in the time (at half a Tank's top speed); a map whose bases only water joins
#                                    needs the Heli or the swimming Jeep (phase 5)
#   RF_AI_TRACE=1                    print both players' state every 2 seconds (tile, mode, speed, path, the next waypoint and its cost)
# Run:
#   godot --headless --audio-driver Dummy --path . --script res://tools/tests/ai_match_harness.gd
extends SceneTree

const PACK := "res://packs/original_pc"
const DT := 1.0 / 62.5
const HALF_SPEED_PX_PER_TICK := 0.5   ## half a Tank's top speed (1.05 units a tick): a route this long a tick is drivable in the time


func _init() -> void:
	var pack := Pack.new()
	if not pack.load_from(PACK):
		push_error("no pack at " + PACK)
		quit(2)
		return
	var ticks := int(OS.get_environment("RF_AI_TICKS")) if OS.get_environment("RF_AI_TICKS") != "" else 6000
	var levels := _levels(pack)
	var root := Node2D.new()
	get_root().add_child(root)
	print("map       land  route_px  met@tick  closest  stuck  searches  sampled  nodes_ms  ms/tick  end")
	var failures := 0
	for id in levels:
		seed(77)
		var r := _run_level(pack, id, ticks, root)
		print("%-9s %-4s  %8.0f  %8s  %7.0f  %5d  %8d  %7d  %8.0f  %7.2f  %s" % [id, "yes" if r.land else "no", r.route_px, str(r.met) if r.met >= 0 else "never", r.closest, r.stuck, r.searches,
			r.tiles, r.brain_ms, r.ms_per_tick, r.end])
		if (r.met < 0 and r.land and r.route_px < ticks * HALF_SPEED_PX_PER_TICK) or r.stuck_long:
			failures += 1
	print("ai_match_harness: %d maps, %d with a long stick or no meeting on a drivable land route" % [levels.size(), failures])
	quit(1 if failures > 0 and OS.get_environment("RF_AI_CHECK") == "1" else 0)


func _levels(pack: Pack) -> Array:
	var want := OS.get_environment("RF_AI_LEVELS")
	var two: Array = []
	for id in pack.list_levels():
		if LevelData.peek_players(pack.level_dir(id)) == 2:
			two.append(id)
	two.sort()
	if want == "all":
		return two
	if want != "":
		return Array(want.split(",", false))
	var out: Array = []
	for i in range(0, two.size(), 10):
		out.append(two[i])
	return out


func _run_level(pack: Pack, id: String, ticks: int, root: Node) -> Dictionary:
	var level := LevelData.new()
	level.load_from(pack.level_dir(id), pack.level_override_paths(id))
	var mc := MatchController.new()
	mc.ai_players = [0]
	root.add_child(mc)
	mc.setup(pack, level, PACK, root)
	var lg := NavGrid.for_vehicle(mc, mc.slots[0].vehicle)
	var route := lg.find_path(lg.tile_of(mc.slots[0].spawn_px), lg.tile_of(mc.slots[1].spawn_px), 200000)
	var route_px := 0.0
	var from := mc.slots[0].spawn_px
	for p in route:
		route_px += from.distance_to(p)
		from = p
	var r := {"land": not route.is_empty() and lg.tile_of(route[route.size() - 1]) == lg.tile_of(mc.slots[1].spawn_px), "route_px": route_px, "met": -1, "closest": INF, "stuck": 0, "searches": 0, "tiles": 0, "brain_ms": 0.0, "ms_per_tick": 0.0, "end": "", "stuck_long": false}
	# the level scene's half of a destroyed or crushed tile (TerrainView3D._apply_tile_destroyed / _clear_tile_decoration), applied after the
	# tick: without it a tile shot down would never change
	var fallen: Array = []
	var crushed: Array = []
	mc.tile_destroyed.connect(func(t: Vector2i): fallen.append([t, level.get_coastal_id(t.x, t.y)]))
	mc.tile_crushed.connect(func(t: Vector2i): crushed.append(t))
	var tiles_down := [0]
	var still := [0, 0]
	var shots := [0, 0]
	for k in 2:
		mc.slots[k].vehicle.shot.connect(func(_spec): shots[k] += 1)
	var last := [Vector2.ZERO, Vector2.ZERO]
	var t0 := Time.get_ticks_usec()
	for i in ticks:
		# every node of the match takes its tick, as the scene tree would run them: the vehicles (which poll the brains), shells, flags ...
		var b0 := Time.get_ticks_usec()
		for c in root.get_children():
			if c != mc and c.has_method("_process"):
				c._process(DT)
		r.brain_ms += (Time.get_ticks_usec() - b0) / 1000.0
		mc._process(DT)
		for f in fallen:
			_apply_tile_destroyed(pack, level, mc, f[0], f[1])
			tiles_down[0] += 1
		for t in crushed:
			level.set_coastal_id(t.x, t.y, 0)
		fallen.clear()
		crushed.clear()
		if mc.match_finished:
			break
		var a: Vehicle = mc.slots[0].vehicle
		var b: Vehicle = mc.slots[1].vehicle
		if a.alive and b.alive and not a.frozen and not b.frozen:
			var d := a.position.distance_to(b.position)
			r.closest = minf(r.closest, d)
			if d <= AIBrain.SIGHT_PX and r.met < 0:
				r.met = i
		if OS.get_environment("RF_AI_TRACE") == "1" and i % 125 == 0:
			for ps in mc.slots:
				var tv := ps.vehicle
				var tb: AIBrain = (ps.controls as AIControls).brain
				var g := NavGrid.for_vehicle(mc, tv)
				var nxt := "-" if tb.nav.path.is_empty() else "%s c%.2f" % [g.tile_of(tb.nav.path[0]), g.cost(g.tile_of(tb.nav.path[0]))]
				print("  t%d side%d %s %s z%.1f sp%.1f hd%.0f water%d path%d next %s stuck%d blocked%s hp%.0f type%d" % [i, ps.index, tb.mode, g.tile_of(tv.position),
					tv.z, tv.speed, tv.heading_deg, tv.water_class, tb.nav.path.size(), nxt, tb.nav.stuck_count, tv.last_blocked_tile, tv.hp, tv.vehicle_type])
		# "stuck long": a free, live vehicle that has not moved 16 px in 10 seconds while its brain wants to go somewhere
		for k in 2:
			var ps: PlayerSlot = mc.slots[k]
			var v := ps.vehicle
			var brain: AIBrain = (ps.controls as AIControls).brain
			if v.alive and not v.frozen and brain.mode in ["advance", "approach"] and not brain.nav.path.is_empty():
				if v.position.distance_to(last[k]) < 16.0:
					still[k] += 1
					if still[k] > 625:
						r.stuck_long = true
				else:
					still[k] = 0
					last[k] = v.position
			else:
				still[k] = 0
				last[k] = v.position
	r.ms_per_tick = (Time.get_ticks_usec() - t0) / 1000.0 / ticks
	for ps in mc.slots:
		var brain: AIBrain = (ps.controls as AIControls).brain
		r.stuck += brain.nav.stuck_count
	for g in (mc.get_meta("ai_nav_grids", {}) as Dictionary).values():
		r.searches += g.searches
		r.tiles += g.tiles_sampled + g.steps_sampled
	var parts: Array = []
	for ps in mc.slots:
		parts.append("side%d %s hp%.0f stock%s" % [ps.index, (ps.controls as AIControls).brain.mode, ps.vehicle.hp, str(ps.stock)])
	r.end = "shots %s, tiles down %d; " % [shots, tiles_down[0]] + ("finished winner %d; " % mc.winner_idx if mc.match_finished else "") + ", ".join(parts) + (" STUCK-LONG" if r.stuck_long else "")
	for c in root.get_children():
		c.free()
	return r


## TerrainView3D._apply_tile_destroyed without the drawing: the destroyed tile takes its coastal entry's next id and art.
func _apply_tile_destroyed(pack: Pack, level: LevelData, mc: MatchController, tile: Vector2i, coastal_id: int) -> void:
	var e := pack.get_coastal_damage(coastal_id)
	var next_id := int(e.get("destroyed_coastal", 0))
	var offset := int(e.get("destroyed_art_offset", 0))
	var art := level.get_art_id(tile.x, tile.y)
	if next_id == 0:
		level.set_coastal_id(tile.x, tile.y, 0)
		art = offset & 0x7F
	else:
		var ne := pack.get_coastal_damage(next_id)
		var base := int(ne.get("base_art", 255))
		if base != 255:
			art = base
			if int(ne.get("flags", 0)) == 8:
				art += level.get_variant(tile.x, tile.y)
		level.set_coastal_id(tile.x, tile.y, next_id)
		if offset != 0:
			art = offset & 0x7F
	level.set_art_id(tile.x, tile.y, art)
	mc.tile_state_applied(tile)
