# The gate's own drawn parts (game/gate_view_3d.gd) flickered with the camera angle -- a reported symptom, and
# the same coplanar-tie class already fixed for the vehicles and the decoration field's shadow (document 102):
# painted in list order in the original, a depth-tested renderer can't order two quads sharing a plane. Confirms
# real ties exist in the traced gate data (not a false alarm) and that GateView3D's own outward shift actually
# resolves them, both gates (coastal id 43 and 44), across both door wings together. Run:
#   godot --headless --path . --script tools/tests/gate_coplanar_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	check("both traced gate ids are present", pack.gates.has("43") and pack.gates.has("44"))

	for gid_str in ["43", "44"]:
		var gd: Dictionary = pack.gates[gid_str]
		var g := Gate.new()
		g.setup(Vector2i(0, 0), int(gid_str), gd, 0, 32.0, null)
		var view := GateView3D.new()
		get_root().add_child(view)
		view.setup(pack, g)

		var raw_quads: Array = []
		var shifted_quads: Array = []
		for p in view._parts:
			var d: Dictionary = g.data["descs"][p["di"]]
			var part: Dictionary = d["parts"][p["pi"]]
			var c: Array[Vector3] = view._corners(d, part, 16.0)
			raw_quads.append(c)
			var sc: Array[Vector3] = []
			for v in c:
				sc.append(v + (p["shift"] as Vector3))
			shifted_quads.append(sc)

		var raw_pairs := CoplanarParts.covered_pairs(raw_quads)
		check("gate %s really has a coplanar tie in the traced data (not a false alarm)" % gid_str, not raw_pairs.is_empty(), str(raw_pairs))
		var moved := 0
		for p in view._parts:
			if (p["shift"] as Vector3) != Vector3.ZERO:
				moved += 1
		check("gate %s: GateView3D shifted exactly the covered part(s)" % gid_str, moved == raw_pairs.size(), "%d shifted, %d ties" % [moved, raw_pairs.size()])
		var shifted_pairs := CoplanarParts.covered_pairs(shifted_quads)
		check("gate %s: after the shift, no part ties another's plane any more" % gid_str, shifted_pairs.is_empty(), str(shifted_pairs))
		view.free()   # Gate is a RefCounted, not a Node -- it frees itself once `g` goes out of scope

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
