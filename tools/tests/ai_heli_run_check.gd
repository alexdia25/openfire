# Confirms the computer player's Heli runs over a tile a turret covers (#129, AIBrain._run): it flies through instead of hovering, with
# the throttle on while it faces its way, turns about only beyond a turret's reach (RUN_PAST_PX), and fires only when a copy of its shot
# would hit. On RFMAP191, where Helis used to hover in turrets' reach and die.
# Run:
#   godot --headless --audio-driver Dummy --path . --script res://tools/tests/ai_heli_run_check.gd
extends SceneTree

var failures := 0


func _check(ok: bool, what: String) -> void:
	print(("pass  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP191"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	mc.ai_players = [0]
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var ps: PlayerSlot = mc.slots[0]
	var brain: AIBrain = (ps.controls as AIControls).brain
	var v := ps.vehicle
	v.set_vehicle_type(3)
	v.z = 50.0
	var threats := mc.turret_threats(v.player_index())
	_check(not threats.is_empty(), "RFMAP191 has a turret of the other side's")
	if threats.is_empty():
		quit(1)
		return
	var gun: Vector2i = threats[0]["tile"]
	var t := AITarget.of_tile(mc, gun)
	_check(brain.strategy.covering_gun(mc, ps, t.position) == gun, "the turret's own tile is covered by it (so a Heli makes runs at it)")

	# coming in from the west, facing it: full throttle on, and its way is through the tile
	v.position = t.position + Vector2(-300.0, 0.0)
	v.heading_deg = 0.0
	var w := brain._run(mc, v, t, 0)
	_check(w & InputWord.UP and brain._run_dir.is_equal_approx(Vector2.RIGHT), "facing the tile from 300 px: throttle on, its way east through it (0x%x)" % w)

	# over the tile, still flying east: it carries on (no turning back, no hover)
	v.position = t.position + Vector2(8.0, 0.0)
	w = brain._run(mc, v, t, 0)
	_check(w & InputWord.UP and not (w & InputWord.DOWN) and brain._run_dir.is_equal_approx(Vector2.RIGHT), "over the tile: flies on through (0x%x)" % w)

	# inside the turret's reach on the far side: still on the way out, not turning yet
	v.position = t.position + Vector2(150.0, 0.0)
	brain._run(mc, v, t, 0)
	_check(brain._run_dir.is_equal_approx(Vector2.RIGHT), "150 px past, still in the turret's reach (192): no turn yet")

	# beyond the end of the run: about, back west through it
	v.position = t.position + Vector2(AIBrain.RUN_PAST_PX, 0.0)
	w = brain._run(mc, v, t, 0)
	_check(brain._run_dir.is_equal_approx(Vector2.LEFT), "at RUN_PAST_PX past (%.0f px, beyond the turret's reach): it turns back" % AIBrain.RUN_PAST_PX)
	_check(not (w & InputWord.UP), "facing away from its new way: it turns before opening the throttle (0x%x)" % w)

	# far out, it fires nothing: a copy is only flown in reach, and a shot that would miss isn't fired
	v.position = t.position + Vector2(-300.0, 0.0)
	v.heading_deg = 0.0
	brain._run_dir = Vector2.ZERO
	brain.gunner.last_flight = {}
	w = brain._run(mc, v, t, 0)
	_check(not (w & AIMotor.button(v, "fire")) and brain.gunner.last_flight.is_empty(), "out of reach: no copy flown, no shot")
	v.position = t.position + Vector2(-60.0, 0.0)
	w = brain._run(mc, v, t, 0)
	var what := String(brain.gunner.last_flight.get("what", ""))
	_check(what != "" and bool(w & AIMotor.button(v, "fire")) == (what == "target"), "in reach: it fires exactly when the copy hits the tile (copy met '%s')" % what)

	print("ai_heli_run_check: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
