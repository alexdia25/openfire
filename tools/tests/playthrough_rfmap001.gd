# Scripted playthrough of RFMAP001 through the real game logic (no rendering): a Tank shoots the building and its ruin, returns home, the
# player becomes a Jeep, fetches the flag and carries it home. A crude tile-path autopilot stands in for the player. Run:
#   godot --headless --path . --script tools/tests/playthrough_rfmap001.gd
# Expect: "match finished true winner 0". The tile-state changes the scene applies at TILE_STATE are mimicked in _apply().
extends SceneTree

var mc: MatchController
var v: Vehicle
var dt := 1.0 / Vehicle.TICK_HZ
var tsz := 32.0
var log_lines := []
var level_ref: LevelData
var pack_ref: Pack

func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	level_ref = level
	pack_ref = pack
	mc = MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	v = mc.vehicle
	mc.target_hit.connect(func(_id, t): _apply(t))
	mc.tile_destroyed.connect(func(t): _apply(t))
	tsz = float(pack.tile_size_px)
	var home := v.position
	var target := (Vector2(75, 56) + Vector2(0.5, 0.5)) * tsz
	print("home ", home, " building ", target, " distance ", snappedf(home.distance_to(target), 1.0))
	# phase 1: the Tank drives to 70 units from the building and shoots it
	var ok := _follow(target, 70.0, 4000)
	print("phase 1 drive: reached ", ok, " at ", v.position, " hp ", v.hp)
	var ticks := 0
	while mc.pools["b"].get_active_position() != null and ticks < 3000:
		_aim(target)
		Input.action_press("ui_accept")
		_step()
		ticks += 1
	Input.action_release("ui_accept")
	print("building destroyed after ", ticks, " ticks of shooting; flags ", mc.flags.keys(), "; coastal id there now ", level_ref.get_coastal_id(75, 56))
	# the ruin (62) has 6 hit points of its own: shoot it into 63
	var t2 := 0
	while level_ref.get_coastal_id(75, 56) != 63 and t2 < 3000:
		_aim(target)
		Input.action_press("ui_accept")
		_step()
		t2 += 1
	Input.action_release("ui_accept")
	print("ruin shot after ", t2, " more ticks; coastal id there now ", level_ref.get_coastal_id(75, 56))
	# phase 2: back home, swap to a Jeep
	ok = _follow(home, 6.0, 4000)
	print("phase 2 return home: ", ok, " at ", v.position)
	for i in 120:
		_step()
	v.moving = false
	mc.switch_player_vehicle()
	mc.select_move(1)   # Tank -> Jeep in the vehicle-choice grid
	mc.confirm_selection()
	if v.vehicle_type != 1:
		mc.debug_swap_vehicle(1)
		print("  (test swapped to the Jeep; the home-tile switch did not fire)")
	print("vehicle type now ", v.vehicle_type, " (1 = Jeep)")
	# phase 3: the Jeep to the flag
	var flag: FlagMarker = mc.flags.get(1)
	if flag == null:
		print("NO FLAG SPAWNED: flags ", mc.flags)
		quit()
		return
	print("flag at ", flag.position)
	ok = _follow(flag.position, 12.0, 4000)
	var tries := 0
	while flag.carrier != v and tries < 6:
		ok = _drive_to(flag.position, 3.0, 300)
		_step()
		tries += 1
	print("phase 3 to the flag: ", ok, "; carrier ", flag.carrier == v, " at ", v.position)
	for i in 30:
		_step()
	print("carrying: ", flag.carrier == v)
	ok = _follow(home, 4.0, 4000)
	for i in 30:
		_step()
	print("phase 4 home with the flag: ", ok, " at ", v.position, " match finished ", mc.match_finished, " winner ", mc.winner_idx)
	quit()

func _apply(t: Vector2i) -> void:
	# what terrain_view_3d._apply_tile_destroyed does once the explosion script reaches TILE_STATE (immediately here)
	var cid := level_ref.get_coastal_id(t.x, t.y)
	var e := pack_ref.get_coastal_damage(cid)
	var nxt := int(e.get("destroyed_coastal", 0))
	level_ref.set_coastal_id(t.x, t.y, nxt)
	if nxt != 0:
		var base := int(pack_ref.get_coastal_damage(nxt).get("base_art", 255))
		if base != 255:
			level_ref.set_art_id(t.x, t.y, base)
	mc.tile_state_applied(t)

