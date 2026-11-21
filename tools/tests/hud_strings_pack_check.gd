# Return Fire keeps its HUD wording through its own ui/strings.json (S7.1, issue #134, wiki document 181): the engine's PlaceholderHud
# words are neutral, and the importer writes the port's wording (tools/data/ui_strings.json) into the pack. The objectives must read as
# they did before S7.1, the flag carrier named from the Jeep's definition (flags.carries_flag), the keys from input/controls.json. Run:
#   godot --headless --path . --script tools/tests/hud_strings_pack_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	GameSettings.control_sets = {}
	var pack := Pack.new()
	_check(pack.load_from("res://packs/original_pc"), "pack loads")
	_check(not pack.ui_strings.is_empty(), "the pack has ui/strings.json")
	_check(not pack.ui_strings.has("_source"), "the importer drops the data file's _source")
	_check(pack.lobbed_missile_data.get("frames", []).size() == 12, "projectiles/lobbed_missile.json (jeep_missile.json before S7.1)")
	_check(PlaceholderHud.carrier_names(pack) == "Jeep", "the flag carrier comes from the definitions: %s" % PlaceholderHud.carrier_names(pack))

	var level := LevelData.new()
	level.load_from(pack.level_dir("RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	mc.players = 1
	mc.computer_fills_sides = false
	root.add_child(mc)
	mc.setup(pack, level, pack.pack_dir, root)
	mc.skip_start_hangar()
	var v: Vehicle = mc.slots[0].vehicle
	var t := PlaceholderHud.objective_text(mc, v)
	_check(t.begins_with("Objective: destroy the enemy building (a Tank's shells; shoot the ruin too), then take the flag"), "targets: the old wording (%s)" % t)
	mc._spawn_flag("b", v.pos_fx)
	v.set_vehicle_type(pack.vehicle_index("rf.tank"))
	t = PlaceholderHud.objective_text(mc, v)
	_check(t == "Objective: the flag is out. Only a Jeep can carry it: return to your base tile and press V to switch", "not the carrier: the old wording (%s)" % t)
	v.set_vehicle_type(pack.vehicle_index("rf.jeep"))
	t = PlaceholderHud.objective_text(mc, v)
	_check(t == "Objective: drive the Jeep onto the flag", "the carrier: the old wording (%s)" % t)
	mc.flags[1].carrier = v
	t = PlaceholderHud.objective_text(mc, v)
	_check(t == "Objective: bring the flag back to your base tile", "carrying it: the old wording (%s)" % t)
	mc.flags[1].carrier = null

	var keys := PlaceholderHud.keys_text(pack, 1, true)
	_check(keys == "arrows drive   A Enter/Space: fire   B Z: raised / swim (Jeep)   C X: mines (MSV) / flag (Jeep) / weapon (Heli) / turret centre   Q E: turret, bank   dock: stand still on your pad + a button (V quick swap, port-only); in the grid: arrows, A choose, B/C map",
			"one player: the old wording, keys from input/controls.json (%s)" % keys)
	keys = PlaceholderHud.keys_text(pack, 2, true)
	_check(keys == "player 1: W S A D drive, H J K buttons, Q E turret / bank      player 2: keypad 8 5 4 6 drive, keypad - keypad + Enter buttons, keypad 7 9 turret / bank",
			"two players (%s)" % keys)
	t = PlaceholderHud.text(pack, "win_banner", {"side": level.side_colour(0).to_upper()})
	_check(t == "TAN WINS  -  flag captured", "the win banner (%s)" % t)
	mc.queue_free()
	print("hud_strings_pack_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
