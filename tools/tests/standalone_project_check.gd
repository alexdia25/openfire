# Headless check for standalone projects (PORTING_PLAN.md 2.7's sharpened end goal, 2026-09-27; EDITOR_PLAN.md
# "New game..."): a pack with no base_pack at all -- a game built entirely in the editor, with no Return Fire content
# under it -- is a normal, editable project, while the bundled original content is still refused. Run:
#   godot --headless --path . --script tools/tests/standalone_project_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var game := ProjectSettings.globalize_path("user://standalone_project_check/game")
	if DirAccess.dir_exists_absolute(game):
		OS.move_to_trash(game)

	# what "New game..." does
	var made := ModWorkspace.create(game, "My game", "")
	_check(made != null, "a standalone project is created")
	made.close()

	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.path_join("pack.json")))
	_check(manifest.get("base_pack", "not empty") == "", "its manifest has no base_pack at all")

	_check(ModLoader.editor_open_problem(game) == "", "the editor can open it")
	_check(ModLoader.mod_problem(game) != "", "but it is not a layerable mod (no base_pack): %s" % ModLoader.mod_problem(game))

	var ws := ModWorkspace.new()
	_check(ws.open(game), "ModWorkspace opens it")
	_check(ws.pack != null and ws.pack.layers.size() == 1 and ws.pack.layers[0] == game, "one layer: itself, nothing under it")
	_check(ws.pack.vehicle_order.is_empty() and ws.pack.list_levels().is_empty(), "no vehicles or levels until the editor adds some")

	# every panel a fresh project opens into stays usable with nothing in it (no crash, no error)
	var vp := VehiclePreviewPanel.new()
	get_root().add_child(vp)
	await process_frame   # panels build their controls in _ready(), which a bare add_child() does not run synchronously
	vp.setup(ws)
	_check(vp.vehicle == null, "the vehicle preview shows nothing selected, not an error")
	vp.queue_free()

	var mv := MapViewPanel.new()
	get_root().add_child(mv)
	await process_frame
	mv.setup(ws)
	mv.queue_free()

	# adding the project's own first vehicle works the same as in a mod
	PackWriter.write_json(game.path_join("vehicles/mygame.buggy/vehicle.json"), {
		"id": "mygame.buggy", "name": "Buggy", "original_index": 0,
		"stats": {"hit_points": 10.0, "armor": 0.0, "fuel": 100.0, "sink_depth": 10.0, "dock_tolerance": 4.0, "death_wait_ticks": 60.0},
		"shape": {"layer": 2, "mask": 39, "z": [0.0, 8.0], "poly": [[-4.0, -6.0], [4.0, -6.0], [4.0, 6.0], [-4.0, 6.0]]},
		"drive": {"model": "ground", "max_forward_per_tick": 1.0, "max_reverse_per_tick": -0.5, "accel_per_tick2": 0.05,
				"friction_per_tick2": 0.02, "turn_steps_per_tick": 0.3},
		"aim": {"model": "none"}, "water": {"model": "none"}, "weapons": {"ammo": [0, 0], "cooldown_ticks": [20, 0], "slots": []},
		"render": {"parts": []}})
	ws.reload()
	_check(ws.pack.vehicle_order == ["mygame.buggy"], "a vehicle added to the project shows up, with no roster or original content assumed")

	ws.close()

	# original content itself is still refused, exactly as before
	_check(ModLoader.editor_open_problem(ModLoader.base_pack_dir()) != "", "the bundled original content still refuses to open")
	var refused := ModWorkspace.new()
	_check(not refused.open(ModLoader.base_pack_dir()), "and ModWorkspace agrees")

	print("standalone_project_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
