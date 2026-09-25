# Golden behaviour check for all four vehicles (PORTING_PLAN.md 2.7.6 step 4): each is driven through the same scripted
# inputs -- throttle, turns, the turret keys, level and raised fire, the mine key, the Heli's weapon toggle and strafe --
# for 600 ticks of 16 ms on RFMAP001, and everything it does is recorded (position, heading, speed, turret, gun, height,
# rotor, bank, ammo, every shot). The recording's hash must equal the one recorded from the code before the behaviour
# modules (tools/tests/data/vehicle_traces.json), so a refactor that changes behaviour by even one tick fails here.
#   godot --headless --path . --script tools/tests/vehicle_behaviour_trace_check.gd
#   ... -- --record   rewrites the golden file (only when behaviour is MEANT to change, e.g. a new trace)
extends SceneTree

const GOLDEN := "res://tools/tests/data/vehicle_traces.json"
const TICKS := 600
const DT := 1.0 / 62.5


## A vehicle whose input seams read a fixed schedule instead of the keyboard.
class ScriptedVehicle extends Vehicle:
	var tick := 0

	func _get_controls() -> Vector2:
		var turn := 0.0
		if tick % 200 >= 60 and tick % 200 < 110:
			turn = 1.0
		elif tick % 200 >= 150 and tick % 200 < 170:
			turn = -1.0
		var thrust := 1.0 if tick < 300 else (-1.0 if tick < 360 else (0.0 if tick < 420 else 1.0))
		return Vector2(turn, thrust)

	func _aim_keys() -> Array:
		return [tick % 150 < 30, tick % 150 >= 70 and tick % 150 < 90, tick >= 500 and tick < 505]

	func _wants_to_fire() -> bool:
		return tick % 90 < 3

	func _wants_raised() -> bool:
		return tick % 130 >= 60 and tick % 130 < 63

	func _wants_mine() -> bool:
		return tick % 170 < 2


func _run(pack: Pack, level: LevelData, type: int) -> String:
	var v := ScriptedVehicle.new()
	v.team = "tan"
	v.setup(pack)
	v.level = level
	v.set_vehicle_type(type)
	v.mine_layer_enabled = true
	var sp: Dictionary = level.spawn_points[0]
	v.position = (Vector2(float(sp["x"]), float(sp["y"])) + Vector2(0.5, 0.5)) * 32.0 + Vector2(64, 64)
	var shots: Array = []
	v.shot.connect(func(spec): shots.append("%d:%s:%s:%.3f" % [v.tick, spec.get("type"), str(Vector2(spec["position"]).snapped(Vector2(0.001, 0.001))), float(spec.get("z", 0.0))]))
	v.mine_dropped.connect(func(at): shots.append("%d:mine:%s" % [v.tick, str(Vector2(at).snapped(Vector2(0.001, 0.001)))]))
	var lines := PackedStringArray()
	for t in TICKS:
		v.tick = t
		if type == 3 and t == 250:
			v.toggle_heli_slot()
		v._process(DT)
		if t % 10 == 0:
			lines.append("%d %.4f,%.4f h%.4f s%.4f tu%.4f g%.4f z%.4f r%.4f b%.4f a%d/%d f%.3f" % [t, v.position.x, v.position.y, v.heading_deg,
					v.speed, v.turret_deg, v.gun_elev_deg, v.z, v.rotor_speed_steps, v.bank_steps, v.ammo[0], v.ammo[1], v.fuel])
	lines.append_array(PackedStringArray(shots))
	v.free()
	return "\n".join(lines)


func _init() -> void:
	var pack := Pack.new()
	pack.load_from("res://packs/original_pc")
	var level := LevelData.new()
	level.load_from(pack.level_dir("RFMAP001"))
	var record := "--record" in OS.get_cmdline_user_args()
	var golden: Dictionary = {}
	if FileAccess.file_exists(GOLDEN):
		golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var failures := 0
	var out := {}
	for type in 4:
		var trace := _run(pack, level, type)
		out[str(type)] = {"md5": trace.md5_text(), "lines": trace.count("\n") + 1}
		if record:
			print("type %d: %s (%d lines)" % [type, out[str(type)]["md5"], out[str(type)]["lines"]])
			if OS.get_environment("RF_TRACE_DUMP") != "":
				FileAccess.open(OS.get_environment("RF_TRACE_DUMP") + "_%d.txt" % type, FileAccess.WRITE).store_string(trace)
			continue
		var want: Dictionary = golden.get(str(type), {})
		var ok: bool = want.get("md5", "") == out[str(type)]["md5"]
		print("%s  type %d behaves exactly as recorded (%d lines)" % ["ok  " if ok else "FAIL", type, out[str(type)]["lines"]])
		if not ok:
			failures += 1
			if OS.get_environment("RF_TRACE_DUMP") != "":
				FileAccess.open(OS.get_environment("RF_TRACE_DUMP") + "_%d.txt" % type, FileAccess.WRITE).store_string(trace)
	if record:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN).get_base_dir())
		FileAccess.open(GOLDEN, FileAccess.WRITE).store_string(JSON.stringify(out, "\t", true) + "\n")
		print("recorded %s" % GOLDEN)
		quit(0)
		return
	print("vehicle_behaviour_trace_check: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)
