# The Tank's drawn geometry (its definition's render descriptor: the six hull faces and the eight turret parts, the barrel cluster at several gun elevations) has no part lying in
# the plane of an earlier overlapping one, so nothing there can z-fight the way the Jeep's wheel strips did (document 102). Run:
#   godot --headless --path . --script tools/tests/tank_coplanar_check.gd
# (Return Fire's own descriptors checked; the shift mechanism itself is openfire-engine's tests/coplanar_parts_check.gd, issue #65.)
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := ModLoader.load_game_pack()
	var v := Vehicle.new()
	v.team = "tan"
	v.setup(pack)
	v.set_vehicle_type(0)
	var render := VehicleRender3D.new()
	get_root().add_child(render)
	render.setup(v, pack)
	for elev in [0.0, 8.0, 16.0, 25.0]:
		v.gun_elev_deg = elev
		var quads: Array = []
		var rigs := {}
		for part in render._render["parts"]:
			var q: Array[Vector3] = []
			for c in render._corners(part, rigs):
				q.append(Vector3(c.x, c.z, c.y))
			quads.append(q)
		var pairs := CoplanarParts.covered_pairs(quads)
		check("elevation %d: no part lies in the plane of an earlier overlapping part" % int(elev), pairs.is_empty(), str(pairs))
	var shifts: Array = render._coplanar_shifts()
	var moved := 0
	for s in shifts:
		if s != Vector3.ZERO:
			moved += 1
	check("so nothing is shifted", moved == 0, str(moved))
	# the shifts helper itself: a wheel-strip-like pair is found, a tilted pair is not
	var strip := [Vector3(0, 8, -12), Vector3(0, 8, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	var panel := [Vector3(0, 13, -12), Vector3(0, 13, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	check("the helper finds a strip inside a panel in one plane", CoplanarParts.covered_pairs([panel, strip]) == [[0, 1]])
	var tilted := [Vector3(0.5, 8, -12), Vector3(0.5, 8, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	check("and not a tilted one", CoplanarParts.covered_pairs([panel, tilted]).is_empty())
	render.free()
	v.free()
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
