# Wrecks as objects of the 16.16 simulation (alexdia25/openfire#133 stage S5.6, wiki document 170), on the real pack: a hulk left by a vehicle that
# ran out of fuel lets its crewman out clear of its shape, stops a vehicle (which remembers it) and a soldier, takes shells (12.0 hit points; a settled
# hulk then only carries the landing bit, FUN_0040c8f0 returning before it reads it), and a wreck that slides into a building gives the tile 34 hit points
# of damage and stops. Needs the real
# pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/wreck_fx_check.gd
extends SceneTree

var _failures := 0
var mc: MatchController
var pack: Pack
var level: LevelData


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _c(t: Vector2i) -> Vector2i:
	return Vector2i(t.x * 0x200000 + 0x100000, t.y * 0x200000 + 0x100000)


func _fresh() -> void:
	if mc != null:
		mc.queue_free()
	level = LevelData.new()
	level.load_from(pack.level_dir("RFMAP002"), pack.level_override_paths("RFMAP002"))
	mc = MatchController.new()
	mc.match_seed = 1996
	mc.computer_fills_sides = false
	get_root().add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", get_root())
	mc.skip_start_hangar()
	mc._drone_cap_override = 0


## A land tile with no decoration in the 4 x 3 tiles around it, and a building tile that can be shot down.
func _find() -> Dictionary:
	var r := {}
	for y in range(4, level.height - 4):
		for x in range(4, level.width - 4):
			var t := Vector2i(x, y)
			if not r.has("open"):
				var clear := true
				for dy in range(-1, 2):
					for dx in range(-2, 2):
						var c := _c(t + Vector2i(dx, dy))
						if level.get_coastal_id(x + dx, y + dy) != 0 or Water.class_at(level, pack, Vector2(c.x / 65536.0, c.y / 65536.0)) != 0:
							clear = false
				if clear:
					r["open"] = t
			if not r.has("building"):
				var id := level.get_coastal_id(x, y)
				if id != 0 and not pack.get_coastal_shapes(id).is_empty() and mc._initial_tile_hp(t) > 0 and not mc.gates.has(t):
					r["building"] = t
	return r


## The player's vehicle, of `type`, killed where it stands at `at` (fuel out: a hulk with the body's shape).
func _hulk(type: int, at: Vector2i) -> Wreck:
	var v := mc.vehicle
	v.set_vehicle_type(type)
	v.docked = false
	v.frozen = false
	v.pos_fx = at
	v.speed_fx = 0
	v.fuel_fx = 0
	v._die()
	return mc.wrecks.back()


func _init() -> void:
	pack = Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	_fresh()
	var f := _find()
	_check(f.has("open") and f.has("building"), "RFMAP002 has open ground and a building (%s)" % [f])
	var open: Vector2i = f["open"]

	# the hulk and its crewman
	var w := _hulk(1, _c(open))
	_check(w.fuel_out and w.solid and not w.chain.is_empty(), "a Jeep out of fuel leaves a hulk with the body's shape")
	var men := mc.soldiers.size()
	for i in 12:
		mc.step()
	_check(mc.soldiers.size() == men + 1 and not w.fuel_out, "once settled, one crewman climbs out and the flag is cleared")
	var man: Soldier = mc.soldiers.back()
	_check(Collision.chains_hit_fx(w.pos_fx, w.z_fx, w.heading_fx, w.chain, man.pos_fx, 0, 0, mc._soldier_chain()).is_empty(),
		"he stands clear of the hulk's shape (%s from %s)" % [man.pos_fx - w.pos_fx, w.pos_fx])
	var row := Vehicle.dir_fx((w.heading_fx - 0x100000) & 0x3f0000)
	var off := man.pos_fx - w.pos_fx
	_check(off.x * row.y == off.y * row.x and (off.x * row.x + off.y * row.y) > 0, "stepped out along the heading less a quarter turn, in whole steps of 3")

	# a vehicle and a soldier walking into it stop; the vehicle remembers it
	var other := Vehicle.new()
	other.setup(pack)
	other.pos_fx = w.pos_fx + Vector2i(0, 0x40000)
	_check(mc.vehicle_blocked(other, other.pos_fx, other.heading_fx) and other.last_touched == w, "a vehicle driving into the hulk is stopped and remembers it (FUN_0040c150)")
	var probe := mc._soldier_probe(man, w.pos_fx, false)
	_check(probe["blocked"] and probe["object"] == w, "a soldier walking into it is stopped and notes it")
	_check(not mc._soldier_probe(man, w.pos_fx, true)["blocked"], "unless he is passing (flag 0x1000000)")

	# shells: 12.0 hit points, then the burst; the decal is met by nothing
	# (each shot ends 2 units short of the centre: a shot that ends exactly on a shape's origin is the zero-length case of the traced
	# point-in-polygon test, document 164)
	var from := w.pos_fx + Vector2i(-0x200000, 0)
	var aim := w.pos_fx + Vector2i(-0x20000, 0)
	var hits := mc.shell_hits_fx(from, 0x20000, aim, 0x20000)
	_check(hits.any(func(h): return h.get("wreck") == w), "a shell flying into the hulk hits it")
	for i in 11:
		var p := Projectile.new()
		p.damage_fx = 0x10000
		p.prev_fx = from
		p.pos_fx = aim
		p.prev_z_fx = 0x20000
		p.z_fx = 0x20000
		mc._shell_moved(p)
	_check(w.hp_fx == 0x10000 and not w.landed_flag, "eleven 1.0 shells leave it 1.0")
	var last := Projectile.new()
	last.damage_fx = 0x10000
	last.prev_fx = from
	last.pos_fx = aim
	last.prev_z_fx = 0x20000
	last.z_fx = 0x20000
	mc._shell_moved(last)
	_check(w.hp_fx == 0 and w.landed_flag, "the twelfth sets the landing bit (FUN_0040cbe0)")
	for i in 5:
		mc.step()
	_check(w.phase == Wreck.Phase.BODY and w.solid and not w.finished, "but a settled hulk never reaches the landing block: it keeps its body")
	_check(mc.shell_hits_fx(from, 0x20000, aim, 0x20000).any(func(h): return h.get("wreck") == w), "and goes on stopping shells")

	# a wreck sliding into a building: the tile takes 34 and the wreck stops
	_fresh()
	var b: Vector2i = f["building"]
	var hp := mc._initial_tile_hp(b)
	var v := mc.vehicle
	v.set_vehicle_type(0)
	v.docked = false
	v.frozen = false
	v.heading_fx = 0x100000   # east
	v.pos_fx = _c(b) - Vector2i(0x1c0000, 0)
	v.speed_fx = 0x18000
	v.take_damage(v.hp + 10.0)
	var slide: Wreck = mc.wrecks.back()
	var gone := []
	mc.tile_destroyed.connect(func(t): gone.append(t))
	var first_hit := -1
	for i in 30:
		var was := slide.pos_fx
		mc.step()
		if first_hit < 0 and slide.pos_fx == was and slide.speed_fx != 0:
			first_hit = i
			if hp > 34:
				_check(int(mc._tile_hp.get(b, hp)) == hp - 34, "the building takes 34 the tick the wreck runs into it (%d -> %s)" % [hp, mc._tile_hp.get(b)])
			else:
				_check(gone.has(b), "the building (%d hit points) is destroyed the tick the wreck runs into it" % hp)
	_check(first_hit >= 0 and slide.pos_fx.x < _c(b).x, "and the wreck is stopped short of it (%s)" % [slide.pos_fx])
	print("wreck_fx_check: %d failures" % _failures)
	quit(_failures)
