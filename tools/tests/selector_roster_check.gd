# Headless check for the vehicle-select hangar with a roster other than the original 4 (PORTING_PLAN.md 2.7.3 step
# 6, issue #15): the hangar always shows exactly 4 bays (user direction, 2026-09-28); which vehicle_type sits in
# each bay comes from the level's effective roster (MatchController.selector_roster/_bay_type), not a hardcoded
# bay==vehicle_type assumption, and a roster of more than 4 pages through them with select_next_page(). The
# default roster (unaffected by any of this) is already covered by tools/tests/select_check.gd. Run:
#   godot --headless --path . --script tools/tests/selector_roster_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _mc(pack: Pack, level: LevelData) -> MatchController:
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	return mc


func _init() -> void:
	var pack := Pack.new()
	_check(pack.load_from("res://packs/original_pc"), "original pack loads")

	# a mod adds a 5th vehicle to RFMAP001's roster, so the effective roster genuinely exceeds 4
	var mod := ProjectSettings.globalize_path("user://selector_roster_check/mod")
	if DirAccess.dir_exists_absolute(mod):
		OS.move_to_trash(mod)
	PackWriter.write_json(mod.path_join("pack.json"), {"id": "selectormod", "name": "selector roster test", "base_pack": "original_pc"})
	var scout: Dictionary = pack.vehicle_def(1).duplicate(true)   # rf.jeep, recombined
	scout["id"] = "selectormod.scout"
	scout["name"] = "Scout"
	PackWriter.write_json(mod.path_join("vehicles/selectormod.scout/vehicle.json"), scout)
	PackWriter.write_json(mod.path_join("levels/RFMAP001/level.override.json"), {"roster": {"selectormod.scout": {"default_stock": 2}}})

	var m := Pack.new()
	_check(m.load_from(mod), "the mod loads")
	var level := LevelData.new()
	_check(level.load_from(m.level_dir("RFMAP001"), m.level_override_paths("RFMAP001")), "the level loads")
	var scout_type := m.vehicle_index("selectormod.scout")

	var mc := _mc(m, level)
	mc._open_selection()
	_check(mc.selector_roster == [0, 1, 2, 3, scout_type], "the effective roster, in order: %s" % [mc.selector_roster])
	_check(mc.selector_page_count() == 2, "5 entries need 2 pages of 4")
	_check(mc.selector_page == 0 and mc._bay_type(mc.selection) == 0, "opens on page 0, the Tank (first with stock)")
	_check(mc._bay_type(0) == 0 and mc._bay_type(1) == 1 and mc._bay_type(2) == 2 and mc._bay_type(3) == 3,
			"page 0's 4 bays are exactly the original roster, in the original order")

	mc.select_next_page()
	_check(mc.selector_page == 1, "select_next_page moves to page 1")
	_check(mc._bay_type(0) == scout_type, "bay 0 of page 1 is the mod's 5th vehicle")
	_check(mc._bay_type(1) < 0 and mc._bay_type(2) < 0 and mc._bay_type(3) < 0, "the other 3 bays on page 1 are empty (no 6th, 7th, 8th vehicle)")
	_check(mc.selection == 0, "the cursor landed on the scout, the only stocked bay on the new page")

	for i in 30:   # let the view's fade-in finish -- confirm_selection only counts once it has (document 78)
		await process_frame
	mc.confirm_selection()
	_check(not mc.selecting and mc.vehicle.vehicle_type == scout_type,
			"confirming on page 1's bay 0 actually creates the mod's 5th vehicle, not vehicle_type 0")
	mc.get_parent().queue_free()

	# a roster with only 3 of the original 4 (the Heli removed): still 4 bays, one now empty; the original's own
	# neighbour navigation is otherwise exactly as before (see the class doc comment)
	var mod2 := ProjectSettings.globalize_path("user://selector_roster_check/mod2")
	if DirAccess.dir_exists_absolute(mod2):
		OS.move_to_trash(mod2)
	PackWriter.write_json(mod2.path_join("pack.json"), {"id": "selectormod2", "name": "selector roster test 2", "base_pack": "original_pc"})
	PackWriter.write_json(mod2.path_join("levels/RFMAP001/level.override.json"), {"roster": {"rf.heli": null}})
	var m2 := Pack.new()
	_check(m2.load_from(mod2), "the second mod loads")
	var level2 := LevelData.new()
	level2.load_from(m2.level_dir("RFMAP001"), m2.level_override_paths("RFMAP001"))
	var mc2 := _mc(m2, level2)
	mc2._open_selection()
	_check(mc2.selector_roster == [0, 1, 2], "3-entry roster (Heli removed)")
	_check(mc2.selector_page_count() == 1, "still fits on one page")
	_check(mc2._bay_type(3) < 0, "bay 3 (the Heli's own, in the original layout) is empty")
	_check(mc2.vehicle_stock[3] == 0, "and its stock is 0, exactly like removing it from the roster in step 6 already means")

	print("selector_roster_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
