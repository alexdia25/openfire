# The radar grid overlay is per vehicle type, not one shared cel (document 108's addendum): Tank 1963 (32x32), MSV 1973 (39x34,
# matching its own larger window), Heli's own 1975 (a plain sprite, not a document-9 tint mask, so no additive-blend material).
# Drawn on top of everything else including the ping. The Jeep has no radar at all (kind 8, the compass, instead). Run:
#   godot --headless --path . --script tools/tests/radar_grid_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)

	var panels: Dictionary = pack.hud_panels["panels"]
	check("the Tank's own grid is the tint-mask family, sized to its 32x32 window",
		panels["0"]["slot9"]["grid_sprite_id"] == "effect.tint.colour.006" and not panels["0"]["slot9"]["grid_is_negative"])
	check("the MSV's own grid is a DIFFERENT cel, sized to ITS 39x34 window (not the Tank's 32x32 one)",
		panels["2"]["slot9"]["grid_sprite_id"] != panels["0"]["slot9"]["grid_sprite_id"]
		and pack.get_sprite(panels["2"]["slot9"]["grid_sprite_id"])["w"] == 39
		and pack.get_sprite(panels["2"]["slot9"]["grid_sprite_id"])["h"] == 34)
	check("the Heli's own grid came from a negative record field and is a plain sprite, not a tint mask",
		panels["3"]["slot9"]["grid_is_negative"]
		and String(pack.get_sprite(panels["3"]["slot9"]["grid_sprite_id"])["kind"]) == "sprite")
	check("the Jeep has no grid at all (kind 8, the compass, not kind 6)", not panels["1"]["slot9"].has("grid_sprite_id"))

	var radar := RadarView.new()
	root.add_child(radar)
	radar.setup(mc)
	check("RadarView built the (initially hidden) grid overlay", radar._grid != null and not radar._grid.visible)

	radar.set_grid(panels["0"]["slot9"]["grid_sprite_id"], false)
	check("Tank: grid visible with an additive material (a real tint-mask approximation)", radar._grid.visible and radar._grid.material != null)
	var tank_tex := radar._grid.texture

	radar.set_grid(panels["2"]["slot9"]["grid_sprite_id"], false)
	check("MSV: a different texture than the Tank's", radar._grid.texture != tank_tex)

	radar.set_grid(panels["3"]["slot9"]["grid_sprite_id"], true)
	check("Heli: no additive material -- drawn as an ordinary sprite", radar._grid.visible and radar._grid.material == null)

	radar.set_grid(null, false)
	check("no grid at all (the Jeep): hidden", not radar._grid.visible)

	radar.set_grid(panels["0"]["slot9"]["grid_sprite_id"], false)
	check("the grid is added after the ping, so it draws on top", radar._grid.get_index() > radar._ping.get_index())

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
