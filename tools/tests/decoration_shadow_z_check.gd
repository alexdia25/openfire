# A structure's own ground shadow (an "effect" part, e.g. cel 1026 on the red-cross building, coastal id 36) sits strictly
# below the structure's own sprite parts even where their footprints overlap, so the two don't z-fight (the same class of bug as
# the Jeep's wheels against its side panels, document 102; user report: the shadow flickered in and out with the camera angle).
# Run: godot --headless --path . --script tools/tests/decoration_shadow_z_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	check("the shadow's ground bias is strictly below the ordinary one", DecorationField3D.SHADOW_Z_BIAS < 0.5)
	check("...by exactly one coplanar step", is_equal_approx(0.5 - DecorationField3D.SHADOW_Z_BIAS, CoplanarParts.COPLANAR_STEP))

	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var parts: Array = pack.get_decoration_parts(36)   # the red-cross building (id 36-38 are all this roof, document 44's labels)
	check("id 36 has decoration parts", not parts.is_empty())
	var shadow_y := INF
	var wall_min_y := INF
	for part in parts:
		var s := pack.get_sprite(String(part.get("sprite_id", "")))
		var is_shadow := String(s.get("kind", "sprite")) == "effect"
		var zoff: float = part.get("zoff", 0.0)
		for c in part.get("corners", []):
			var y: float = float(c[2]) + zoff
			if is_shadow:
				shadow_y = minf(shadow_y, y)
			else:
				wall_min_y = minf(wall_min_y, y)
	check("id 36 really has a ground-level shadow part and a ground-level wall corner (both z=0, confirming the overlap this fixes)",
		is_equal_approx(shadow_y, 0.0) and is_equal_approx(wall_min_y, 0.0), "shadow z=%s wall z=%s" % [shadow_y, wall_min_y])
	# the actual world-space height DecorationField3D._build() would give each: the shadow strictly below the wall's own lowest point
	var shadow_world_y := shadow_y + DecorationField3D.SHADOW_Z_BIAS
	var wall_world_y := wall_min_y + 0.5
	check("so the shadow sits strictly below the wall's own base, not tied with it", shadow_world_y < wall_world_y)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
