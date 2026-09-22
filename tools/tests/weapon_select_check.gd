# Headless sanity check for the Heli's kind-9 weapon-select icons (document 83): confirms
# HudPanel builds two icons for the Heli only, at the traced positions, and that they swap
# texture when Vehicle.heli_weapon_slot() changes. Run:
#   godot --headless --path . --script tools/tests/weapon_select_check.gd
extends SceneTree

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
	mc.vehicle.set_vehicle_type(3)   # Heli

	var panel := HudPanel.new()
	root.add_child(panel)
	panel.setup(mc)
	panel._process(0.0)

	print("bomb icon: ", panel._weapon_select_bomb != null, " pos ", panel._weapon_select_bomb.position, " tex ", panel._weapon_select_bomb.texture.resource_path if panel._weapon_select_bomb.texture else null)
	print("gun icon: ", panel._weapon_select_gun != null, " pos ", panel._weapon_select_gun.position)
	print("slot 0 (gun) -> bomb tex region ", panel._weapon_select_bomb.texture.region, " gun tex region ", panel._weapon_select_gun.texture.region)

	mc.vehicle.toggle_heli_slot()
	panel._process(0.0)
	print("after toggle: bomb tex region ", panel._weapon_select_bomb.texture.region, " gun tex region ", panel._weapon_select_gun.texture.region)

	# also confirm a non-Heli panel has none
	mc.vehicle.set_vehicle_type(0)
	panel._process(0.0)
	print("Tank panel has weapon-select icons: ", panel._weapon_select_bomb != null)
	print("done")
	quit()
