class_name RFExtras
extends RefCounted
## The pack's pieces that come from outside ART.CAR / WORLDS / SOUND: the GDScript ports of tools/extract_hud_strip.py,
## extract_win_banners.py, extract_compass_lamps.py, extract_music.py and extract_win_jingles.py (their docstrings hold
## the traced detail). Each returns "" on success or why it failed, and writes into the pack directory it is given.
##
## PORT CHOICE (issue #61, stage 3): the Python tools encode the music and the jingles' audio to Ogg Vorbis with ffmpeg;
## Godot can't encode Vorbis, so these write the same PCM compressed to QOA as AudioStreamWAV resources
## (music/track_NN.res, music/win_N.res; the engine's AudioFiles loads either). Track boundaries, durations and every
## other field of music.json / jingles.json are the same; the samples differ only by codec loss.

const HUD_STRIPS := {"1PBSCRL.RFA": "strip_1p_low", "1PBSCRH.RFA": "strip_1p_high", "NEWREQLG.RFA": "title_large", "NEWREQSM.RFA": "title_small"}
const TITLE_BAR_ROW := {"title_large": 453, "title_small": 227}   ## the picture's bottom bar ("PRESS 'F2' TO BEGIN") starts here: cut off, the port writes its own prompt
const BANNERS := {"BANBL.BMP": "win_banner_tan_low", "BANGL.BMP": "win_banner_green_low",
		"BANBH.BMP": "win_banner_tan_high", "BANGH.BMP": "win_banner_green_high"}
const LAMP_CELS := [[1969, 1970], [1971, 1972]]   ## (the lamp, the cel whose PLUT is the dim end): flag row, home row
const LAMP_STEPS := 16
const LAMP_SIZE := 16
const MUSIC_TRACKS := 24
const DRUMS_TRACKS := [28, 29]   ## cut from SOUND/Drums.WAV (the table restarts at 0 there): the title screen's Drums line
const AUDIO_EXT := "res"


static func _bmp(path: String) -> Image:
	var img := Image.new()
	if img.load_bmp_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return img


## extract_hud_strip.py: the one-player screen's bottom strip, plain BMPs, saved opaque (RGB).
static func hud_strips(art_dir: String, pack_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("hud"))
	for src in HUD_STRIPS:
		var img := _bmp(art_dir.path_join(src))
		if img == null:
			return "could not read ART/%s" % src
		img.convert(Image.FORMAT_RGB8)
		if TITLE_BAR_ROW.has(HUD_STRIPS[src]):
			img = img.get_region(Rect2i(0, 0, img.get_width(), int(TITLE_BAR_ROW[HUD_STRIPS[src]])))
		img.save_png(pack_dir.path_join("hud").path_join(HUD_STRIPS[src] + ".png"))
	return ""


## extract_win_banners.py: the four victory ribbons, pure black made transparent (a recorded PORT CHOICE there).
static func win_banners(title_dir: String, pack_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("hud"))
	for src in BANNERS:
		var img := _bmp(title_dir.path_join(src))
		if img == null:
			return "could not read TITLE/%s" % src
		img.convert(Image.FORMAT_RGBA8)
		var px := img.get_data()
		for i in range(0, px.size(), 4):
			if px[i] == 0 and px[i + 1] == 0 and px[i + 2] == 0:
				px[i + 3] = 0
		img = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, px)
		img.save_png(pack_dir.path_join("hud").path_join(BANNERS[src] + ".png"))
	return ""


## extract_compass_lamps.py: the Jeep compass lamp in 17 brightness steps (FUN_00424290's palettes), one sheet.
static func compass_lamps(car: RFCarDecoder, pack_dir: String) -> String:
	var master := car.master_palette()
	if master.is_empty():
		return "ART.CAR has no master palette where expected"
	var data := car.data
	var sheet := Image.create((LAMP_STEPS + 1) * LAMP_SIZE, LAMP_CELS.size() * LAMP_SIZE, false, Image.FORMAT_RGBA8)
	var cache := {}
	for row in LAMP_CELS.size():
		var lamp: Dictionary = car.cels[LAMP_CELS[row][0]]
		if int(lamp["w"]) != LAMP_SIZE or int(lamp["h"]) != LAMP_SIZE:
			return "compass lamp cel %d is not 16 x 16" % LAMP_CELS[row][0]
		var a_plut: int = car.cels[LAMP_CELS[row][1]]["plut"]
		var b_plut: int = lamp["plut"]
		for k in LAMP_STEPS + 1:
			var pal := []
			pal.resize(16)
			for j in range(1, 16):
				var p1: Array = master[data[a_plut + j]]
				var p2: Array = master[data[b_plut + j]]
				var rgb := []
				for ch in 3:
					rgb.append((int(p1[ch]) + ((int(p2[ch]) - int(p1[ch])) * k >> 4)) & 0xFF)
				pal[j] = _nearest(master, rgb, cache)
			for y in LAMP_SIZE:
				for x in LAMP_SIZE:
					var idx := data[int(lamp["src"]) + y * LAMP_SIZE + x]
					if idx == 0:
						continue
					var c: Array = master[pal[idx]]
					sheet.set_pixel(k * LAMP_SIZE + x, row * LAMP_SIZE + y, Color8(c[0], c[1], c[2], 255))
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("hud"))
	sheet.save_png(pack_dir.path_join("hud/compass_lamps.png"))
	return ""


