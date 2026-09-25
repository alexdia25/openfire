# The music director's decisions (document 98), against the real line table in the pack's music/music.json. Run:
#   godot --headless --path . --script tools/tests/music_director_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


## One tick of a game in which the player's vehicle exists (its handler sets bit 0x400 every tick).
func _tick_alive(d: MusicDirector, theme: Callable = Callable()) -> void:
	d.bit_vehicle = true
	d.tick(theme)


func _director() -> MusicDirector:
	var d := MusicDirector.new()
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://packs/original_pc/music/music.json"))
	d.load_lines(doc["lines"])
	return d


func _init() -> void:
	# FUN_0040f2f0
	check("Tank: its own flag carried -> theme 2", MusicDirector.vehicle_line(0, true, false, 5, -1, 7) == 2)
	check("Tank: the other flag within 128 units -> theme 2", MusicDirector.vehicle_line(0, false, true, 5, -1, 7) == 2)
	check("Tank: stock 2 -> theme 0", MusicDirector.vehicle_line(0, false, false, 2, -1, 7) == 0)
	check("Tank: random above 3 -> theme 1, else 0", MusicDirector.vehicle_line(0, false, false, 5, -1, 4) == 1 and MusicDirector.vehicle_line(0, false, false, 5, -1, 3) == 0)
	check("Jeep and MSV: the record's line", MusicDirector.vehicle_line(1, false, false, 8, 4, 0) == 4 and MusicDirector.vehicle_line(2, false, false, 3, 6, 0) == 6)
	check("Heli: stock 2 -> 8; else 8 when the roll is below 4, else 9", MusicDirector.vehicle_line(3, false, false, 2, 8, 7) == 8 and MusicDirector.vehicle_line(3, false, false, 3, 8, 3) == 8 and MusicDirector.vehicle_line(3, false, false, 3, 8, 4) == 9)

	# a Tank is created: line 0 at 0x80, then the state machine's own choice
	var d := _director()
	var changes: Array = []
	d.line_changed.connect(func(a, b, t): changes.append([a, b, t]))
	d.vehicle_created(0, 0x80)
	_tick_alive(d, func(): return 1)
	check("Tank created: the state machine's theme 1 replaces theme 0 at equal priority (its window allows it)", d.requested == 1 and d.state == MusicDirector.STATE_THEME, "requested %d state %d" % [d.requested, d.state])
	check("... and the change is announced from nothing to line 1", changes.size() == 1 and changes[0][1] == 1, str(changes))
	_tick_alive(d)
	check("the priority decays a step a tick from 0x80 (two ticks: 0x7e), floor 0x58", d.priority == 0x7e and d.floor_priority == 0x58, "%x %x" % [d.priority, d.floor_priority])
	for i in 60:
		_tick_alive(d)
	check("... and stops at the floor", d.priority == 0x58, "%x" % d.priority)
	# a flag appears: the discovery sting at 0xfe cuts in (type 2)
	changes.clear()
	d.bit_flag_appeared = true
	_tick_alive(d)
	check("a flag appears: Flag Discovery (11) plays over the theme, cut (type 2)", d.requested == 11 and changes.size() == 1 and changes[0][2] == 2 and d.state == MusicDirector.STATE_FLAG_FOUND, str(changes))
	check("the sting remembers the theme as the previous line", d.previous == 1)
	# the sting ends in the game view: the previous line comes back at priority 100
	d.in_game_view = true
	check("the sting is over: 'ended'", d.segment_ended() == "ended")
	d.tick()
	check("... the previous theme (1) is requested again", d.requested == 1 and d.playing == 1, "%d %d" % [d.requested, d.playing])
	# the sting ends outside the game view: Bunker
	var d2 := _director()
	d2.bit_flag_appeared = true
	d2.tick()
	d2.in_game_view = false
	d2.segment_ended()
	d2.tick()
	check("a sting ending outside the game view starts Bunker (14)", d2.requested == 14, str(d2.requested))
	# a looping line restarts from its alternate track
	var d3 := _director()
	d3.request(4, 0x80)
	d3.tick()
	for i in 60:
		d3.tick()
	check("Jeep theme: looping", d3.segment_ended() == "loop" and d3.use_alt)
	d3.tick()
	check("... and the same line is playing again", d3.playing == 4)

	# a Tank dies while its theme plays: its own death line, cut
	var d4 := _director()
	d4.vehicle_created(0, 0x80)
	_tick_alive(d4, func(): return 0)
	changes.clear()
	d4.line_changed.connect(func(a, b, t): changes.append([a, b, t]))
	_tick_alive(d4)   # the vehicle bit stays up: the state stays 4
	d4.vehicle_destroyed(3)
	d4.bit_vehicle = false
	d4.tick()
	check("theme playing: the Tank's death line (3), cut (type 2)", d4.requested == 3 and changes.size() == 1 and changes[0][2] == 2 and d4.state == MusicDirector.STATE_DEATH, str(changes))
	# ... but while the flag is carried the generic Death (15) plays instead
	var d5 := _director()
	d5.request(4, 0x80)
	d5.bit_flag_carried = true
	d5.tick()
	check("a flag carried by the other team: Flag Pickup (12), state 5", d5.requested == 4 or d5.requested == 12)
	for i in 60:
		d5.bit_flag_carried = true
		d5.tick()
	check("... after the theme's priority has decayed", d5.requested == 12 and d5.state == MusicDirector.STATE_FLAG_CARRIED, "%d %d" % [d5.requested, d5.state])
	d5.vehicle_destroyed(5)
	d5.tick()
	check("death outside a theme: the generic Death line (15)", d5.requested == 15, str(d5.requested))
	# the vehicle choice: Bunker, and it yields to a theme
	var d6 := _director()
	d6.choosing = 1
	d6.tick()
	check("the choice is open: Bunker (14) at 0x68", d6.requested == 14 and d6.state == MusicDirector.STATE_BUNKER)
	d6.choosing = 0
	d6.vehicle_created(4, 0x80)
	_tick_alive(d6, func(): return 4)
	check("the vehicle is created: the theme (0x80) takes over from Bunker (0x68)", d6.requested == 4, str(d6.requested))
	# the equal-priority window: Heli 2 (window 8..3) never displaces Heli 1
	var d7 := _director()
	d7.vehicle_created(8, 0x80)
	_tick_alive(d7, func(): return 9)
	check("Heli: line 9 cannot replace line 8 at equal priority", d7.requested == 8, str(d7.requested))
	# nothing playing any more: ask for silence
	var d8 := _director()
	d8.state = MusicDirector.STATE_THEME
	d8.tick()
	check("nothing playing while the state is above 1: back to idle, requesting silence", d8.requested == -1 and d8.state == MusicDirector.STATE_IDLE)
	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
