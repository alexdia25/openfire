# openfire's "Layout: ..." entry on GameFlow's Settings screen (importer/boot.gd): present after boot's _ready, its label names the current layout, and the action flips it.
# Run: godot --headless --path . --script res://tools/tests/settings_layout_entry_check.gd
extends SceneTree


func _init() -> void:
	var fails := 0
	var before := GameSettings.hud_layout
	var boot := OpenFireBoot.new()
	get_root().add_child(boot)
	await process_frame   # _ready runs on the first frame
	var found := false
	for e in GameFlow.settings_entries:
		if e[0] is Callable and String(e[0].call()).begins_with("Layout: "):
			found = true
	print(("ok   " if found else "FAIL ") + "the layout entry is on the Settings screen")
	fails += 0 if found else 1
	GameSettings.hud_layout = HudLayout.MODERN
	var l1 := OpenFireBoot.layout_label()
	OpenFireBoot.toggle_layout()
	var l2 := OpenFireBoot.layout_label()
	OpenFireBoot.toggle_layout()
	var ok := l1 == "Layout: Modern" and l2 == "Layout: Classic" and GameSettings.hud_layout == HudLayout.MODERN
	print(("ok   " if ok else "FAIL ") + "label follows the toggle: %s -> %s" % [l1, l2])
	fails += 0 if ok else 1
	GameSettings.hud_layout = before
	GameSettings.save_settings()
	quit(1 if fails > 0 else 0)
