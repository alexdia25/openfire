# The vehicle's height and water on integers (alexdia25/openfire#133 stage S6.1, wiki document 171), on the real pack (RFMAP002):
#  - FUN_0042f280 / FUN_0042f410 on integers: a point within a unit of a shore tile's centre never overlaps the coast shape (FUN_0041d670's
#    whole-unit cut makes the segment to the centre a point);
#  - the water handler runs after the move: a Tank driving into the water is classed and starts wading on the tick it gets there, and in
#    deep water it sinks 0x6666 a tick and is lost at exactly 0x10000 - (depth & 0xffff0000);
#  - FUN_0040b980's move step: a vehicle turning into a wall stops and keeps its speed (no bounce), one driving straight in bounces;
#  - the Heli's climb is part of its move: blocked, it does not climb;
#  - the dock sink fades from the tick after the height is below -0x100000 and ends at exactly -0x200000; the pad rise releases the
#    vehicle the tick after its height reaches 0.
# Needs the real pack (res://packs/original_pc). Run:
#   godot --headless --path . --script tools/tests/height_fx_check.gd
extends SceneTree

var _failures := 0
var mc: MatchController
var pack: Pack
var level: LevelData


class ScriptedControls extends PlayerControls:
	var held := 0

	func poll() -> int:
		prev_word = word
		word = held
		return word

	func read_word() -> int:
		return word

	func state() -> int:
		return InputWord.decode(word, prev_word)


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _c(t: Vector2i) -> Vector2i:
	return Vector2i(t.x * 0x200000 + 0x100000, t.y * 0x200000 + 0x100000)


func _fresh(type: int, held: int) -> Vehicle:
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
	var v := mc.vehicle
	v.set_vehicle_type(type)
	v.docked = false
	v.frozen = false
	v.skip_start()   # no roll off the pad (wiki document 173)
	var ctl := ScriptedControls.new()
	ctl.held = held
	v.controls = ctl
	mc.slots[0].controls = ctl
	return v


