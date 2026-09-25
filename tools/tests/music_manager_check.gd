# The music manager (document 98): the pack's tracks load and a line becomes a gapless playlist of the right tracks. Run:
#   godot --headless --path . --script tools/tests/music_manager_check.gd
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
	var m := MusicManager.new()
	get_root().add_child(m)
	check("the manager sets up from the pack's music.json", m.setup(pack, mc))
	check("18 lines and 24 tracks", m.director.lines.size() == 18 and m._tracks.size() == 24)
	m.director.request(0, 0x80)
	m.director.tick()
	var pl = m._player.stream
	check("Tank 1 becomes a playlist of tracks 8-11", pl is AudioStreamPlaylist and pl.stream_count == 4, str(pl))
	var total := 0.0
	for i in pl.stream_count:
		total += pl.get_list_stream(i).get_length()
	check("... about 7 minutes long (35.7 + 210.1 + 163.2 + 8.6 s)", absf(total - 417.6) < 3.0, "%.1f s" % total)
	m.director.request(14, 0x80)
	m.director.priority = 0
	m.director.requested = -1
	m.director.request(14, 0x80)
	m.director.tick()
	pl = m._player.stream
	check("Bunker (14) is the single track 20", pl is AudioStreamPlaylist and pl.stream_count == 1 and absf(pl.get_list_stream(0).get_length() - 28.7) < 0.5)
	m.director.use_alt = true
	m.director.playing = -1
	m.director.requested = -1
	m.director.priority = 0
	m.director.request(1, 0x80)   # Tank 2: start 9, alternate 8, end 12
	m._pending = {"line": 1, "alt": true}
	m._start_pending()
	pl = m._player.stream
	check("a loop restart of Tank 2 starts at its alternate track 8 (tracks 8-11)", pl.stream_count == 4 and absf(pl.get_list_stream(0).get_length() - 35.7) < 0.5)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
