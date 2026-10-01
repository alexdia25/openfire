# openfire's first run (issue #61, stage 4): with no base pack yet, the boot scene shows the import screen before
# anything else; a wrong folder (or the 3DO disc) is refused at once with a clear message and nothing is written;
# with a pack in place, boot goes straight to GameFlow, whose Settings screen carries "Game files..." back to the
# import screen. With RF_GAME_DIR set it also runs a real import through the screen, on its background thread, and
# checks the game starts on the result. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/first_run_check.gd
extends SceneTree

const TARGET := "user://first_run_check/packs/original_pc"

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _boot() -> OpenFireBoot:
	var boot: OpenFireBoot = load(OpenFireBoot.BOOT).instantiate()
	get_root().add_child(boot)
	current_scene = boot
	await process_frame
	await process_frame
	return boot


func _init() -> void:
	RFImporter.remove_tree(ProjectSettings.globalize_path("user://first_run_check"))
	var saved_prefs := FileAccess.get_file_as_string(FirstRunScreen.PREFS)   # the screen remembers the folders it was given
	var original_base := EngineConfig.base_pack()
	ProjectSettings.set_setting(EngineConfig.BASE_PACK, TARGET)

	var boot := await _boot()
	_check(boot.screen != null and current_scene == boot, "no pack yet: the import screen comes first")
	var screen := boot.screen
	screen.start_import(ProjectSettings.globalize_path("user://first_run_check/nowhere"))
	_check(not screen.is_importing() and screen.error_text().contains("not a folder"), "a missing folder is refused: %s" % screen.error_text())
	var empty := ProjectSettings.globalize_path("user://first_run_check/empty")
	DirAccess.make_dir_recursive_absolute(empty)
	screen.start_import(empty)
	_check(not screen.is_importing() and screen.error_text().contains("RFIRE.BIN is missing"), "a folder without the game is refused: %s" % screen.error_text())
	var three_do := ProjectSettings.globalize_path("user://first_run_check/3do")
	DirAccess.make_dir_recursive_absolute(three_do)
	FileAccess.open(three_do.path_join("Return Fire (Europe).cue"), FileAccess.WRITE).store_string("FILE x BINARY")
	screen.start_import(three_do)
	_check(screen.error_text().contains("3DO version"), "the 3DO disc is recognised and refused clearly")
	_check(not DirAccess.dir_exists_absolute(TARGET), "nothing was written for any of them")

	var install := OS.get_environment("RF_GAME_DIR")
	if install != "":
		screen.start_import(install)
		_check(screen.is_importing(), "a real install starts importing on a background thread")
		var t0 := Time.get_ticks_msec()
		while current_scene == boot and Time.get_ticks_msec() - t0 < 600000:
			if screen._continue.visible:   # finished with notes (e.g. no music found): the player reads them, then continues
				print("  notes: ", screen.error_text())
				screen._continue.pressed.emit()
			await process_frame
		# success changes scene, which frees the screen: only ask it why while it still exists
		_check(current_scene is GameFlow or not is_instance_valid(screen), "the import finished: %s" % (screen.error_text() if is_instance_valid(screen) else "ok"))
		_check(ModLoader.has_pack(TARGET), "the pack is in place at the target")
		_check(current_scene is GameFlow, "and the game started on it")
	else:
		print("(skipping the real import: set RF_GAME_DIR to run it)")
		ProjectSettings.set_setting(EngineConfig.BASE_PACK, original_base)
		boot.queue_free()
		boot = await _boot()
		await process_frame
		_check(current_scene is GameFlow, "with a pack in place, boot goes straight to the game")

	_check(GameFlow.settings_entries.any(func(e): return e[0] == "Game files..."), "Settings has \"Game files...\"")
	OpenFireBoot.reimport()
	await process_frame
	await process_frame
	await process_frame
	_check(current_scene is OpenFireBoot and (current_scene as OpenFireBoot).screen != null, "which brings the import screen back even though a pack exists")

	ProjectSettings.set_setting(EngineConfig.BASE_PACK, original_base)
	if saved_prefs == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FirstRunScreen.PREFS))
	else:
		FileAccess.open(FirstRunScreen.PREFS, FileAccess.WRITE).store_string(saved_prefs)
	print("first_run_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
