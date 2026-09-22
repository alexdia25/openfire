# Confirms the gate's traced sound cues (FUN_004322f0, document 82): GateMove fires when a fully
# open gate decides to close again, GateClose fires the tick it finishes closing. Run:
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
	mc.vehicle.sound_cue.connect(func(id): cues.append(id))

	# A synthetic gate, independent of whether this level happens to place one (RFMAP001 does not):
	# real gate data (Pack.gates), an arbitrary tile.
	var gate_id: String = pack.gates.keys()[0]
	var t := Vector2i(5, 5)
	var g := Gate.new()
	g.setup(t, int(gate_id), pack.gates[gate_id], 0, float(pack.tile_size_px), mc.vehicle)
	g.sound_cue.connect(mc.vehicle.sound_cue.emit)
	mc.vehicle.position = g.centre   # keep the carrier inside the watch region while it opens
	var dt := 1.0 / Gate.TICK_HZ
	var no_block := func(_bars): return false

	while g.open < Gate.OPEN_MAX:   # drive it fully open, carrier still in the region
		g.tick(dt, no_block)
	print("cues while opening (carrier still present): ", cues, " (expect none -- GateMove is untraced on the opening side)")

	mc.vehicle.position = g.centre + Vector2(10000.0, 0.0)   # carrier leaves -> tick() sets target = 0.0
	g.tick(dt, no_block)
	print("GateMove fired once the carrier leaves: ", cues.has("GateMove"))

	cues.clear()
	while g.open > 0.0:
		g.tick(dt, no_block)
	print("GateClose fired on first closed tick: ", cues, " (expect exactly [\"GateClose\"])")
	print("done")
	quit()
