# Confirms the computer player uses a Jeep as the gun where nothing else reaches the target (#130): on RFMAP156 (no Heli in stock, the
# target over water from both Tank and MSV), it takes a Jeep, swims it to the target, breaches the yard's wall, drives into the target and
# its missiles break it. A lookalike (not the active one) takes 12 hits, more than a Jeep carries: then it goes home for another and comes
# back. The turrets and Drones are switched off here: with them, a one-hit-point Jeep doesn't get through the ring of turrets round that
# target.
# Run:
#   godot --headless --audio-driver Dummy --path . --script res://tools/tests/ai_jeep_gun_check.gd
extends SceneTree

const TICKS := 30000   ## a lookalike takes 12 hits (two states of 6): with walls to breach first, a trip to rearm

var failures := 0


func _check(ok: bool, what: String) -> void:
	print(("pass  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP156"))
	var root := Node2D.new()
	get_root().add_child(root)
	seed(1996)   # the computer players draw from the global generator: fixed here, so the check runs the same way every time
	var mc := MatchController.new()
	mc.match_seed = 1996
	mc.ai_players = [0]
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	mc._turret_tiles.clear()
	mc.turrets.clear()
	mc._drone_cap_override = 0
	var ps: PlayerSlot = mc.slots[0]
	var brain: AIBrain = (ps.controls as AIControls).brain
	var st := brain.strategy
	st.forced_plan = AIStrategy.Plan.ATTACK
	st.plan = AIStrategy.Plan.ATTACK

	var t := st.target_tile(mc, ps)
	_check(t.x >= 0 and st._type_in_stock(mc, ps, false, t) < 0, "RFMAP156: no gun in stock gets within a shot of the target %s" % t)
	_check(st._lobber_for(mc, ps, t, false) == 1, "a Jeep does: it is the means")
	_check(st.wanted_vehicle(mc, ps) == 1, "so it takes a Jeep from the hangar")

	# the level scene's half of a tile shot down (as tools/tests/ai_match_harness.gd does): without it a wall shot down comes back whole
	var fallen: Array = []
	mc.tile_destroyed.connect(func(f: Vector2i): fallen.append([f, level.get_coastal_id(f.x, f.y)]))
	var broke := [false]
	mc.target_hit.connect(func(_pool: String, f: Vector2i):
		fallen.append([f, level.get_coastal_id(f.x, f.y)])
		if f == t:
			broke[0] = true)

	var start_hp := mc.tile_hp(t)
	var rammed := false
	var fired := 0
	var broke_at := -1
	var dt := 1.0 / Vehicle.TICK_HZ
	for i in TICKS:
		var shots_before := mc._projectiles.size()
		for c in root.get_children():   # every node takes its tick, as the scene tree runs them (the match steps the vehicles and shots itself)
			if c != mc and c.has_method("_process"):
				c._process(dt)
		mc._process(dt)
		for f in fallen:
			_apply_tile_destroyed(pack, level, mc, f[0], f[1])
		fallen.clear()
		var v := ps.vehicle
		if v != null and v.last_blocked_tile == t:
			rammed = true
		if brain.mode == "attack" and mc._projectiles.size() > shots_before and v != null and v.vehicle_type == 1:
			fired += 1
		if broke[0] or mc.tile_hp(t) <= 0:   # the active one falls at the first state; a lookalike once it is rubble
			broke_at = i
			break
	_check(rammed, "its Jeep drove into the target tile (the missile's aim)")
	_check(fired > 0, "and fired at it (%d missiles)" % fired)
	_check(broke_at >= 0, "the target (%d hit points, %s) broke, at tick %d" % [start_hp, "the active one" if broke[0] else "a lookalike: 12 in all", broke_at])

	print("ai_jeep_gun_check: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


## The level scene's half of a destroyed tile: its next state (a copy of ai_match_harness.gd's).
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