## Squared RGB distance, the lowest index on a tie (as the Python tool; GDI's own tie rule is not verified).
static func _nearest(master: Array, rgb: Array, cache: Dictionary) -> int:
	var key := (int(rgb[0]) << 16) | (int(rgb[1]) << 8) | int(rgb[2])
	if cache.has(key):
		return cache[key]
	var best := 0
	var best_d := 1 << 30
	for i in master.size():
		var c: Array = master[i]
		var d := (int(c[0]) - int(rgb[0])) ** 2 + (int(c[1]) - int(rgb[1])) ** 2 + (int(c[2]) - int(rgb[2])) ** 2
		if d < best_d:
			best_d = d
			best = i
	cache[key] = best
	return best


## s16le PCM as a QOA-compressed AudioStreamWAV resource at `path`.
static func _write_audio(pcm: PackedByteArray, rate: int, path: String) -> String:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = rate
	wav.data = pcm
	var tmp := path.get_basename() + ".tmp.wav"
	if wav.save_to_wav(tmp) != OK:
		return "could not write %s" % tmp
	var qoa := AudioStreamWAV.load_from_buffer(FileAccess.get_file_as_bytes(tmp), {"compress/mode": 2})
	DirAccess.remove_absolute(tmp)
	if qoa == null or ResourceSaver.save(qoa, path) != OK:
		return "could not write %s" % path
	return ""


## extract_music.py: SOUND/Score.WAV on the CD, cut into tracks 1..24 by RFIRE.BIN's offset table 0x449470, SOUND/Drums.WAV into tracks 28 and 29,
## and the 18 music lines of 0x4463b8.
static func music(exe: RFExe, iso: RFIso9660, pack_dir: String) -> String:
	var table := []
	for i in 32:
		table.append(exe.dword(0x449470 + 4 * i))
	var lines := []
	for i in 18:
		var b := exe.off(0x4463b8 + i * 0x2c)
		var d := exe.data
		var list_ptr := d.decode_u32(b + 0x10)
		var flags := d.decode_u32(b + 0x14)
		var trans := []
		if list_ptr != 0:
			var o := exe.off(list_ptr)
			while d[o] < 0x80:
				trans.append({"from_line": d[o], "type": d[o + 1]})
				o += 8
		lines.append({"id": d[b], "name": exe.cstr(d.decode_u32(b + 4)), "lowest": d.decode_s8(b + 1), "highest": d.decode_s8(b + 2),
				"enabled_bit0": d[b + 3] & 1, "default_transition": d[b + 9], "transitions": trans, "sting": bool(flags & 2),
				"flags": flags, "start_track": -d.decode_s32(b + 0x18), "alt_track": -d.decode_s32(b + 0x1c), "end_track": -d.decode_s32(b + 0x20)})
	var wav := iso.read_file("SCORE.WAV")
	if wav.size() < 44 or wav.slice(0, 4).get_string_from_ascii() != "RIFF" or wav.slice(8, 16).get_string_from_ascii() != "WAVEfmt ":
		return "the CD image has no music file (SOUND/SCORE.WAV)"
	var drums := iso.read_file("DRUMS.WAV")
	if drums.size() < 44 or drums.slice(0, 4).get_string_from_ascii() != "RIFF" or drums.slice(8, 16).get_string_from_ascii() != "WAVEfmt ":
		return "the CD image has no title music file (SOUND/DRUMS.WAV)"
	var out_dir := pack_dir.path_join("music")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var tracks := []
	var numbers := range(1, MUSIC_TRACKS + 1)
	numbers.append_array(DRUMS_TRACKS)
	for n in numbers:
		var a: int = table[n]
		var z: int = table[n + 1]
		var src := wav if n <= MUSIC_TRACKS else drums
		var file := "track_%02d.%s" % [n, AUDIO_EXT]
		var why := _write_audio(src.slice(44 + a, 44 + z), 44100, out_dir.path_join(file))
		if why != "":
			return why
		tracks.append({"n": n, "file": file, "start_byte": a, "end_byte": z, "seconds": RFPyCompat.round_digits((z - a) / 176400.0, 2)})
	PackWriter.write_json(out_dir.path_join("music.json"), {
		"_source": "RFIRE.BIN offset table 0x449470 and music line table 0x4463b8; SOUND/Score.WAV and SOUND/Drums.WAV on the CD image; document 98",
		"tracks": tracks, "lines": lines})
	return ""


