# The front-end screens play the hangar theme (issue alexdia25/openfire#21): GameFlow's title screen starts a MusicManager in menu mode, which plays the Bunker line
# (line 14) from the real pack's tracks, and entering a level hands the music over to the level's own manager. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/menu_music_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var flow := GameFlow.new()
	get_root().add_child(flow)
	for i in 5:
		await process_frame
	var m: MusicManager = flow._menu_music
	_check(m != null, "the title screen starts menu music")
	if m != null:
		_check(m.director.requested == MusicDirector.LINE_BUNKER and m.director.playing == MusicDirector.LINE_BUNKER, "it asks for the Bunker line")
		_check(m._player.playing, "and the player is playing it")
	flow._show_main_menu()
	_check(flow._menu_music == m, "the same music carries on through the menus")
	flow._enter_level(flow.pack.list_levels()[0])
	await process_frame
	_check(flow._menu_music == null, "entering a level drops the menu music")
	quit(_failures)
