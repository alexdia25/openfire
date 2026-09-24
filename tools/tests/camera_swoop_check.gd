# The camera swoop-in's traced easing and its setting (document 90).
#   godot --headless --path . --script tools/tests/camera_swoop_check.gd
extends SceneTree

func _init() -> void:
	for type in [0, 3]:
		var sw := CameraSwoop.new(type)
		var half := -1
		var arrived := -1
		var pitch_arrived := -1
		var t := 0
		while not sw.done and t < 1000:
			sw.advance(1.0)
			t += 1
			if half < 0 and sw.height_fraction() < 0.5:
				half = t
			if arrived < 0 and sw._height.value <= sw._height.target + 1.0:
				arrived = t
			if pitch_arrived < 0 and sw._pitch.value < sw._pitch.target + 1.0:
				pitch_arrived = t
		print("type ", type, ": height half way at tick ", half, ", within 1 unit at tick ", arrived, ", pitch within 1 at tick ", pitch_arrived, ", done at tick ", t)
		if type == 0:
			assert(arrived > 195 and arrived < 215)
		assert(sw.height_fraction() == 0.0 or sw.height_fraction() < 0.01)
	var fast := CameraSwoop.new(0)
	fast.advance(0.4)
	fast.advance(0.4)
	print("0.8 ticks accumulated: fraction ", fast.height_fraction(), " (expect 1.0: no whole tick yet)")
	fast.advance(0.4)
	print("1.2 ticks: fraction ", snappedf(fast.height_fraction(), 0.0001), " (expect just under 1.0)")

	GameSettings.camera_swoop_in = false
	GameSettings.save_settings()
	GameSettings.camera_swoop_in = true
	GameSettings.load_settings()
	print("setting round trip: camera_swoop_in ", GameSettings.camera_swoop_in, " (expect false)")
	assert(not GameSettings.camera_swoop_in)
	GameSettings.camera_swoop_in = true
	GameSettings.save_settings()
	GameSettings.load_settings()
	print("restored: ", GameSettings.camera_swoop_in, " (expect true)")
	quit()
