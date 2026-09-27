# Dev tool, not a test: draws every vehicle in a fixed set of poses with the game's renderer (VehicleRender3D.create_for) and
# saves one PNG per pose, so a renderer change can be checked pixel for pixel against the images made before it.
#   godot --audio-driver Dummy --path . --script tools/tests/render_gallery.gd -- <out_dir> [name filter]
# (a real window: this needs the rendering driver, not --headless)
extends SceneTree

const W := 360
const H := 300


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://gallery"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var pack := ModLoader.load_game_pack()
	get_root().size = Vector2i(W, H)
	var world := Node3D.new()
	get_root().add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.25)
	world.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 40.0
	world.add_child(cam)
	cam.current = true
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(192, 192)
	plane.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.55, 0.45, 0.32)
	plane.material_override = gm
	world.add_child(plane)

	await process_frame   # the scene is in the tree from here on (look_at needs it)
	var poses: Array = []   # [name, type, colour, flash, {field: value}]
	for colour in ["tan", "green"]:
		for h in [0.0, 200.0]:
			poses.append(["tank_%s_h%d" % [colour, h], 0, colour, false, {"heading_deg": h}])
	poses.append(["tank_rear", 0, "tan", false, {"heading_deg": 200.0}, [200.0, 35.0, 30.0]])
	poses.append(["tank_side", 0, "tan", false, {"heading_deg": 200.0}, [110.0, 15.0, 30.0]])
	poses.append(["tank_top", 0, "tan", false, {"heading_deg": 0.0}, [90.0, 89.0, 34.0]])
	poses.append(["tank_back", 0, "green", false, {"heading_deg": 0.0}, [-90.0, 25.0, 30.0]])
	poses.append(["tank_side_l", 0, "tan", false, {"heading_deg": 0.0}, [0.0, 10.0, 30.0]])
	poses.append(["tank_side_r", 0, "tan", false, {"heading_deg": 0.0}, [180.0, 10.0, 30.0]])
	poses.append(["tank_flash", 0, "tan", true, {"heading_deg": 200.0}])
	poses.append(["tank_turret40", 0, "tan", false, {"heading_deg": 200.0, "turret_deg": 40.0}])
	poses.append(["tank_turret200_elev25", 0, "green", false, {"heading_deg": 30.0, "turret_deg": 200.0, "gun_elev_deg": 25.0}])
	poses.append(["tank_elev12", 0, "tan", false, {"heading_deg": 200.0, "gun_elev_deg": 12.0}])
	for x in [0.0, 1.0, 2.0, 3.0]:
		poses.append(["jeep_frame%d" % x, 1, "tan", false, {"heading_deg": 200.0, "position": Vector2(x + 0.5, 0.0)}])
	for s in [0.0, 0.3, 0.5, 0.7, 1.0]:
		poses.append(["jeep_swim%d" % int(s * 10), 1, "green", false, {"heading_deg": 200.0, "swim_amount": s}])
	poses.append(["jeep_flash", 1, "tan", true, {"heading_deg": 200.0}])
	for fired in [0, 1, 2]:
		poses.append(["msv_fired%d" % fired, 2, "tan", false, {"heading_deg": 200.0, "_salvo_index": fired}])
	poses.append(["msv_elev20_reload", 2, "green", false, {"heading_deg": 200.0, "gun_elev_deg": 20.0, "_salvo_reload": 30.0}])
	poses.append(["msv_flash", 2, "tan", true, {"heading_deg": 200.0}])
	for sp in [0.0, 1.0, 2.0, 3.0, 4.0]:
		poses.append(["heli_rotor%d" % sp, 3, "tan", false, {"heading_deg": 200.0, "rotor_speed_steps": sp, "heli_spinup_stage": 0}])
	poses.append(["heli_fold25", 3, "tan", false, {"heading_deg": 200.0, "rotor_speed_steps": 0.0, "heli_spinup_stage": 1, "_heli_spinup_progress": 0.25}])
	poses.append(["heli_fold75", 3, "green", false, {"heading_deg": 200.0, "rotor_speed_steps": 0.0, "heli_spinup_stage": 1, "_heli_spinup_progress": 0.75}])
	poses.append(["heli_tilt", 3, "green", false, {"heading_deg": 120.0, "rotor_speed_steps": 4.0, "heli_spinup_stage": 0, "z": 50.0, "speed": 60.0, "bank_steps": 2.0}])

	var only: String = args[1] if args.size() > 1 else ""   # a substring of the pose names to draw (default: all)
	for p in poses:
		if only != "" and not String(p[0]).contains(only):
			continue
		var v := Vehicle.new()
		v.team = "tan"
		v.colour = p[2]
		v.setup(pack)
		v.set_vehicle_type(p[1])
		for k in p[4]:
			v.set(k, p[4][k])
		v.hit_flash_remaining = 1.0e9 if p[3] else 0.0
		var r := VehicleRender3D.create_for(v, pack, world)
		r.set_process(false)   # frozen at the pose: a spinning rotor would otherwise depend on the frame times
		r._process(0.0)
		var target := Vector3(0.0, 6.0 + v.z * 0.6, 0.0)
		var view: Array = p[5] if p.size() > 5 else [35.0, 38.0, 42.0]   # yaw, pitch, distance
		var yw := deg_to_rad(view[0])
		var pt := deg_to_rad(view[1])
		cam.position = target + Vector3(sin(yw) * cos(pt), sin(pt), cos(yw) * cos(pt)) * float(view[2])
		cam.look_at(target)
		# the vehicle stays where it is (position is a gameplay value the renderer follows): put the camera on it
		cam.position += Vector3(v.position.x, 0.0, v.position.y)
		cam.look_at(target + Vector3(v.position.x, 0.0, v.position.y))
		for i in 3:
			await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/%s.png" % [out_dir, p[0]])
		r.get_parent().remove_child(r)
		r.free()
		v.free()
	print("gallery: %d poses -> %s" % [poses.size(), out_dir])
	quit()
