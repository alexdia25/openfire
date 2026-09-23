# Confirms the wreck sequence (document 87): a vehicle's death now emits a value snapshot
# (`Vehicle.wrecked`) immune to a same-frame respawn resetting the same node's fields, and the
# resulting `Wreck3D` falls from the death height (the project's known ballistic gravity, from
# rest -- see wreck_3d.gd's header for the contradiction found in the original's own fall timing,
# not resolved, so this is a guessed interpolation) before settling -- a ground vehicle's wreck
# (height 0) appears at once, a Heli shot down mid-flight visibly falls first.
# Run:
#   godot --headless --path . --script tools/tests/wreck_fall_check.gd
extends SceneTree

func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var root := Node2D.new()
	get_root().add_child(root)
	var dt := 1.0 / Vehicle.TICK_HZ

	var v := Vehicle.new()
	root.add_child(v)
	v.setup(pack)
	var snapshots: Array = []
	v.wrecked.connect(func(info): snapshots.append(info))
	v.destroyed.connect(func(_v): v.respawn(Vector2(999.0, 999.0)))  # simulates match_controller's immediate respawn

	var death_pos := v.position
	var death_heading := v.heading_deg
	v.hp = 1.0
	v.take_damage(100.0)
	print("tank respawned (alive): ", v.alive, " position ", v.position, " (expect true, (999, 999))")
	print("tank snapshot unaffected by the respawn: ", snapshots[0]["position"] == death_pos and snapshots[0]["heading_deg"] == death_heading and snapshots[0]["z"] == 0.0)

	var w := Wreck3D.new()
	root.add_child(w)
	w.setup(pack, snapshots[0]["team"], snapshots[0]["position"], snapshots[0]["heading_deg"], snapshots[0]["vehicle_type"], snapshots[0]["z"])
	print("tank wreck falling: ", w._falling, " (expect false -- height 0 at death, appears at once)")
	var ticks := 0
	while w._falling and ticks < 200:
		w._process(dt)
		ticks += 1
	print("tank wreck final height ", w._height, " (expect 0.0)")

	# A Heli shot down mid-flight: the same fall, starting from real altitude.
	v.set_vehicle_type(3)
	v.z = 60.0
	v.hp = 1.0
	v.take_damage(100.0)
	print("heli snapshot z: ", snapshots[1]["z"], " (expect 60.0)")

	var w2 := Wreck3D.new()
	root.add_child(w2)
	w2.setup(pack, snapshots[1]["team"], snapshots[1]["position"], snapshots[1]["heading_deg"], snapshots[1]["vehicle_type"], snapshots[1]["z"])
	print("heli wreck falling: ", w2._falling, " (expect true -- height 60 at death)")
	var ticks2 := 0
	while w2._falling and ticks2 < 400:
		w2._process(dt)
		ticks2 += 1
	print("heli wreck settled after ", ticks2, " ticks (expect a real fall, roughly 60-80 ticks), final height ", w2._height, " (expect 0.0)")
	print("done")
	quit()
