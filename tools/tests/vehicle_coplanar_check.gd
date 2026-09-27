# Parts of a vehicle descriptor that lie in the same plane as an earlier overlapping part are drawn over it by a small outward shift instead of a depth tie (the Jeep's wheel strips
# against its side panels z-fought). Run:  godot --headless --path . --script tools/tests/vehicle_coplanar_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


## The shifts a renderer built for vehicle type `t` computes for its parts (in the descriptor's order).
func _shifts(pack: Pack, t: int) -> Array:
	var v := Vehicle.new()
	v.team = "tan"
	v.setup(pack)
	v.set_vehicle_type(t)
	var render := VehicleRender3D.new()
	get_root().add_child(render)
	render.setup(v, pack)
	var out: Array = render._coplanar_shifts()
	render.free()
	v.free()
	return out


func _init() -> void:
	var pack := ModLoader.load_game_pack()
	var s := _shifts(pack, 1)
	check("the Jeep's left wheel strip (part 9) is shifted outward (-x) off its side panel (part 1)", s[9].x < -0.01 and absf(s[9].y) < 1e-6 and absf(s[9].z) < 1e-6, str(s[9]))
	check("the right wheel strip (part 10) is shifted outward (+x) off its panel (part 2)", s[10].x > 0.01 and absf(s[10].y) < 1e-6, str(s[10]))
	check("the side panels and every other Jeep part stay where the descriptor puts them", s[1] == Vector3.ZERO and s[2] == Vector3.ZERO and s[0] == Vector3.ZERO and s[5] == Vector3.ZERO, str(s))
	var moved := 0
	for v in s:
		if v != Vector3.ZERO:
			moved += 1
	check("exactly the two wheel strips move", moved == 2, str(moved))
	check("the shift is far under a pixel but above the depth resolution (0.0003 at 300 units, near plane 10)", absf(s[9].x) < 0.1 and absf(s[9].x) > 0.005)
	for id in ["2", "3"]:
		var t := _shifts(pack, int(id))
		var any := false
		for v in t:
			any = any or v != Vector3.ZERO
		check("type %s has no covered coplanar parts, so nothing moves" % id, not any)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
