# The computer players' harness (alexdia25/openfire#77, wiki documents 142, 145 and 146): two computer players against each other on Return
# Fire's two-sided maps, headless, no level scene, fixed ticks. Per map: whether they met (came within sight), how close they got, how
# often they got stuck, the path searches and tiles worked out, the time the brains took, the fighting (shots, hits on vehicles, kills,
# Drones sent and shot down), the longest either stayed by the other's pad without leaving (not withdrawing, or not moving) while that side's vehicle was protected (no spawn camping), and how the
# match stood at the end.
# Seeded, so a run repeats.
#   RF_AI_LEVELS=RFMAP101,RFMAP150   the maps (default: every 10th two-sided map, RF_AI_EVERY=5 every 5th); "all" = all two-sided maps
#   RF_AI_TICKS=6000                 ticks per map (62.5 a second)
#   RF_AI_CHECK=1                    exit 1 when one stayed stuck, or (with RF_AI_PLAN=hunt) the players never met though a land route joins
#                                    the bases that is short enough to drive in the time, or one camped a pad (stayed within
#                                    AIBrain.keep_out_px of it for more than 4 s while that side's vehicle was
#                                    protected, without withdrawing, or withdrawing but not moving); a map whose bases
#                                    only water joins needs the Heli or the swimming Jeep (phase 5)
#   RF_AI_PLAN=attack|hunt|defend    every computer player keeps that plan (default: they choose)
#   RF_AI_PASSIVE=1                  side 1 takes its vehicle and then does nothing: can side 0 win against the map alone?
#   RF_AI_DRAIN=2000                 every so many ticks side 0's vehicle loses its fuel, then its shots, in turn: does it get served?
#   RF_AI_TRACE=1                    print both players' state every 2 seconds (tile, mode, speed, path, the next waypoint and its cost)
# Run:
#   godot --headless --audio-driver Dummy --path . --script res://tools/tests/ai_match_harness.gd
extends SceneTree

const PACK := "res://packs/original_pc"
const DT := 1.0 / 62.5
const HALF_SPEED_PX_PER_TICK := 0.5   ## half a Tank's top speed (1.05 units a tick): a route this long a tick is drivable in the time
const CAMP_LIMIT_TICKS := 250         ## spawn camping: longer than this (4 s) by a protected vehicle's pad without leaving
const LEAVING_TICKS := 62             ## checked about once a second
const LEAVING_PX := 16.0              ## a vehicle driving away moves at least this much in a second (a Tank: about 65 px)


## A computer player that leaves the hangar and stays by its pad (RF_AI_PASSIVE).
class PassiveBrain extends AIBrain:
	func think(mc: MatchController, ps: PlayerSlot, prev: int) -> int:
		return AIMotor.choice_word(mc, ps, -1, prev) if ps.selecting else 0


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
	print("map       land  route_px  met@tick  closest  stuck  ms/tick  shots  hits  kills  drones  camped  end")
	var failures := 0
	var totals := {"shots": 0, "turret_shots": 0, "hits": 0, "kills": 0, "drones": 0, "drones_down": 0, "targets": 0, "flags": 0, "wins": 0, "plans": 0, "swaps": 0, "serves": 0, "mines": 0}
	var plan_ticks := [0, 0, 0]
	var by_side := [0, 0]
	for id in levels:
		seed(77)
		var r := _run_level(pack, id, ticks, root)
		print("%-9s %-4s  %8.0f  %8s  %7.0f  %5d  %7.2f  %5d  %4d  %5d  %3d/%-3d  %6d  %s" % [id, "yes" if r.land else "no", r.route_px,
			str(r.met) if r.met >= 0 else "never", r.closest, r.stuck, r.ms_per_tick, r.shots, r.hits, r.kills, r.drones_down, r.drones,
			r.camp_ticks, r.end])
		var must_meet: bool = OS.get_environment("RF_AI_PLAN") == "hunt"   # with the objective in play they may never need to
		if (must_meet and r.met < 0 and r.land and r.route_px < ticks * HALF_SPEED_PX_PER_TICK) or r.stuck_long or r.camp_ticks > CAMP_LIMIT_TICKS:
			failures += 1
		for k in totals:
			totals[k] += r[k]
		for k in 3:
			plan_ticks[k] += r.plan_ticks[k]
		if r.winner >= 0:
			by_side[r.winner] += 1
	print("totals: %s" % totals)
	print("wins by side: %s; ticks in attack / hunt / defend: %s" % [by_side, plan_ticks])
	print("ai_match_harness: %d maps, %d with a long stick, no meeting on a drivable land route, or a camped pad" % [levels.size(), failures])
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
	var every := int(OS.get_environment("RF_AI_EVERY")) if OS.get_environment("RF_AI_EVERY") != "" else 10
	var out: Array = []
	for i in range(0, two.size(), every):
		out.append(two[i])
	return out