func _init() -> void:
	pack = Pack.new()
	pack.load_from("res://packs/original_pc")
	_fresh(0, 0)

	# 1. the shore tiles' centres
	var found := false
	for y in level.height:
		for x in level.width:
			if found or (level.get_art_id(x, y) & 0x7f) != 5 or level.get_coastal_id(x, y) != 0:
				continue
			found = true
			var c := _c(Vector2i(x, y))
			_check(Water.class_at_fx(level, pack, c) == 0, "art 5 (flag set): the point at the centre does not overlap the coast shape: land")
			_check(Water.class_at_fx(level, pack, c + Vector2i(0, -0x40000)) == 1, "... and 4 units north of it, inside the shape, it is shallow")
			_check(Water.class_at_fx(level, pack, c + Vector2i(0, -0x40000), 0, 0x10001) == 0, "... but not above 0x10000")
	_check(found, "an art-5 shore tile exists on RFMAP002")

	# 2. into deep water, south from the land at (89, 42)
	var v := _fresh(0, InputWord.UP)
	v.pos_fx = _c(Vector2i(89, 44)) - Vector2i(0, 0x380000)
	v.heading_fx = 0x200000
	var wade_tick := -1
	var sink_tick := -1
	var lost_tick := -1
	var falls := true
	var last_h := 0
	for i in 400:
		var was_class := v.water_class_now()
		mc.step()
		if wade_tick < 0 and v.wading:
			wade_tick = i
			_check(was_class == 0 and v.water_class == 1, "the class is taken after the move: wading starts on the tick the Tank reaches the shallows")
			_check(v.wade_counter_fx == 0x40000, "the splash counter starts at 0x40000 (%x)" % v.wade_counter_fx)
		if sink_tick < 0 and v._sinking:
			sink_tick = i
			last_h = v.height_fx
		elif sink_tick >= 0 and v.alive:
			falls = falls and v.height_fx == last_h - 0x6666
			last_h = v.height_fx
		if not v.alive:
			lost_tick = i
			break
	_check(wade_tick >= 0 and sink_tick > wade_tick, "the Tank wades (tick %d), then sinks in deep water (tick %d)" % [wade_tick, sink_tick])
	_check(falls, "it falls exactly 0x6666 a tick")
	_check(lost_tick > sink_tick and v.height_fx == 0x10000 - (14 << 16), "it is lost at exactly 0x10000 - 14.0 (%x, tick %d)" % [v.height_fx, lost_tick])

	# 3. a Jeep turning into the building at (40, 31) from the north stops and keeps its speed; a Tank driving straight in bounces (the
	#    Jeep is narrow enough to pass it straight)
	v = _fresh(1, InputWord.UP | InputWord.RIGHT)
	v.pos_fx = _c(Vector2i(40, 31)) - Vector2i(0, 0x220000)
	v.heading_fx = 0x200000
	var stuck := -1
	for i in 80:
		var was := v.pos_fx
		var hd := v.heading_fx
		mc.step()
		if v.speed_fx > 0 and v.pos_fx == was and v.heading_fx == hd:
			stuck = i
			break
	var spd := v.speed_fx
	var at := v.pos_fx
	for i in 5:
		mc.step()
	_check(stuck >= 0 and v.speed_fx == spd and v.pos_fx == at and spd > 0, "turning into the building it stops and keeps its speed (tick %d, %d)" % [stuck, spd])
	v = _fresh(0, InputWord.UP)
	v.pos_fx = _c(Vector2i(40, 31)) - Vector2i(0, 0x220000)
	v.heading_fx = 0x200000
	var bounced := false
	for i in 80:
		mc.step()
		if v.speed_fx < 0:
			bounced = true
			break
	_check(bounced, "a Tank driving straight in bounces (-speed >> 2)")

	# 4. the Heli turning into the building low: blocked, it does not climb either
	v = _fresh(3, InputWord.UP | InputWord.RIGHT)
	v.pos_fx = _c(Vector2i(40, 31)) - Vector2i(0, 0x360000)
	v.heading_fx = 0x200000
	var blocked_climb := false
	var climbs := true
	for i in 160:
		var was := v.pos_fx
		var h := v.height_fx
		mc.step()
		if v.pos_fx == was and v.height_fx == h and h < 0x320000:
			blocked_climb = true
		elif v.pos_fx != was and h < 0x320000:
			climbs = climbs and v.height_fx == mini(h + 0x8000, 0x320000)
	_check(blocked_climb, "a blocked Heli move undoes its climb")
	_check(climbs, "a clear one climbs exactly 0x8000 a tick")

	# 5. the dock and the pad rise
	v = _fresh(0, 0)
	var ps := mc.slots[0]
	v.position = ps.spawn_px
	mc.step()
	_check(mc.can_dock(v), "the Tank can dock on its pad")
	mc._begin_dock(ps)
	var fade_ok := true
	var end_h := 0
	for i in 200:
		var pre := v.height_fx
		var fade := ps.view_fade
		mc.step()
		if ps.selecting:
			end_h = v.height_fx
			break
		if pre > -0x100001:
			fade_ok = fade_ok and ps.view_fade == fade
	_check(fade_ok, "the view does not fade while the height was above -0x100001 at the start of the tick")
	_check(end_h == -0x200000 and v.docked, "the dock ends at exactly -0x200000 (%x)" % end_h)
	mc._begin_pad_rise(ps)
	var zero_tick := -1
	var free_tick := -1
	for i in 200:
		mc.step()
		if zero_tick < 0 and v.height_fx == 0:
			zero_tick = i
			_check(v.frozen and ps.pad_rising, "at height 0 the vehicle is still held")
		if not ps.pad_rising:
			free_tick = i
			break
	_check(zero_tick >= 0 and free_tick == zero_tick + 1 and not v.frozen, "it is released the tick after (%d, %d)" % [zero_tick, free_tick])
	print("height_fx_check: %d failures" % _failures)
	quit(_failures)
