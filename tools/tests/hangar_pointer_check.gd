# The hangar's selection pointer (issue #38): the three 35 x 2 cels 2091-2093 light two or three of the rail's seven slots (one every
# 5 pixels, x = 1 + 5 * slot) in turn, and the cursor's bay draws them at its table position, the same way for all four bays -- the
# reference footage (about 181-189 s) shows no mirroring for the right-hand bays and no drop. Run:
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
	for bay in 4:
		var e: Dictionary = sel["entries"][str(bay)]
		check("bay %d (%s): no mirror or extra offset in the data" % [bay, e["name"]], not e.has("pointer_mirror") and not sel.has("pointer_draw"))
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
