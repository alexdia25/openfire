# Which colour table a weapon bar draws with (document 103): amber (the fuel table) for every weapon bar, except the Heli's bar for the weapon that is not
# selected, which is the dark olive ammunition table. The colours are the ones sampled in the reference footage. Run:
#   godot --headless --path . --script tools/tests/hud_bar_colour_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _bar_colours(panel: HudPanel) -> Array:
	var out := []
	for b in panel._bars:
		if int(b["kind"]) == 4:
			out.append(b["fill"].color)
	return out


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var probe_tank := Vehicle.new()
	probe_tank.setup(pack)
	probe_tank.set_vehicle_type(0)
	var probe_msv := Vehicle.new()
	probe_msv.setup(pack)
	probe_msv.set_vehicle_type(2)
	var probe_heli := Vehicle.new()
	probe_heli.setup(pack)
	probe_heli.set_vehicle_type(3)
	check("the Tank's weapon bar is amber", not HudPanel.uses_ammo_colours(probe_tank, 0, 0))
	check("the MSV's two bars are both amber", not HudPanel.uses_ammo_colours(probe_msv, 0, 0) and not HudPanel.uses_ammo_colours(probe_msv, 1, 0))
	check("the Heli's selected bar is amber, the other olive", not HudPanel.uses_ammo_colours(probe_heli, 0, 0) and HudPanel.uses_ammo_colours(probe_heli, 1, 0))
	check("switching the Heli's weapon swaps them", HudPanel.uses_ammo_colours(probe_heli, 0, 1) and not HudPanel.uses_ammo_colours(probe_heli, 1, 1))
	probe_tank.free()
	probe_msv.free()
	probe_heli.free()
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var panel := HudPanel.new()
	root.add_child(panel)
	panel.setup(mc)
	var amber := Color8(253, 188, 0)   # sampled from the recording's Tank and Heli bars (both within one step of the pack's colour)
	var olive := Color8(112, 108, 0)   # the recording's Heli right-hand bar
	mc.vehicle.set_vehicle_type(0)
	panel._process(0.1)
	var tank := _bar_colours(panel)
	check("Tank: one weapon bar, amber", tank.size() == 1 and _near(tank[0], amber), str(tank))
	mc.vehicle.set_vehicle_type(3)
	panel._process(0.1)
	var heli := _bar_colours(panel)
	check("Heli: bottom bar amber, right bar olive", heli.size() == 2 and _near(heli[0], amber) and _near(heli[1], olive), str(heli))
	mc.vehicle.toggle_heli_slot()
	panel._process(0.1)
	heli = _bar_colours(panel)
	check("Heli after the switch: bottom olive, right amber", heli.size() == 2 and _near(heli[0], olive) and _near(heli[1], amber), str(heli))
	var critical := Color8(237, 0, 0)   # fuel_rgb["0"], the amber TABLE's own lowest tier -- still amber, just empty
	mc.vehicle.set_vehicle_type(2)
	panel._process(0.1)
	var msv := _bar_colours(panel)
	# document 75: with the mine layer off (single player, the default -- issue #31) the MSV's own mine bar (slot 1)
	# reads empty, not full -- still the amber TABLE (uses_ammo_colours is false either way), just its lowest tier,
	# not olive. Confirms the fix didn't accidentally switch colour tables, only the fill fraction.
	check("MSV, mine layer off: weapon bar full amber, mine bar empty (still amber's own critical tier, not olive)",
		msv.size() == 2 and _near(msv[0], amber) and _near(msv[1], critical), str(msv))
	mc.vehicle.mine_layer_enabled = true
	panel._process(100.0)   # let the bar's own eased fill (move_toward, FUN_0042cdd0) catch up to the new target
	msv = _bar_colours(panel)
	check("MSV, mine layer on (two players / RF_DEBUG_MINES): both bars read full amber", msv.size() == 2 and _near(msv[0], amber) and _near(msv[1], amber), str(msv))
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02
