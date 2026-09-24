# Headless check for how the game loads mods (PORTING_PLAN.md 2.7.9, ModLoader): original content with no mods; enabled
# mods layered on top in order, later winning; a mod's own new maps and vehicles present only while it is enabled; bad
# mods (missing, broken, a base pack posing as a mod) skipped so the game still runs the original; the original files
# themselves never changed; and the mod tool refusing to open original content as a mod. Explicit mod lists are passed,
# so the user's real settings are never touched. Run:
#   godot --headless --path . --script tools/tests/mod_loading_check.gd
extends SceneTree

var _failures := 0
const HULL := "vehicle.tank.hull.04"


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _make_mod(dir: String, colour: Color, extras := false) -> void:
	if DirAccess.dir_exists_absolute(dir):
		OS.move_to_trash(dir)
	var ws := ModWorkspace.create(dir, dir.get_file())
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(colour)
	ws.import_frame(HULL, img)
	ws.save()
	ws.close()
	if extras:   # a custom map and a new vehicle type: content the original doesn't have at all
		DirAccess.make_dir_recursive_absolute(dir.path_join("levels/MODMAP01"))
		DirAccess.copy_absolute("res://packs/original_pc/levels/RFMAP001/level.json", dir.path_join("levels/MODMAP01/level.json"))
		DirAccess.copy_absolute("res://packs/original_pc/levels/RFMAP001/art.bin", dir.path_join("levels/MODMAP01/art.bin"))
		PackWriter.write_json(dir.path_join("vehicles/vehicle_types.json"), {"types": {"hovertank": {"name": "Hovertank"}}})


func _hull(p: Pack) -> Color:
	return p.get_sprite_image(HULL).get_pixel(10, 10)


func _init() -> void:
	var original_file := "res://packs/original_pc/sprites/vehicle/tank/hull.04.png"
	var original_md5 := FileAccess.get_md5(original_file)
	var root := ProjectSettings.globalize_path("user://mod_loading_check")
	var a := root.path_join("mod_a")
	var b := root.path_join("mod_b")
	_make_mod(a, Color.CYAN, true)
	_make_mod(b, Color.ORANGE)
	var broken := root.path_join("broken")
	DirAccess.make_dir_recursive_absolute(broken)
	FileAccess.open(broken.path_join("pack.json"), FileAccess.WRITE).store_string("{ not json")

	var base := ModLoader.load_game_pack(ModLoader.BASE_PACK, [])
	var base_hull := _hull(base)
	_check(base.layers.size() == 1, "no mods enabled: the original content alone")
	_check(not "MODMAP01" in base.list_levels() and not base.vehicle_types.has("hovertank"), "no mod content without the mod")

	var with_a := ModLoader.load_game_pack(ModLoader.BASE_PACK, [a])
	_check(with_a.layers.size() == 2 and _hull(with_a) == Color.CYAN, "an enabled mod loads on top")
	_check("MODMAP01" in with_a.list_levels() and "RFMAP001" in with_a.list_levels(), "a mod's custom map is added beside the originals")
	_check(with_a.vehicle_types.has("hovertank") and with_a.vehicle_types.has("0"), "a mod's new vehicle is added beside the originals")
	_check(with_a.level_dir("RFMAP001") == "res://packs/original_pc/levels/RFMAP001", "untouched maps still come from the original")

	var ab := ModLoader.load_game_pack(ModLoader.BASE_PACK, [a, b])
	_check(ab.layers.size() == 3 and _hull(ab) == Color.ORANGE and "MODMAP01" in ab.list_levels(), "two mods: the later one wins where both change something")
	var ba := ModLoader.load_game_pack(ModLoader.BASE_PACK, [b, a])
	_check(_hull(ba) == Color.CYAN, "load order decides")

	var skipped := ModLoader.load_game_pack(ModLoader.BASE_PACK, [root.path_join("missing"), broken, ModLoader.BASE_PACK, a])
	_check(skipped.layers.size() == 2 and _hull(skipped) == Color.CYAN, "missing, broken and base-pack entries are skipped, good mods still load")
	var only_bad := ModLoader.load_game_pack(ModLoader.BASE_PACK, [broken])
	_check(only_bad.layers.size() == 1 and _hull(only_bad) == base_hull, "only bad mods: the original content")

	var off := ModLoader.load_game_pack(ModLoader.BASE_PACK, [])
	_check(_hull(off) == base_hull and not "MODMAP01" in off.list_levels(), "disabling the mods gives the original content back")
	_check(FileAccess.get_md5(original_file) == original_md5, "the original files were never changed")

	_check(ModLoader.mod_problem(ModLoader.BASE_PACK) != "", "the original pack is not a mod")
	var ws := ModWorkspace.new()
	_check(not ws.open(ModLoader.BASE_PACK), "the mod tool refuses to open original content as a mod")
	ws.close()

	print("mod_loading_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
