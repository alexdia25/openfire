# The Hall of Fame as the Return Fire pack declares it (ui/menus.json from tools/data/ui_menus.json; wiki document 133, issue #84): the main menu lists High Scores, it opens a
# "Return Fire Hall of Fame" screen with the Training and Tournament tabs, and the whole menu definition is sound. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/hall_of_fame_pack_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	HighScores.path = "user://hall_of_fame_pack_check.json"
	HighScores.clear()
	var pack := ModLoader.load_game_pack()
	var menus := MenuDef.from_pack(pack.ui_menus)
	_check(menus.problems().is_empty(), "the pack's menus are sound: %s" % [menus.problems()])
	var labels := []
	for item in menus.screens["main"]["items"]:
		labels.append(item["label"])
	_check(labels == ["Campaign", "Multiplayer", "High Scores", "Settings"], "the main menu lists High Scores between Multiplayer and Settings: %s" % [labels])
	_check(menus.screens["hall_of_fame"]["type"] == "high_scores" and menus.screens["hall_of_fame"]["title"] == "Return Fire Hall of Fame", "and opens the Return Fire Hall of Fame")
	HighScores.record_win(String(pack.manifest.get("id", "")), 1, "RFMAP001", "Brown", 95000)
	var flow: GameFlow = load("res://addons/openfire_engine/game/game_flow.tscn").instantiate()
	get_root().add_child(flow)
	await process_frame
	flow.show_screen("hall_of_fame")
	await process_frame
	var tree: Tree = flow._current.find_children("*", "Tree", true, false)[0]
	_check(tree.columns == 4 and tree.get_root().get_child_count() == 1 and tree.get_root().get_child(0).get_text(3) == " 1:35", "the Training tab shows a recorded win with its time")
	HighScores.clear()
	print("hall_of_fame_pack_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
