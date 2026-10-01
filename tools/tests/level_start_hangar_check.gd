# A level starts in the vehicle-choice hangar (issue #63; documents 89/95) and the hangar is actually on screen: the
# view is faded out under it, so if the hangar screen isn't shown the player sees only black. (Regression: the match
# opened the hangar during its own setup, before the HUD's SelectorScreen existed to hear about it, so every level
# started on a black screen.) Then confirming a vehicle undocks it into a visible, playable level. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/level_start_hangar_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var view: Node = load("res://addons/openfire_engine/game/terrain_view_3d.tscn").instantiate()
	get_root().add_child(view)
	current_scene = view
	for i in 3:
		await process_frame
	var mc: MatchController = view.controller
	var screens := view.find_children("*", "SelectorScreen", true, false)
	_check(mc.selecting and mc.view_fade == 0.0, "the level opens in the hangar, the view faded out under it")
	_check(screens.size() == 1 and screens[0].visible, "and the hangar screen is shown, not left hidden over black")

	mc.skip_start_hangar()
	await process_frame
	_check(not mc.selecting and not mc.vehicle.frozen and mc.view_fade == 1.0, "confirming undocks the vehicle into a visible level")
	_check(not screens[0].visible, "the hangar screen is gone")

	print("level_start_hangar_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
