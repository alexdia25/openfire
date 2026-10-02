# What the original draws while a vehicle wades or sinks (issue #25, document 122): the water handlers' state machine and the descriptor the render
# block shows for it. Run:
#   godot --headless --path . --script tools/tests/water_view_check.gd
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
	var tsz := float(pack.tile_size_px)
	# a strip of shallow water (art 1) at row 80, a strip of deep (art 2) at row 90, land elsewhere
	for x in range(40, 60):
		for dy in range(-1, 2):
			level.set_art_id(x, 80 + dy, 1)
			level.set_art_id(x, 90 + dy, 2)
	var shallow := (Vector2(50, 80) + Vector2(0.5, 0.5)) * tsz
	var deep := (Vector2(50, 90) + Vector2(0.5, 0.5)) * tsz
	level.set_art_id(50, 70, 0)
	var land := (Vector2(50, 70) + Vector2(0.5, 0.5)) * tsz
	check("the fixture: shallow, deep and land", Water.class_at(level, pack, shallow) == 1 and Water.class_at(level, pack, deep) == 2 and Water.class_at(level, pack, land) == 0,
			"%d %d %d" % [Water.class_at(level, pack, shallow), Water.class_at(level, pack, deep), Water.class_at(level, pack, land)])

	var dt := 1.0 / Vehicle.TICK_HZ
	for t in [0, 1, 2]:
		var v: Vehicle = mc.vehicle
		v.set_vehicle_type(t)
		var name := String(pack.vehicle_def(t).get("name", t))
		v.position = land
		v.speed = 0.0
		v._update_water(dt)
		check("%s: dry on land (view 0, no wading)" % name, v.water_view() == 0 and not v.wading)

		# moving forward at full speed into shallow water starts the wading handler at counter 4.0 (frame 4)
		v.position = shallow
		v.speed = v.max_speed
		v._update_water(dt)
		check("%s: fast in shallow water wades (view 1, counter 4, frame 4)" % name, v.water_view() == 1 and v.wading and is_equal_approx(v.wade_counter, 4.0)
				and v.channel("wade_frame") == 4.0, "%s %s" % [v.water_view(), v.wade_counter])
		for i in 25:
			v._update_water(dt)
		check("%s: the counter grows 0.2 a tick and wraps back by 5 at 13 while it keeps wading" % name, v.wade_counter > 8.0 and v.wade_counter < 13.0, str(v.wade_counter))
		for i in 200:
			v._update_water(dt)
		check("%s: it stays in 8..13 as it loops" % name, v.wading and v.wade_counter >= 8.0 and v.wade_counter < 13.0, str(v.wade_counter))

		# stopping: not wading any more, the counter runs to 13, wraps to 0 and the handler ends when it passes 3 -> 4
		v.speed = 0.0
		var ticks := 0
		while v.wading and ticks < 400:
			v._update_water(dt)
			ticks += 1
		check("%s: stopped in the shallows the splash dies away (%d ticks)" % [name, ticks], not v.wading and v.water_view() == 0 and ticks < 400)

		# slow in shallow water does not start it
		v.speed = v.max_speed * 0.1
		v._update_water(dt)
		check("%s: slow in shallow water does not wade" % name, not v.wading)

		# deep water sinks, the sinking descriptor replaces the vehicle, and the frame is the depth
		v.position = deep
		v.speed = 0.0
		v._update_water(dt)
		check("%s: deep water installs the sinking handler (view 2)" % name, v.water_view() == 2 and v._sinking and not v.wading)
		for i in 10:
			v._update_water(dt)
		check("%s: the sinking frame is the depth, -floor(z)" % name, v.channel("sink_frame") == -floorf(v.z) and v.channel("sink_frame") >= 1.0, str(v.z))
		v._sinking = false
		v.z = 0.0

	# the Jeep's swimming spray: wading while its swim amount is not 0 draws descriptor 0x43fe18 (view 3), frames from the remap
	var jeep: Vehicle = mc.vehicle
	jeep.set_vehicle_type(1)
	jeep.position = shallow
	jeep.swim_target = 1.0
	jeep.swim_amount = 0.5
	jeep.speed = jeep.max_speed
	jeep.wading = true
	jeep.wade_counter = 6.0
	check("the swimming Jeep wades in view 3", jeep.water_view() == 3)
	check("swim frame remap: 4 + 1.5 * (6 - 4) = 7", jeep.wade_swim_frame() == 7, str(jeep.wade_swim_frame()))
	jeep.wade_counter = 10.0
	check("swim frame remap: 10 + 1.6 * (10 - 8) = 13", jeep.wade_swim_frame() == 13, str(jeep.wade_swim_frame()))
	jeep.wade_counter = 12.9
	check("swim frame remap is capped at 17", jeep.wade_swim_frame() <= 17, str(jeep.wade_swim_frame()))

	# the render block: parts with `modes` are drawn only in their view, the others not while sinking
	var r := VehicleRender3D.new()
	root.add_child(r)
	jeep.set_vehicle_type(1)
	jeep.swim_target = 0.0
	jeep.swim_amount = 0.0
	jeep.wading = false
	jeep._sinking = false
	r.setup(jeep, pack)
	var def_parts: Array = pack.vehicle_def(1)["render"]["parts"]
	for view in [0, 1, 2]:
		jeep.wading = view == 1
		jeep._sinking = view == 2
		jeep.z = -3.0 if view == 2 else 0.0
		r._update_parts()
		var shown := 0
		var hull_shown := 0
		for i in def_parts.size():
			var mi: MeshInstance3D = r._parts[i]["mesh"]
			if mi.visible and mi.mesh != null:
				shown += 1
				if not def_parts[i].has("modes"):
					hull_shown += 1
		print("     view %d: %d parts drawn, %d of them the vehicle's" % [view, shown, hull_shown])
		if view == 0:
			check("dry: the hull is drawn and none of the overlays", hull_shown > 0 and shown == hull_shown)
		elif view == 1:
			check("wading: the hull and the spray quad", hull_shown > 0 and shown == hull_shown + 1)
		else:
			check("sinking: no hull, the two sinking pictures and the ripple", hull_shown == 0 and shown == 3)
	print("water_view_check: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)