func _run_level(pack: Pack, id: String, ticks: int, root: Node) -> Dictionary:
	var level := LevelData.new()
	level.load_from(pack.level_dir(id), pack.level_override_paths(id))
	var mc := MatchController.new()
	mc.ai_players = [0]
	root.add_child(mc)
	mc.setup(pack, level, PACK, root)
	if OS.get_environment("RF_AI_PASSIVE") == "1":
		(mc.slots[1].controls as AIControls).brain = PassiveBrain.new()
		mc._drone_cap_override = 0   # it stands still: the camp rule would send Drones at it all game
	var lg := NavGrid.for_vehicle(mc, mc.slots[0].vehicle)
	var route := lg.find_path(lg.tile_of(mc.slots[0].spawn_px), lg.tile_of(mc.slots[1].spawn_px), 200000)
	var route_px := 0.0
	var from := mc.slots[0].spawn_px
	for p in route:
		route_px += from.distance_to(p)
		from = p
	var r := {"land": not route.is_empty() and lg.tile_of(route[route.size() - 1]) == lg.tile_of(mc.slots[1].spawn_px), "route_px": route_px, "met": -1, "closest": INF, "stuck": 0, "searches": 0, "tiles": 0, "brain_ms": 0.0, "ms_per_tick": 0.0, "end": "", "stuck_long": false,
		"shots": 0, "hits": 0, "kills": 0, "drones": 0, "drones_down": 0, "targets": 0, "flags": 0, "wins": 0, "plans": 0, "swaps": 0, "serves": 0, "mines": 0, "camp_ticks": 0, "camp_note": "", "turret_shots": 0, "winner": -1, "ended_at": -1, "plan_ticks": [0, 0, 0]}
	# the level scene's half of a destroyed or crushed tile (TerrainView3D._apply_tile_destroyed / _clear_tile_decoration), applied after the
	# tick: without it a tile shot down would never change
	var fallen: Array = []
	var crushed: Array = []
	mc.tile_destroyed.connect(func(t: Vector2i): fallen.append([t, level.get_coastal_id(t.x, t.y)]))
	mc.target_hit.connect(func(_pool: String, t: Vector2i):   # an active target reports here instead (TerrainView3D._on_target_hit)
		fallen.append([t, level.get_coastal_id(t.x, t.y)])
		r.targets += 1)
	mc.tile_crushed.connect(func(t: Vector2i): crushed.append(t))
	var tiles_down := [0]
	var still := [0, 0]
	var shots := [0, 0]
	var turret_shots := [0]   # shots that left with the turret turned more than 10 degrees off the hull (the Tank aiming without turning)
	for k in 2:
		var sv: Vehicle = mc.slots[k].vehicle
		sv.shot.connect(func(_spec):
			shots[k] += 1
			if absf(wrapf(sv.turret_deg, -180.0, 180.0)) > 10.0:
				turret_shots[0] += 1)
	var hp := [mc.slots[0].vehicle.hp, mc.slots[1].vehicle.hp]
	var drain := int(OS.get_environment("RF_AI_DRAIN"))
	var mines_laid := [0]
	mc.mine_added.connect(func(m): mines_laid[0] += 1 if m.dropper != null else 0)
	var camp := [0, 0]
	var ended_at := [-1]
	var docking := [false, false]
	var camp_from := [Vector2(INF, INF), Vector2(INF, INF)]
	var was_alive := [true, true]
	var sent: Array = []
	mc.drone_created.connect(func(d: Drone): sent.append(d))
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
		if drain > 0 and i % drain == drain - 1 and mc.slots[0].vehicle != null and is_instance_valid(mc.slots[0].vehicle):
			var dv: Vehicle = mc.slots[0].vehicle
			if i / drain % 2 == 0:
				dv.fuel = minf(dv.fuel, dv.fuel_max * 0.1)
			else:
				dv.ammo[0] = 0
		if mc.match_finished:
			ended_at[0] = i
			break
		for k in 2:
			if mc.slots[k].dock_state != 0 and not docking[k]:
				r.swaps += 1
			docking[k] = mc.slots[k].dock_state != 0
		# hits and kills (each vehicle's lost hit points, and its deaths); no spawn camping: while a side's vehicle is protected (AIBrain.protected:
		# dead, in the hangar, docked, or just out and by its pad), the longest the other side's vehicle stays within PAD_KEEP_OUT_PX of that pad
		for k in 2:
			var vk: Vehicle = mc.slots[k].vehicle
			if vk.alive and vk.hp < hp[k]:
				r.hits += 1
			if was_alive[k] and not vk.alive:
				r.kills += 1
			hp[k] = vk.hp
			was_alive[k] = vk.alive
			var other: PlayerSlot = mc.slots[1 - k]
			var kb: AIBrain = (mc.slots[k].controls as AIControls).brain
			var pd := vk.position.distance_to(other.spawn_px)
			var driving: bool = vk.alive and not vk.frozen and mc.slots[k].death_phase == 0 and not mc.slots[k].selecting   # not a wreck, not in the hangar
			if kb.protected(mc, other) and driving and pd < AIBrain.keep_out_px(mc, other):
				if i % LEAVING_TICKS == 0:
					# every second: still by the pad and not leaving (not withdrawing, or withdrawing but not moving: stuck) counts as camping
					var moved := vk.position.distance_to(camp_from[k]) if camp_from[k].x != INF else INF
					var leaving: bool = kb.mode in ["withdraw", "swap", "rescue"] and moved >= LEAVING_PX
					if not leaving and kb.mode not in ["attack", "clear", "fetch", "carry", "guard"]:   # an objective, or what it defends, may lie by their pad: that is not waiting for a vehicle
						camp[k] += LEAVING_TICKS
						if camp[k] > r.camp_ticks:
							r.camp_ticks = camp[k]
							r.camp_note = "side%d %s %s at %d px t%d" % [mc.slots[k].index, kb.mode, ["vehicle", "tile", "drone"][kb.target.kind] if kb.target != null else "-",
								int(pd), i]
					else:
						camp[k] = 0
					camp_from[k] = vk.position
			else:
				camp[k] = 0
				camp_from[k] = Vector2(INF, INF)
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
				print("  t%d side%d %s %s z%.1f sp%.1f hd%.0f water%d path%d next %s stuck%d blocked%s hp%.0f type%d plan%d breach%s turret%.0f shot%s" % [i, ps.index, tb.mode, g.tile_of(tv.position),
					tv.z, tv.speed, tv.heading_deg, tv.water_class, tb.nav.path.size(), nxt, tb.nav.stuck_count, tv.last_blocked_tile, tv.hp, tv.vehicle_type,
					tb.strategy.plan, tb.nav.breach_tile, tv.turret_deg, tb.gunner.last_flight])
				var tt := tb.strategy.target_tile(mc, ps)
				print("    target %s hp%d dist%.0f line'%s' goaltile %s" % [tt, mc.tile_hp(tt), tv.position.distance_to(mc.tile_aim_point(tt)),
					tb.gunner.line_to(mc, tv, AITarget.of_tile(mc, tt)), tb.nav.goal_tile])
		# "stuck long": a free, live vehicle that has not moved 16 px in 10 seconds while its brain wants to go somewhere
		for k in 2:
			var ps: PlayerSlot = mc.slots[k]
			var v := ps.vehicle
			var brain: AIBrain = (ps.controls as AIControls).brain
			if v.alive and not v.frozen and brain.mode in ["hunt", "approach", "withdraw", "attack", "clear", "fetch", "carry", "rescue", "swap", "guard"] and not brain.nav.path.is_empty():
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
	r.shots = shots[0] + shots[1]
	r.flags = mc.flags.size()
	r.winner = mc.winner_idx if mc.match_finished and mc.winner_idx >= 0 else -1
	r.wins = 1 if r.winner >= 0 else 0
	r.ended_at = ended_at[0]
	r.plan_ticks = [0, 0, 0]
	for ps in mc.slots:
		var st: AIStrategy = (ps.controls as AIControls).brain.strategy
		r.plans += st.plans_made
		r.serves += st.serves
		for k in 3:
			r.plan_ticks[k] += st.ticks_in[k]
	r.drones = sent.size()
	r.mines = mines_laid[0]
	for d in sent:
		if d.killed:
			r.drones_down += 1
	r.turret_shots = turret_shots[0]
	r.end = "%s targets %d flags %d plans %d swaps %d serves %d mines %d; shots %s (turret turned: %d), tiles down %d; " % ["WON side%d t%d;" % [r.winner, r.ended_at] if r.winner >= 0 else "no winner;",
		r.targets, r.flags, r.plans, r.swaps, r.serves, r.mines, shots, turret_shots[0], tiles_down[0]] + ("finished winner %d; " % mc.winner_idx if mc.match_finished else "") + ", ".join(parts) + (" STUCK-LONG" if r.stuck_long else "") + (" camped: " + r.camp_note if r.camp_note != "" else "")
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
