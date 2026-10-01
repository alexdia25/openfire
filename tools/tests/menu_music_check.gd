# The front-end screens play the Drums line (issue alexdia25/openfire#21): GameFlow's title screen starts a MusicManager in menu mode, which loops line 17 (tracks 28 and 29,
# cut from Drums.WAV) from the real pack unbroken through every menu, and entering a level hands the music over to the level's own manager (the hangar theme is the level's). Run:
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
		_check(m.director.requested == MusicDirector.LINE_DRUMS and m.director.playing == MusicDirector.LINE_DRUMS, "the title screen asks for the Drums line")
		_check(m._player.playing, "and the player is playing it")
	flow._show_main_menu()
	for i in 5:
		await process_frame
	_check(flow._menu_music == m and m.director.playing == MusicDirector.LINE_DRUMS and m._player.playing, "the main menu keeps the same Drums loop going")
	flow._show_level_select()
	_check(flow._menu_music == m, "and so does level select")
	flow._enter_level(flow.pack.list_levels()[0])
	await process_frame
	_check(flow._menu_music == null, "entering a level drops the menu music")
	quit(_failures)