## extract_win_jingles.py: the four victory jingles (TITLE\WIN*.STM on the CD): audio and the raw Cinepak stream.
static func win_jingles(exe: RFExe, iso: RFIso9660, pack_dir: String) -> String:
	var out_dir := pack_dir.path_join("music")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var by_levl := []
	for i in 10:
		by_levl.append(exe.dword(0x44e120 + 4 * i))
	var tiers := []
	for t in 4:
		var src := exe.cstr(exe.dword(0x44e110 + 4 * t))   # e.g. "TITLE\Win1.stm"
		var stm := iso.read_file(src.get_slice("\\", src.get_slice_count("\\") - 1))
		if stm.size() < 0x1000 or stm.slice(12, 16).get_string_from_ascii() != "auds":
			return "the CD image has no victory jingle %s" % src
		if stm.decode_u16(0x98) != 1 or stm.decode_u16(0x9a) != 2 or stm.decode_u32(0x9c) != 22050 or stm.decode_u16(0xa6) != 16:
			return "%s is not 22 kHz stereo PCM" % src
		var total_frames := stm.decode_u32(0x2c)
		var pcm := PackedByteArray()
		var video := PackedByteArray()
		var frame_lengths := []
		for blk in (stm.size() - 0x1000) / 0x10000:
			var o := 0x1000 + blk * 0x10000
			var aoff := stm.decode_u32(o + 8)
			var aframes := stm.decode_u32(o + 12)
			pcm.append_array(stm.slice(o + aoff, o + aoff + aframes * 4))
			# the block's video: Cinepak chunks before its audio, found by their 320 x 240 signature
			var region := stm.slice(o + 32, o + aoff) if aoff > 32 else PackedByteArray()   # a block with no video (Python's slice is empty)
			var start := 0
			while true:
				var i := _find(region, [0x01, 0x40, 0x00, 0xF0], start)
				if i < 0:
					break
				var hstart := i - 4
				var size := (region[hstart + 1] << 16) | (region[hstart + 2] << 8) | region[hstart + 3]
				if size < 10:
					return "%s: a corrupt video chunk" % src
				video.append_array(region.slice(hstart, hstart + size))
				frame_lengths.append(size)
				start = hstart + size
		if pcm.size() != total_frames * 4:
			return "%s: audio length does not match its header" % src
		var name := "win_%d.%s" % [t, AUDIO_EXT]
		var why := _write_audio(pcm, 22050, out_dir.path_join(name))
		if why != "":
			return why
		var video_name := "win_%d.cvid" % t
		var vf := FileAccess.open(out_dir.path_join(video_name), FileAccess.WRITE)
		vf.store_buffer(video)
		vf.close()
		tiers.append({"file": name, "source": src, "seconds": RFPyCompat.round_digits(pcm.size() / 4 / 22050.0, 2),
				"video_file": video_name, "video_width": 320, "video_height": 240, "video_frame_lengths": frame_lengths})
	PackWriter.write_json(out_dir.path_join("jingles.json"), {
		"_source": "RFIRE.BIN tables 0x44e110 / 0x44e120 and the TITLE\\WIN*.STM streams on the CD image; document 101, video addendum for issue #60",
		"tiers": tiers, "tier_by_levl": by_levl})
	return ""


## bytes.find(sub, start).
static func _find(hay: PackedByteArray, sub: Array, start: int) -> int:
	var n := sub.size()
	var i := hay.find(sub[0], start)
	while i >= 0 and i + n <= hay.size():
		var ok := true
		for k in range(1, n):
			if hay[i + k] != sub[k]:
				ok = false
				break
		if ok:
			return i
		i = hay.find(sub[0], i + 1)
	return -1
