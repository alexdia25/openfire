# Confirms the gate's traced sound cues: GateMove (document 82, FUN_00432270) fires once at creation --
# right when a gate wakes -- and again (FUN_004322f0) when a fully open gate decides to close; GateClose
# fires the tick it finishes closing. Per-tick, GateMove is still untraced on the opening side itself (no
# repeat sound while the bars are actually sliding apart) -- only the one-shot creation call was missing.
# Run:
#   godot --headless --path . --script tools/tests/gate_sound_check.gd
extends SceneTree

var cues: Array[String] = []


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
	mc.sound_at.connect(func(id, _at, _z): cues.append(id))   # a gate's sounds come from the gate (issue #22)

	# A synthetic gate, independent of whether this level happens to place one (RFMAP001 does not):
	# real gate data (Pack.gates), an arbitrary tile.
	var gate_id: String = pack.gates.keys()[0]
	var t := Vector2i(5, 5)
	var g := Gate.new()
	g.setup(t, int(gate_id), pack.gates[gate_id], 0, float(pack.tile_size_px), mc.vehicle)
	g.sound_cue.connect(func(c): mc._sound_at(c, g.centre))
	mc.vehicle.position = g.centre   # keep the carrier inside the watch region while it opens
	var dt := 1.0 / Gate.TICK_HZ
	var no_block := func(_bars): return false

	while g.open < Gate.OPEN_MAX:   # drive it fully open, carrier still in the region
		g.tick(dt, no_block)
	print("cues from ticking while opening (carrier still present): ", cues, " (expect none -- GateMove is untraced on the opening TICKS themselves)")

	mc.vehicle.position = g.centre + Vector2(10000.0, 0.0)   # carrier leaves -> tick() sets target = 0.0
	g.tick(dt, no_block)
	print("GateMove fired once the carrier leaves: ", cues.has("GateMove"))

	cues.clear()
	while g.open > 0.0:
		g.tick(dt, no_block)
	print("GateClose fired on first closed tick: ", cues, " (expect exactly [\"GateClose\"])")

	# The one-shot creation cue (FUN_00432270), via the real match-controller path this time, not a synthetic Gate:
	cues.clear()
	level.decorations.append({"x": 6, "y": 6, "coastal_id": int(gate_id), "variant": 0})   # a fresh tile, not one LevelData already indexed
	mc.debug_open_gate(Vector2i(6, 6))
	print("GateMove fires once, right when the gate is created: ", cues, " (expect exactly [\"GateMove\"])")
	print("done")
	quit()
