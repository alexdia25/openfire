# Holds the fire button for each vehicle until its stock is gone and reports shots and empty clicks, then rearms (document 72). Run:
#   godot --headless --path . --script tools/tests/ammo_check.gd
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
	var shots := [0]
	var clicks := [0]
	v.shot.connect(func(_s): shots[0] += 1)
	v.empty_click.connect(func(): clicks[0] += 1)
	for t in 4:
		v.set_vehicle_type(t)
		v.position = Vector2(2160, 2160)
		shots[0] = 0
		clicks[0] = 0
		if t == 3:
			v.z = 0.0
		Input.action_press("ui_accept")
		for i in 6000:
			mc._process(dt)
			v._process(dt)
		Input.action_release("ui_accept")
		print(v.name if false else ["Tank", "Jeep", "MSV", "Heli"][t], " stock ", v.ammo_max, " shots ", shots[0], " clicks>0 ", clicks[0] > 0, " left ", v.ammo)
	v.set_vehicle_type(0)
	v.ammo[0] = 0
	v.zone_kind = 2
	v.zone_origin = v.position
	v.zone_box = [-50.0, -50.0, 50.0, 50.0]
	v.moving = false
	for i in 200:
		mc._update_zone(v, dt)
	print("Tank rearm after 200 ticks: ", v.ammo[0], " (expect 150)")
	quit()
