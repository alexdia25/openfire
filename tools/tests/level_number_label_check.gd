# Headless check for the level list labels ("NNN - Title", user direction 2026-09-28), in both places that list
# levels: the game's own LevelSelectScreen and the editor's MapViewPanel. Run:
#   godot --headless --path . --script tools/tests/level_number_label_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	_check(LevelSelectScreen._level_number("RFMAP001") == "001", "the number in RFMAP001 is 001")
	_check(LevelSelectScreen._level_number("RFMAP117") == "117", "and in RFMAP117, 117")
	_check(LevelSelectScreen._level_number("mymod.custom_level") == "mymod.custom_level",
			"an id with no trailing digits (a mod's own) falls back to the whole id")
	_check(LevelSelectScreen._peek_name("res://packs/original_pc/levels/RFMAP001") == "The Cakewalk",
			"the peeked name matches the real level")

	var pack := Pack.new()
	_check(pack.load_from("res://packs/original_pc"), "pack loads")
	var s := LevelSelectScreen.new()
	get_root().add_child(s)
	await process_frame
	s.setup(pack)
	var list: ItemList = null
	for c in s.get_children():
		if c is VBoxContainer:
			for cc in c.get_children():
				if cc is ItemList:
					list = cc
	_check(list != null and list.get_item_text(0) == "001 - The Cakewalk", "the level select list shows the format: %s" % [list.get_item_text(0) if list else "?"])

	print("level_number_label_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
