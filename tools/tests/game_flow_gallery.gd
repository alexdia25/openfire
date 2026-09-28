# Dev tool, not a test: drives GameFlow through every screen and saves one screenshot each, for a visual check.
#   godot --audio-driver Dummy --path . --script tools/tests/game_flow_gallery.gd -- <out_dir>
# (a real window: this needs the rendering driver, not --headless)
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://gallery"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var flow: GameFlow = load("res://game/game_flow.tscn").instantiate()
	get_root().add_child(flow)
	await process_frame
	await process_frame
	await _shot(out_dir, "1_title")
	flow._show_main_menu()
	await _shot(out_dir, "2_main_menu")
	flow._show_settings()
	await _shot(out_dir, "3_settings")
	flow._show_multiplayer()
	await _shot(out_dir, "4_multiplayer")
	flow._show_level_select()
	await _shot(out_dir, "5_level_select")
	flow._play_story("gallery_test_scene", func(): pass)
	await _shot(out_dir, "6_story_scene")
	flow._show_mission_failed()
	await _shot(out_dir, "7_mission_failed")
	flow.start_level("RFMAP001")
	for i in 30:
		await process_frame
	await _shot(out_dir, "8_level")
	print("game_flow_gallery: done -> %s" % out_dir)
	quit()


func _shot(out_dir: String, name: String) -> void:
	for i in 3:
		await process_frame
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
