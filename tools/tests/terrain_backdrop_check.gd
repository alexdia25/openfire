# The finite ground mesh's own honest gap (terrain_view_3d.gd's _build_terrain_ground comment): near a large
# map's edge the tilted camera's rays can overshoot it, showing Godot's own default background instead of
# terrain -- reported as a level looking like it "starts off the map" (RFMAP057, spawn 8 tiles from a 128-tile
# map's edge). Confirms a WorldEnvironment now fills that gap with a sand-toned backdrop instead of the
# default void, without adding ambient light that would change the ground plane's own directional-light
# shading (everything else in the scene is unshaded and ignores lighting entirely, but the ground itself is
# not). Run:
#   godot --headless --path . --script tools/tests/terrain_backdrop_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var view: Node = load("res://game/terrain_view_3d.tscn").instantiate()
	get_root().add_child(view)
	current_scene = view
	for i in 3:
		await process_frame

	var we: WorldEnvironment = null
	for c in view.get_children():
		if c is WorldEnvironment:
			we = c
	check("a WorldEnvironment was built", we != null)
	var env := we.environment
	check("its background is a flat colour, not Godot's own default clear colour", env.background_mode == Environment.BG_COLOR)
	check("the colour is a plausible sand tone, not black (the radar's own off-map fill is black, by contrast; this is the main view)",
		env.background_color.r > 0.5 and env.background_color.g > 0.4 and env.background_color.b > 0.2, str(env.background_color))
	check("no ambient light was introduced -- the ground plane's own shading must not change", env.ambient_light_source == Environment.AMBIENT_SOURCE_DISABLED)

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
