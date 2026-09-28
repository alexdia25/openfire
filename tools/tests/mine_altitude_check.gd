# Document 53's general collision rule (FUN_0041e4c0): "the two z ranges, each shifted by its object's height,
# overlap". _update_mines/_update_boxes had used a fixed 0..hit_z[1] range instead of shifting by the vehicle's
# own current v.z -- reported: mines still went off under a flying Heli. Confirms a Heli at altitude is immune
# to both a mine's own trigger box and an active explosion damage box, and that landing restores both. Run:
#   godot --headless --path . --script tools/tests/mine_altitude_check.gd
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
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var v := mc.vehicle
	v.set_vehicle_type(3)   # Heli
	var no_block := func(_bars): return false

	# Arm a mine at the vehicle's own position (the dropper isn't in danger while it's unarmed, document 60).
	mc._on_mine_dropped(v.position, null)
	var m: Mine = mc.mines[0]
	var dt := 1.0 / Mine.TICK_HZ
	while not m.armed:
		m.advance(dt * Mine.TICK_HZ)
	check("the mine is armed before the real test begins", m.armed)

	v.position = m.position
	v.moving = true
	v.z = 40.0   # well above Mine.Z_HI (0.1) once shifted: hit_z [0,10] + 40 = [40,50]
	mc._update_mines(1.0 / Vehicle.TICK_HZ)
	check("a flying Heli directly over an armed mine does NOT set it off", mc.mines.size() == 1, "mines left: %d" % mc.mines.size())

	v.z = 0.0   # landed: hit_z [0,10] + 0 overlaps the mine's [-50, 0.1]
	mc._update_mines(1.0 / Vehicle.TICK_HZ)
	check("the same Heli, landed on the same spot, DOES set it off", mc.mines.is_empty())

	# The resulting explosion box: a flying Heli over it takes no damage; landed, it does.
	check("detonating left an active damage box", not mc._boxes.is_empty())
	v.z = 40.0
	v.hp = v.max_hp
	mc._update_boxes(1.0)
	check("a flying Heli inside the box's footprint takes no damage from it", v.hp == v.max_hp, "hp %s/%s" % [v.hp, v.max_hp])
	v.z = 0.0
	mc._update_boxes(1.0)
	check("the same Heli, landed in the same footprint, DOES take damage", v.hp < v.max_hp, "hp %s/%s" % [v.hp, v.max_hp])

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
