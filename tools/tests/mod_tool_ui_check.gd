# Headless smoke test of the mod tool's UI (EDITOR_PLAN.md, E0): the editor scene opens a fresh mod, the Assets panel
# selects and replaces a sprite, the Team colours panel adds a colour, undo / save / validation update the top bar and the
# Validate tab. The logic under it is covered by mod_workspace_check.gd; this checks the panels are wired to it.
# Run:
#   godot --headless --path . --script tools/tests/mod_tool_ui_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _init() -> void:
	var dir := ProjectSettings.globalize_path("user://mod_tool_ui_check/uimod")
	if DirAccess.dir_exists_absolute(dir):
		OS.move_to_trash(dir)
	ModWorkspace.create(dir, "UI test").close()
	OS.set_environment("RF_EDITOR_MOD", dir)
	var main: Control = load("res://editor/editor_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var ws: ModWorkspace = main.ws
	_check(ws != null and ws.mod_dir == dir, "editor opened the mod")
	_check(main._save_btn.disabled and main._undo_btn.disabled, "clean mod: save and undo disabled")

	var assets: AssetsPanel = main._assets
	assets.select("vehicle.tank.hull.04")
	await process_frame
	_check(assets._canvas.sprite_id == "vehicle.tank.hull.04", "canvas shows the selected sprite")
	_check(assets._canvas.mask_texture != null, "an original pair shows its team paint")
	var strip_found := false
	for c in assets._inspector.get_children():
		if c is GridContainer and c.get_child_count() >= 8:
			strip_found = true
	_check(strip_found, "inspector shows a colour strip")

	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.CYAN)
	ws.import_frame("vehicle.tank.hull.04", img, "Replace frame")
	await process_frame
	_check(not main._save_btn.disabled and not main._undo_btn.disabled, "an edit enables save and undo")
	_check(main._path_label.text.contains("unsaved"), "top bar says unsaved")
	var tree_has_mod_colour := false
	assets._mod_only.button_pressed = true
	assets._rebuild_tree()
	var groups := assets._tree.get_root().get_children()
	_check(groups.size() == 1 and groups[0].get_child_count() == 1, "'In this mod' filter lists just the replaced sprite")

	var colours: ColoursPanel = main._colours
	colours._name.text = "teal"
	colours._picker.color = Color.from_hsv(0.5, 0.7, 0.5)
	colours._apply()
	await process_frame
	var listed := false
	for i in colours._list.item_count:
		listed = listed or String(colours._list.get_item_metadata(i)) == "teal"
	_check(listed and ws.mod_colours.has("teal"), "a colour added in the panel is in the mod and listed")
	_check(colours._preview.get_child_count() >= 6, "the preview shows sample team art in it")

	var findings: ItemList = main._findings
	var warned := false
	for i in findings.item_count:
		warned = warned or findings.get_item_text(i).contains("unsaved")
	_check(warned, "Validate lists the unsaved changes")
	ws.undo.undo()
	await process_frame
	_check(not ws.mod_colours.has("teal"), "undo from the top bar's stack removes the colour")
	ws.save()
	await process_frame
	_check(main._save_btn.disabled, "save disables save")

	main.queue_free()
	await process_frame
	print("mod_tool_ui_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
