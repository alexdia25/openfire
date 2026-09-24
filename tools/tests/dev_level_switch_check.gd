# The dev level switcher: `]` / `[` load the next / previous level by reloading the scene.
#   godot --headless --path . --script tools/tests/dev_level_switch_check.gd
extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://game/terrain_view_3d.tscn")
	var view := scene.instantiate()
	get_root().add_child(view)
	current_scene = view
	await process_frame
	print("start: ", view.level_id)
	for key in [KEY_BRACKETRIGHT, KEY_BRACKETRIGHT, KEY_BRACKETLEFT, KEY_PAGEUP]:
		var ev := InputEventKey.new()
		ev.keycode = key
		ev.pressed = true
		view._unhandled_input(ev)
		await process_frame
		await process_frame
		view = current_scene
		print("after ", OS.get_keycode_string(key), ": ", view.level_id)
	quit()
