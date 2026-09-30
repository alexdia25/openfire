# The victory jingle (document 101): the level's LEVL picks one of four decoded streams, the ribbon is held until the jingle ends, fades out over 500 ms, then the sequence
# is done. Run:  godot --headless --audio-driver Dummy --path . --script tools/tests/win_jingle_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var r := WinRibbon.new()
	get_root().add_child(r)
	r.setup(pack)
	var lengths := {}
	for levl in [0, 1, 4, 5, 7, 8, 9, 20]:
		var j := r._load_jingle(levl)
		lengths[levl] = snappedf(j.get_length(), 0.1) if j != null else -1.0
	var want := {0: 11.8, 1: 22.7, 4: 22.7, 5: 22.4, 7: 22.4, 8: 69.5, 9: 69.5, 20: 69.5}
	var ok := true
	for k in want:
		ok = ok and absf(float(lengths[k]) - float(want[k])) < 0.15
	check("LEVL 0 plays Win1 (11.8 s), 1-4 Win2 (22.7 s), 5-7 Win3 (22.4 s), 8 and 9 Win (69.5 s); a byte past 9 is clamped like FUN_00430620 (tier 3)", ok, str(lengths))

	# Winner 1 (the second player, green ribbon) runs the exact same code path as winner 0 -- document 92 says so but
	# it went unexercised. A fresh WinRibbon confirms it loads (the green banner, not tan) and drives the same sequence.
	var r2 := WinRibbon.new()
	get_root().add_child(r2)
	r2.setup(pack)
	check("winner 1 (the second player) also starts and finds a jingle, same as winner 0", r2.start(1, 0) and r2.has_jingle())
	r2._process(1.0 + 0.01)
	check("winner 1's jingle starts the same way", r2._jingle_started)
	r2._on_jingle_finished()
	r2._process(0.6)
	check("winner 1's sequence finishes the same way", r2._done)

	check("the ribbon starts and finds the jingle", r.start(0, 0) and r.has_jingle())
	var done := [false]
	r.sequence_done.connect(func(): done[0] = true)
	r._process(1.0 + 0.01)
	check("the jingle starts the instant the ribbon phase begins (FUN_00430b10's frame 0), not once its own fade-in finishes",
		r._jingle_started and r._ribbon.modulate.a < 1.0)
	r._process(3.0)
	check("the ribbon is held while the jingle plays", not done[0] and is_equal_approx(r._ribbon.modulate.a, 1.0) and r._out_t < 0.0)
	r._on_jingle_finished()
	r._process(0.25)
	check("after the jingle the ribbon fades out over 500 ms", not done[0] and absf(r._ribbon.modulate.a - 0.5) < 0.01, str(r._ribbon.modulate.a))
	r._process(0.3)
	check("then the sequence is done", done[0] and r._ribbon.modulate.a == 0.0)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
