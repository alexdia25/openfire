# The hangar screen must be drawn above the view-fade layer: docking fades the view to black (view_fade 0) and the hangar then opens on top of it.
# (Regression: with the fade above the hangar, docking showed a fully black screen.)
#   godot --headless --path . --script tools/tests/hud_layer_order_check.gd
extends SceneTree

func _init() -> void:
	var view: Node = load("res://game/terrain_view_3d.tscn").instantiate()
	get_root().add_child(view)
	current_scene = view
	for i in 3:
		await process_frame
	var hud: Node = null
	for c in view.get_children():
		if c is PlaceholderHud:
			hud = c
	assert(hud != null)
	var fade_i := -1
	var select_i := -1
	var skull_i := -1
	for i in hud.get_child_count():
		var c := hud.get_child(i)
		if c is SelectorScreen:
			select_i = i
		elif c is DeathSkullView:
			skull_i = i
		elif c is ColorRect:
			fade_i = i
	print("hud children: fade ", fade_i, ", hangar screen ", select_i, ", skull ", skull_i, " (expect fade < hangar < skull)")
	assert(fade_i >= 0 and select_i > fade_i and skull_i > select_i)
	quit()
