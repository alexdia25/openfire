# The real-time Cinepak decoder (issue #60, document 101's addendum): decodes the win jingle's real
# extracted video (tools/extract_win_jingles.py's win_<tier>.cvid) frame by frame and checks specific pixel
# samples against a Python reference implementation of the same algorithm, itself verified pixel-for-pixel
# (zero error, all 1865 real frames across all four tiers) against ffmpeg's own mature Cinepak decoder.
# Run: godot --headless --path . --script tools/tests/cinepak_decoder_check.gd
extends SceneTree

var fails := 0


func check(name: String, ok: bool, detail: String = "") -> void:
	print(("ok   " if ok else "FAIL ") + name + ("  " + detail if detail != "" else ""))
	if not ok:
		fails += 1


func _init() -> void:
	var path := "res://packs/original_pc/music"
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path + "/jingles.json"))
	var tier: Dictionary = doc["tiers"][0]
	check("win_0's frame index exists and has real chunks", tier.has("video_frame_lengths") and tier["video_frame_lengths"].size() == 160,
		str(tier.get("video_frame_lengths", []).size()))
	var lengths: Array = tier["video_frame_lengths"]
	var cvid := FileAccess.get_file_as_bytes(path + "/" + String(tier["video_file"]))
	var offs: Array[int] = [0]
	for l in lengths:
		offs.append(offs[-1] + int(l))

	var w := 320
	var h := 240
	var pixels := PackedByteArray()
	pixels.resize(w * h * 3)
	var dec := CinepakDecoder.new()

	# {frame index (0-based, decode order) : [(x, y, [r,g,b]), ...]}, from the validated Python reference
	var expect := {
		0: [[0, 0, [0, 0, 0]], [100, 50, [0, 0, 0]]],
		79: [[0, 0, [157, 157, 157]], [100, 50, [75, 75, 75]], [200, 150, [158, 158, 158]], [319, 239, [40, 40, 40]]],
		80: [[0, 0, [169, 169, 169]], [100, 50, [73, 73, 73]], [200, 150, [186, 186, 186]], [319, 239, [34, 34, 34]]],
		159: [[0, 0, [158, 158, 158]], [100, 50, [75, 75, 75]], [200, 150, [183, 183, 183]], [319, 239, [59, 59, 59]]],
	}
	for i in lengths.size():
		var raw := cvid.slice(offs[i], offs[i + 1])
		dec.decode_frame(raw, pixels, w, h)
		if expect.has(i):
			var ok := true
			var detail := ""
			for sample in expect[i]:
				var x: int = sample[0]
				var y: int = sample[1]
				var want: Array = sample[2]
				var o := (y * w + x) * 3
				var got := [pixels[o], pixels[o + 1], pixels[o + 2]]
				if got != want:
					ok = false
					detail += " (%d,%d) got %s want %s" % [x, y, got, want]
			check("frame %d matches the reference decoder at its sample points" % i, ok, detail)

	print("failures: ", fails)
	quit(1 if fails > 0 else 0)
