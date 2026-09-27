# The Tank's drawn geometry (game/vehicle_box_3d.gd: the six hull faces and the eight turret parts, the barrel cluster at several gun elevations) has no part lying in the
# plane of an earlier overlapping one, so nothing there can z-fight the way the Jeep's wheel strips did (document 102). Run:
#   godot --headless --path . --script tools/tests/tank_coplanar_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


## A hull face as four corners in the box renderer's local space (the Sprite3D's own axes: "top" lies in x-z, "side_x" spans z and y, "side_z" spans x and y).
func _face_quad(f: Dictionary) -> Array:
	var c: Vector3 = f["center"]
	var h: Vector2 = f["half"]
	match String(f["axis"]):
		"top":
			return [c + Vector3(-h.x, 0, -h.y), c + Vector3(h.x, 0, -h.y), c + Vector3(h.x, 0, h.y), c + Vector3(-h.x, 0, h.y)]
		"side_x":
			return [c + Vector3(0, h.y, -h.x), c + Vector3(0, h.y, h.x), c + Vector3(0, -h.y, h.x), c + Vector3(0, -h.y, -h.x)]
	return [c + Vector3(-h.x, h.y, 0), c + Vector3(h.x, h.y, 0), c + Vector3(h.x, -h.y, 0), c + Vector3(-h.x, -h.y, 0)]


func _init() -> void:
	var render := VehicleBoxRender3D.new()
	var faces: Array = []
	for f in VehicleBoxRender3D.FACES:
		faces.append(_face_quad(f))
	for elev in [0.0, 8.0, 16.0, 25.0]:
		render._elev_shown = elev
		var quads: Array = faces.duplicate()
		for i in VehicleBoxRender3D.TURRET_PARTS.size():
			var q: Array[Vector3] = []
			for p in render._turret_corners(i):
				q.append(p)
			quads.append(q)
		var pairs := CoplanarParts.covered_pairs(quads)
		check("elevation %d: no part lies in the plane of an earlier overlapping part" % int(elev), pairs.is_empty(), str(pairs))
	# the shifts helper itself: a wheel-strip-like pair is found, a tilted pair is not
	var strip := [Vector3(0, 8, -12), Vector3(0, 8, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	var panel := [Vector3(0, 13, -12), Vector3(0, 13, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	check("the helper finds a strip inside a panel in one plane", CoplanarParts.covered_pairs([panel, strip]) == [[0, 1]])
	var tilted := [Vector3(0.5, 8, -12), Vector3(0.5, 8, 12), Vector3(0, 0, 12), Vector3(0, 0, -12)]
	check("and not a tilted one", CoplanarParts.covered_pairs([panel, tilted]).is_empty())
	render.free()
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
