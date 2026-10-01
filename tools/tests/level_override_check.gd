# Headless check for a map's roster override (PORTING_PLAN.md 2.7.3, step 6): a mod's own levels/<id>/level.override.json
# patches the pack's default roster and a level's side colours for one map, without shipping a copy of level.json/art.bin,
# without touching the original pack, and without moving any definition's own vehicle_type index. Run:
#   godot --headless --path . --script tools/tests/level_override_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var pack := Pack.new()
	_check(pack.load_from("res://packs/original_pc"), "original pack loads")

	var mod := ProjectSettings.globalize_path("user://level_override_check/mod")
	if DirAccess.dir_exists_absolute(mod):
		OS.move_to_trash(mod)
	PackWriter.write_json(mod.path_join("pack.json"), {"id": "overridemod", "name": "level override test", "base_pack": "original_pc"})
	# a new vehicle, so the override can offer it on the map without touching the roster of any other map
	var scout: Dictionary = pack.vehicle_def(1).duplicate(true)   # rf.jeep, recombined as a new id
	scout["id"] = "overridemod.scout"
	scout["name"] = "Scout"
	PackWriter.write_json(mod.path_join("vehicles/overridemod.scout/vehicle.json"), scout)
	# the override itself: no level.json/art.bin here at all -- just the patch
	PackWriter.write_json(mod.path_join("levels/RFMAP001/level.override.json"), {
		"side_colours": ["red", "blue"],
		"roster": {"rf.heli": null, "rf.tank": {"stock_key": "", "default_stock": 9}, "overridemod.scout": {"default_stock": 2}},
		"flow": {"intro": "briefing"}})

	var m := Pack.new()
	_check(m.load_from(mod), "the mod loads")
	_check(m.level_dir("RFMAP001") != "" and not m.level_dir("RFMAP001").begins_with(mod),
			"level_dir still resolves to a real level.json (the original's): the override-only folder is not mistaken for it")
	_check(m.level_override_paths("RFMAP001").size() == 1, "exactly one layer's override.json is found")

	var level := LevelData.new()
	_check(level.load_from(m.level_dir("RFMAP001"), m.level_override_paths("RFMAP001")), "the level loads with the override applied")
	_check(level.side_colours == ["red", "blue"], "side_colours came from the override")
	_check(level.roster_override.get("rf.heli", "missing") == null and level.roster_override["rf.tank"]["default_stock"] == 9.0,
			"roster_override carries the raw per-id entries")
	_check(level.flow.get("intro", "") == "briefing", "flow (PORTING_PLAN.md 2.8) is carried the same way (an intro scene id, here)")

	var roster := m.roster_for(level)
	var ids: Array = roster.map(func(e): return e["id"])
	_check(ids == ["rf.tank", "rf.jeep", "rf.msv", "overridemod.scout"], "the effective roster: Heli removed, the scout added, order kept: %s" % [ids])
	var tank_entry: Dictionary = roster[ids.find("rf.tank")]
	_check(tank_entry["default_stock"] == 9.0 and tank_entry["stock_key"] == "", "the Tank's stock and stock_key are overridden (empty key opts out of the VHCL letter)")
	_check(m.vehicle_roster.size() == 4 and m.vehicle_roster.map(func(e): return e["id"]).has("rf.heli"), "the pack's own default roster is untouched")

	# a match on this level: the Heli's global index (3) has no stock; the scout (a new definition, its own index) does
	var world := Node.new()
	get_root().add_child(world)
	var mc := MatchController.new()
	world.add_child(mc)
	mc.setup(m, level, mod, world)
	mc.skip_start_hangar()   # this test checks post-spawn stock, not the start-of-match hangar itself (issue #63)
	var heli_t := m.vehicle_index("rf.heli")
	var tank_t := m.vehicle_index("rf.tank")
	var scout_t := m.vehicle_index("overridemod.scout")
	_check(mc.vehicle_stock.size() == m.vehicle_order.size(), "vehicle_stock spans every definition's index, not just the roster's")
	_check(mc.vehicle_stock[heli_t] == 0, "the Heli is unavailable on this map (removed from its roster)")
	_check(mc.vehicle_stock[tank_t] == 8, "the Tank's stock is the override's 9, minus the one spent spawning the player's")
	_check(mc.vehicle_stock[scout_t] == 2, "the new vehicle has its own stock, at its own (non-roster) index")
	_check(mc.vehicle.colour == "red", "the player's vehicle is drawn in the overridden side colour")

	# a second, unrelated level in the same mod is unaffected (no override.json for it)
	var level2 := LevelData.new()
	_check(level2.load_from(m.level_dir("RFMAP002"), m.level_override_paths("RFMAP002")), "a level without its own override loads")
	_check(level2.roster_override.is_empty() and level2.side_colours == ["tan", "green"], "and is not affected by RFMAP001's override")
	_check(m.roster_for(level2) == m.vehicle_roster, "so its effective roster is just the pack default")

	print("level_override_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
