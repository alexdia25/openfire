# Confirms Mine.beep (the fuse blink, documents 50/60) is connected to the "Button" sound cue
# when a mine is placed. Run:
#   godot --headless --path . --script tools/tests/mine_beep_check.gd
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

	var cues: Array[String] = []
	mc.vehicle.sound_cue.connect(func(id): cues.append(id))
	mc._on_mine_dropped(mc.vehicle.position + Vector2(40.0, 0.0), mc.vehicle)
	var m: Mine = mc.mines[-1]
	var dt := 1.0 / Mine.TICK_HZ
	for i in 400:   # a few blink cycles (period 30 ticks) before it arms at ~158 ticks
		m.advance(dt * Mine.TICK_HZ)
		if m.armed:
			break
	print("Button beeps heard: ", cues.count("Button"), " (expect several, mine armed: ", m.armed, ")")
	print("done")
	quit()
