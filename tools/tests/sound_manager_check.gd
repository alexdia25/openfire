# Headless sanity check for game/sound_manager.gd (document 82): loads the pack's audio.json,
# connects a Vehicle, and confirms the two applied cues (OutAmmo, Heli) resolve to real
# AudioStreamWAV data without touching a live 3D scene or GPU screenshot. Run:
#   godot --headless --path . --script tools/tests/sound_manager_check.gd
extends SceneTree

func _init() -> void:
	var pack := Pack.new()
	assert(pack.load_from("res://packs/original_pc"))
	var root := Node.new()
	get_root().add_child(root)

	var sound := SoundManager.new()
	root.add_child(sound)
	sound.setup(pack)

	var v := Vehicle.new()
	root.add_child(v)
	sound.connect_vehicle(v)

	for cue_id in ["OutAmmo", "Heli"]:
		var entry := pack.get_sound(cue_id)
		print("%s -> %s" % [cue_id, entry])
		var stream := sound._stream_for(cue_id)
		print("  stream ok: %s (%s frames)" % [stream != null, stream.get_length() if stream != null else -1])

	print("missing cue -> %s" % [sound._stream_for("NoSuchCue")])
	await process_frame   # nodes must be inside the live tree before AudioStreamPlayer.play() works
	v.sound_cue.emit("OutAmmo")   # exercises the connected signal path end to end
	print("playing after emit: %s" % [sound._players.any(func(p): return p.playing)])
	print("done")
	quit()
