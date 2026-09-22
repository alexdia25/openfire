# Confirms Vehicle._process_fuel_warn() plays "FuelWarn" once fuel drops below fuel_max/8 (a
# traced one-eighth-of-a-tank threshold, FUN_0040b980), repeating on a 120-tick cooldown while
# still low, and not at all above the threshold. Run:
#   godot --headless --path . --script tools/tests/fuel_warn_check.gd
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
	var v := mc.vehicle
	var dt := 1.0 / Vehicle.TICK_HZ

	var cues: Array[String] = []
	v.sound_cue.connect(func(id): cues.append(id))

	# above threshold: no warning for a few hundred ticks
	v.fuel = v.fuel_max * 0.5
	for i in 300:
		v._process(dt)
	print("cues above 1/8 tank (expect empty): ", cues)

	# drop just below the threshold and watch it fire, then repeat on cooldown
	v.fuel = v.fuel_max / 8.0 - 1.0
	cues.clear()
	var first_tick := -1
	for i in 260:
		v._process(dt)
		if first_tick < 0 and not cues.is_empty():
			first_tick = i
	print("cues below 1/8 tank over 260 ticks (expect 3, at ticks 0/120/240): ", cues, " first at tick ", first_tick)
	print("done")
	quit()