func _blocked_tile(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= level_ref.width or y >= level_ref.height:
		return true
	if Water.class_at(level_ref, pack_ref, (Vector2(x, y) + Vector2(0.5, 0.5)) * tsz) == 2:
		return true
	var id := level_ref.get_coastal_id(x, y)
	if id == 0:
		return false
	var info := pack_ref.get_coastal_shapes(id)
	if info.is_empty() or info.get("shapes", []).is_empty():
		return false
	if v.vehicle_type == 0 and id in [1, 2, 5, 11]:
		return false  # a Tank crushes bushes
	return not (id in [14, 39, 40, 41, 42])  # rearm / refuel pumps have enterable zones

func _path(from: Vector2, to: Vector2) -> Array:
	var s := Vector2i(int(from.x / tsz), int(from.y / tsz))
	var g := Vector2i(int(to.x / tsz), int(to.y / tsz))
	var came := {s: s}
	var q := [s]
	var found := false
	while q.size() > 0:
		var t: Vector2i = q.pop_front()
		if t == g:
			found = true
			break
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = t + d
			if came.has(n):
				continue
			if n != g and _blocked_tile(n.x, n.y):
				continue
			came[n] = t
			q.append(n)
	if not found:
		return []
	var out := []
	var c := g
	while c != s:
		out.push_front((Vector2(c) + Vector2(0.5, 0.5)) * tsz)
		c = came[c]
	return out

func _follow(to: Vector2, radius: float, max_ticks: int) -> bool:
	var path := _path(v.position, to)
	print("  planned ", path.size(), " waypoints")
	if path.is_empty():
		return false
	var total := 0
	for w in path:
		if v.position.distance_to(to) <= radius:
			return true
		var ok := _drive_to(w, 30.0, 600)
		total += 1
		if not ok:
			print("  failed at waypoint ", total, " of ", path.size(), " ", w, " pos ", v.position, " heading ", snappedf(v.heading_deg, 1.0), " water ", v.water_class, " swim ", v.swim_amount, " fuel ", snappedf(v.fuel, 1.0), " alive ", v.alive, " speed ", snappedf(v.speed, 0.1))
			var pt := Vector2i(int(v.position.x / tsz), int(v.position.y / tsz))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var tt := pt + Vector2i(dx, dy)
					print("    tile ", tt, " coastal ", level_ref.get_coastal_id(tt.x, tt.y), " art ", level_ref.get_art_id(tt.x, tt.y) & 0x7f, " wc ", Water.class_at(level_ref, pack_ref, (Vector2(tt) + Vector2(0.5, 0.5)) * tsz))
			return false
	return _drive_to(to, radius, 600)

func _step() -> void:
	for p in mc._projectiles:
		if is_instance_valid(p):
			p._process(dt)
	v._process(dt)
	mc._process(dt)

func _aim(to: Vector2) -> void:
	var want := rad_to_deg((to - v.position).angle())
	var d := wrapf(want - v.heading_deg, -180.0, 180.0)
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	if d > 4.0:
		Input.action_press("ui_right")
	elif d < -4.0:
		Input.action_press("ui_left")

func _drive_to(to: Vector2, radius: float, max_ticks: int) -> bool:
	var t := 0
	var last_pos := v.position
	var unstick := 0
	var unstick_dir := 1.0
	var stuck_count := 0
	while v.position.distance_to(to) > radius and t < max_ticks:
		if unstick > 0:
			unstick -= 1
			Input.action_release("ui_up")
			Input.action_press("ui_down")
			Input.action_release("ui_left")
			Input.action_release("ui_right")
			Input.action_press("ui_right" if unstick_dir > 0 else "ui_left")
		else:
			Input.action_release("ui_down")
			_aim(to)
			var want := rad_to_deg((to - v.position).angle())
			var d := absf(wrapf(want - v.heading_deg, -180.0, 180.0))
			if d < 30.0:
				Input.action_press("ui_up")
			else:
				Input.action_release("ui_up")
		_step()
		t += 1
		if t % 45 == 0 and unstick == 0:
			if v.position.distance_to(last_pos) < 3.0:
				stuck_count += 1
				unstick = 70
				unstick_dir = -unstick_dir
				if stuck_count > 40:
					print("  GAVE UP at ", v.position, " going to ", to)
					break
			last_pos = v.position
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	print("  drive took ", t, " ticks, unstick episodes ", stuck_count)
	return v.position.distance_to(to) <= radius
