# Headless check for the last sprite ids that used to be spelled in code (PORTING_PLAN.md 2.7.5's leftover list,
# issue #55): the death skull's mouth frames, the mine's ember light, and the Jeep missile's spin frames are now
# pack data (Pack.death_skull_data / mine_data / jeep_missile_data), built by tools/build_pack.py from the registry
# the same way vehicle parts and the flag already are, so a mod can re-skin any of them. Run:
#   godot --headless --path . --script tools/tests/leftover_sprite_tables_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var pack := Pack.new()
	_check(pack.load_from("res://packs/original_pc"), "pack loads")

	var skull: Array = pack.death_skull_data.get("frames", [])
	_check(skull.size() == 7, "7 death-skull mouth frames")
	_check(skull[0] == ["ui.death_skull.tan.f1", "ui.death_skull.green.f1"], "frame 1 is the traced pair: %s" % [skull[0]])
	_check(pack.get_sprite("ui.death_skull.tan.f1").size() > 0, "and it resolves to a real sprite")

	var embers: Array = pack.mine_data.get("sprites", [])
	_check(embers == ["effect.ember_small.01", "effect.ember_small.02", "effect.ember_small.03"], "3 mine ember variants: %s" % [embers])
	_check(pack.get_sprite("effect.ember_small.02").size() > 0, "and they resolve to real sprites")

	var missile: Array = pack.jeep_missile_data.get("frames", [])
	_check(missile.size() == 12, "12 Jeep missile spin frames")
	_check(missile[0] == ["projectile.jeep_missile.tan.01", "projectile.jeep_missile.green.01"], "frame 1 is the traced pair: %s" % [missile[0]])
	_check(missile[11] == ["projectile.jeep_missile.tan.12", "projectile.jeep_missile.green.12"], "frame 12 too: %s" % [missile[11]])

	# a mod can re-skin any of these the same way it re-skins a vehicle part: replace the whole table (2.7.4's
	# per-top-level-key overlay), no arithmetic on cel numbers anywhere in the game code that reads it
	var mod := ProjectSettings.globalize_path("user://leftover_sprite_tables_check/mod")
	if DirAccess.dir_exists_absolute(mod):
		OS.move_to_trash(mod)
	PackWriter.write_json(mod.path_join("pack.json"), {"id": "spritetablemod", "name": "sprite table test", "base_pack": "original_pc"})
	PackWriter.write_json(mod.path_join("effects/mine.json"), {"sprites": ["effect.ember_small.03", "effect.ember_small.02", "effect.ember_small.01"]})
	var m := Pack.new()
	_check(m.load_from(mod), "the mod loads")
	_check(m.mine_data.get("sprites", []) == ["effect.ember_small.03", "effect.ember_small.02", "effect.ember_small.01"],
			"the mod's mine.json replaces the whole table")
	_check(pack.mine_data.get("sprites", []) == embers, "the original pack is unaffected")

	print("leftover_sprite_tables_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
