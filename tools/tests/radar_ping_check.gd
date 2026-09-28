# The radar ping (documents 68, 71, 103): the panel's own vehicle pings for the 74 ticks after it is hit (state+0x4c, the
# same "hit until" deadline as the hit flash, document 47/59), stepping evenly through the 16 growing-ring cels; a hit on
# any OTHER vehicle, or armour blocking the hit entirely, does not start it. Run:
#   godot --headless --path . --script tools/tests/radar_ping_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	check("the pack has the ping data (tools/extract_radar.py)", pack.radar_data.get("ping", {}).size() > 0)
	var level := LevelData.new()
	assert(level.load_from("res://packs/original_pc/levels/RFMAP001"))
	var root := Node2D.new()
	get_root().add_child(root)
	var mc := MatchController.new()
	root.add_child(mc)
	mc.setup(pack, level, "res://packs/original_pc", root)
	var v := mc.vehicle

	check("no ping before anyone is hit", mc.radar_ping_frame() == -1)

	var ticks_per_ms := Vehicle.TICK_HZ / 1000.0
	var now := Time.get_ticks_msec()
	mc._player_hit_at_ms = float(now)
	check("frame 0 right at the hit", mc.radar_ping_frame() == 0)
	mc._player_hit_at_ms = now - 37.0 / ticks_per_ms   # halfway through the 74-tick window
	check("about frame 7-8 halfway through the window", mc.radar_ping_frame() in [7, 8], str(mc.radar_ping_frame()))
	mc._player_hit_at_ms = now - 70.0 / ticks_per_ms   # near the end of the 74-tick window (headroom for this test's own real-clock drift)
	check("near the last frame close to when the window ends", mc.radar_ping_frame() in [14, 15], str(mc.radar_ping_frame()))
	mc._player_hit_at_ms = now - 75.0 / ticks_per_ms   # one tick past the traced (-10, 64) window (74 ticks after the hit)
	check("no ping once the window has closed", mc.radar_ping_frame() == -1)

	mc._player_hit_at_ms = -1.0e9
	mc._register_hit(mc.enemy_vehicles[0] if not mc.enemy_vehicles.is_empty() else v)   # a non-player hit, if one exists, must not start it
	if not mc.enemy_vehicles.is_empty():
		check("hitting a non-player vehicle does not ping the player's radar", mc.radar_ping_frame() == -1)
	mc._register_hit(v)
	check("registering the player's own hit starts the ping", mc.radar_ping_frame() >= 0)

	mc._player_hit_at_ms = -1.0e9
	v.armor = 1000.0   # blocks take_damage() outright (Vehicle.take_damage: damage <= armor -> false)
	var before := v.hp
	v.take_damage(1.0)
	check("armour blocking the hit leaves hp untouched", v.hp == before)
	check("...and does not start a ping (match_controller only registers a successful take_damage)", mc.radar_ping_frame() == -1)

	var radar := RadarView.new()
	root.add_child(radar)
	radar.setup(mc)
	check("RadarView built the ping overlay", radar._ping != null)
	check("...sized to the window, matching the base radar image", radar._ping.size == radar.size, str(radar._ping.size) + " vs " + str(radar.size))
	var tex0 := radar._ping_texture(0)
	var tex15 := radar._ping_texture(15)
	check("frame 0 and frame 15 are different regions", tex0.region != tex15.region)
	check("both resolve to a real atlas", tex0.atlas != null and tex15.atlas != null)

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
