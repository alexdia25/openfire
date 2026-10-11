# The original's progression as the Return Fire pack declares it (ui/progression.json, wiki document 128, issue #103): a new player has Level 1 only (one map: RFMAP001), a win
# opens the next level once every map of the level is done (any one in the two-player mode), a map started 20 times counts, a lost game marks nothing. Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/progression_pack_check.gd
extends SceneTree

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _open_count(pr: Progression, pack: Pack, mode: int) -> int:
	var n := 0
	for id in pack.list_levels():
		if LevelData.peek_players(pack.level_dir(id)) == mode and pr.is_open(id, mode):
			n += 1
	return n


func _by_difficulty(pack: Pack, mode: int, difficulty: int) -> Array[String]:
	var out: Array[String] = []
	for id in pack.list_levels():
		if LevelData.peek_players(pack.level_dir(id)) == mode and LevelData.peek_difficulty(pack.level_dir(id)) == difficulty:
			out.append(String(id))
	return out


func _init() -> void:
	ProgressStore.path = "user://progression_pack_check.json"
	ProgressStore.clear()
	var pack := ModLoader.load_game_pack()
	var pr := Progression.from_pack(pack)
	_check(pr != null and pr.problems().is_empty(), "the pack declares progression, and it is sound: %s" % [pr.problems() if pr != null else "none"])
	var l1 := _by_difficulty(pack, 1, 1)
	var l2 := _by_difficulty(pack, 1, 2)
	_check(l1 == ["RFMAP001"] and l2.size() == 12, "Level 1 is RFMAP001 alone, Level 2 has 12 maps (document 125): %s, %d" % [l1, l2.size()])
	_check(_open_count(pr, pack, 1) == 1 and pr.is_open("RFMAP001", 1), "a new one-player game has only Level 1 open")

	var lost := pr.state("RFMAP001", 1)
	_check(lost == 0, "nothing is done before a win")
	pr.record_won("RFMAP001", 1, 100)
	_check(_open_count(pr, pack, 1) == 1 + l2.size(), "winning every map of Level 1 opens exactly Level 2: %d open" % _open_count(pr, pack, 1))

	for i in l2.size() - 1:
		pr.record_won(l2[i], 1, 50)
	var l3 := _by_difficulty(pack, 1, 3)
	_check(not pr.is_open(l3[0], 1), "all but one map of Level 2 is not enough for Level 3")
	for i in 19:
		pr.record_started(l2[l2.size() - 1], 1)
	_check(not pr.is_open(l3[0], 1), "19 starts of the last map do not count")
	pr.record_started(l2[l2.size() - 1], 1)
	_check(pr.state(l2[l2.size() - 1], 1) == 2 and pr.is_open(l3[0], 1), "the 20th start does (the original's counter: record +0x18 > 0x13)")

	var p2 := _by_difficulty(pack, 2, 2)
	_check(not p2.is_empty() and not pr.is_open(p2[0], 2), "the two-player mode has its own records: nothing done there")
	var first2 := _by_difficulty(pack, 2, 1)
	if not first2.is_empty():
		pr.record_won(first2[0], 2, 60)
		_check(pr.is_open(p2[0], 2), "in the two-player mode one map done opens the next level")
	ProgressStore.clear()
	print("progression_pack_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)
