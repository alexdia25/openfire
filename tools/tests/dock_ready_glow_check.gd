# The dock-ready cue (documents 80, 89/95, issue #37): the original lights the home pad with a real glow
# (cel 1778 / effect.glow.001, the same PRE0=5 background-recolour blend as the hangar spotlight, issue #64)
# while the vehicle sits parked and ready, not the port's earlier invented coloured ring. Run:
#   godot --headless --path . --script tools/tests/dock_ready_glow_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var sprite := pack.get_sprite("effect.glow.001")
	check("the sprite's own pack data names the brighten blend", String(sprite.get("recolour_mode", "")) == "brighten_add")
	var step := float(sprite.get("recolour_step", 0.0))
	check("...and the exact per-level step (document 9/80: +3 of 255 a level)", is_equal_approx(step, 3.0 / 255.0), str(step))

	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	mc.skip_start_hangar()

	var ind := DockReadyIndicator3D.new()
	root.add_child(ind)
	ind.setup(mc, pack)
	check("the indicator built the glow quad", ind._quad != null)
	if ind._quad != null:
		var mat := ind._quad.material_override as ShaderMaterial
		check("...with the generic background-recolour shader", mat != null and mat.shader != null)
		if mat != null:
			check("...parameterised with this sprite's own step, not a constant in the script", is_equal_approx(float(mat.get_shader_parameter("recolour_step")), step))

	var dt := 1.0 / Vehicle.TICK_HZ
	var v := mc.vehicle
	v.position = mc.home_position()
	v.speed = 0.0
	v.moving = false
	ind._process(dt)
	check("visible once parked at the pad, in tolerance and not pressing anything", ind._quad.visible, str(mc.can_dock(v)))
	v.moving = true
	ind._process(dt)
	check("hidden again once moving", not ind._quad.visible)

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
