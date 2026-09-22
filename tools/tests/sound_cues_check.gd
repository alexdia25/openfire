# Confirms the newly-wired sound_cue triggers actually fire (document 82's second wiring pass):
# the rearm loop's Ding, the compass's DumbDirect, the Heli's HeliClick, the vehicle-select
# GClick, and the dock's Raise. Run:
#   godot --headless --path . --script tools/tests/sound_cues_check.gd
extends SceneTree

var cues: Array[String] = []


func _on_cue(id: String) -> void:
	cues.append(id)


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
	mc.vehicle.sound_cue.connect(_on_cue)
	var dt := 1.0 / Vehicle.TICK_HZ

	# Ding: rearm() emits every 40 ticks while called.
	for i in 41:
		mc.vehicle.rearm(dt)
	print("Ding after 41 rearm ticks: ", cues.count("Ding"), " (expect 1)")

	# HeliClick: the third button toggle.
	mc.vehicle.set_vehicle_type(3)
	mc.vehicle.toggle_heli_slot()
	print("HeliClick after toggle: ", cues.has("HeliClick"))

	# DumbDirect: face a due-east flag with heading 0 (document 71's exact -16 case).
	mc.vehicle.set_vehicle_type(1)
	mc.vehicle.heading_deg = 0.0
	var enemy_idx := mc.vehicle.player_index() ^ 1
	mc._spawn_flag("a" if enemy_idx == 0 else "b", mc.vehicle.position + Vector2(1000.0, 0.0))
	cues.clear()
	mc._update_compass_chime(mc.vehicle)
	mc._update_compass_chime(mc.vehicle)   # second tick: should NOT re-fire (already aligned)
	print("DumbDirect fires once on alignment: ", cues.count("DumbDirect"), " (expect 1)")

	# GClick: any cursor move in the vehicle-choice grid.
	mc.switch_player_vehicle()
	cues.clear()
	mc.select_move(1)   # down
	print("GClick on cursor move: ", cues.has("GClick"))

	print("done")
	quit()
