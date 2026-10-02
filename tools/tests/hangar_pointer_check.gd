# The hangar's selection pointer (issue #38, FUN_00417d60): the original mirrors it for a bay whose table x is past
# 60 px (`0x3c0000 < x`), i.e. the right-hand bays, and places it at +(0.4, 1) px with a slightly narrower cel. The pack
# carries both as data (tools/data/selector.json: per-entry `pointer_mirror`, `pointer_draw`). Run:
#   godot --headless --path . --script tools/tests/hangar_pointer_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var sel: Dictionary = pack.selector_data
	var mirrored := []
	for bay in 4:
		var e: Dictionary = sel["entries"][str(bay)]
		var expect: bool = float(e["pointer"][0]) > 60.0
		check("bay %d (%s): mirrored exactly when its pointer x (%s) is past 60" % [bay, e["name"], e["pointer"][0]], bool(e.get("pointer_mirror", false)) == expect)
		if expect:
			mirrored.append(e["name"])
	check("the right-hand bays (Tank, Jeep) are the mirrored ones", mirrored == ["Tank", "Jeep"], str(mirrored))
	var d: Dictionary = sel["pointer_draw"]
	check("offset (0x6666, 0x10000) = (0.4, 1.0) px", is_equal_approx(float(d["offset"][0]), 0.4) and is_equal_approx(float(d["offset"][1]), 1.0))
	check("scale 1 - 0x4000 / 0x100000 = 0.984375, mirrored (0x8000 - HDX) = -0.953125", is_equal_approx(float(d["scale_x"]), 0.984375) and is_equal_approx(float(d["mirror_scale_x"]), 0.953125))
	# the three pointer cels light two or three of the rail's seven slots (5 px apart) between them: the pattern is the art's own
	var lit := []
	for id in sel["sprites"]["pointer"]:
		var img := pack.get_sprite_image(String(id))
		var cols := []
		for x in img.get_width():
			if img.get_pixel(x, 0).a > 0.0 and (x == 0 or img.get_pixel(x - 1, 0).a == 0.0):
				cols.append(x)
		lit.append(cols)
	check("pointer frames light slots [2,5] / [0,3,6] / [1,4] of the seven (x = 1 + 5 * slot)", lit == [[11, 26], [1, 16, 31], [6, 21]], str(lit))
	print("hangar_pointer_check: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
