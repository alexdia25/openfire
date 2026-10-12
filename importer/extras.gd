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

const HUD_STRIPS := {"1PBSCRL.RFA": "strip_1p_low", "1PBSCRH.RFA": "strip_1p_high", "2PBSCRL.RFA": "strip_2p_low", "2PBSCRH.RFA": "strip_2p_high",
		"NEWREQLG.RFA": "title_large", "NEWREQSM.RFA": "title_small"}
## The two-player screen's divider (document 139): FUN_004313c0 loads ARTpMScr.rfa (24 x 299) in a two-player game and blits one rectangle of
## it at (0x9c, 0), low resolution, or (0x138, 0), high: x 16-24 / rows 0-150, or x 0-16 / all 299 rows. name -> [x, y, w, h].
const DIVIDER_2P := {"divider_2p_low": [16, 0, 8, 150], "divider_2p_high": [0, 0, 16, 299]}
const TITLE_BAR_TEXT_ROWS := {"title_large": [456, 475], "title_small": [229, 237]}   ## the picture's bottom bar ("PRESS 'F2' TO BEGIN"): the text is painted out, the port writes its own
const BANNERS := {"BANBL.BMP": "win_banner_tan_low", "BANGL.BMP": "win_banner_green_low",
		"BANBH.BMP": "win_banner_tan_high", "BANGH.BMP": "win_banner_green_high"}
const LAMP_CELS := [[1969, 1970], [1971, 1972]]   ## (the lamp, the cel whose PLUT is the dim end): flag row, home row
const LAMP_STEPS := 16
const LAMP_SIZE := 16
const MUSIC_TRACKS := 24
const DRUMS_TRACKS := [28, 29]   ## cut from SOUND/Drums.WAV (the table restarts at 0 there): the title screen's Drums line
const AUDIO_EXT := "res"


static func _bmp(src: RFSource, rel: String) -> Image:
	var img := Image.new()
	if img.load_bmp_from_buffer(src.read_file(rel)) != OK:
		return null
	return img


## extract_hud_strip.py: the one-player screen's bottom strip, plain BMPs, saved opaque (RGB).
static func hud_strips(src: RFSource, pack_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("hud"))
	for file in HUD_STRIPS:
		var img := _bmp(src, "ART/" + file)
		if img == null:
			return "could not read ART/%s" % file
		img.convert(Image.FORMAT_RGB8)
		if TITLE_BAR_TEXT_ROWS.has(HUD_STRIPS[file]):
			var rows: Array = TITLE_BAR_TEXT_ROWS[HUD_STRIPS[file]]
			for y in range(int(rows[0]), int(rows[1]) + 1):
				var c := img.get_pixel(2, y)
				for x in img.get_width():
					img.set_pixel(x, y, c)
		img.save_png(pack_dir.path_join("hud").path_join(HUD_STRIPS[file] + ".png"))
	var div := _bmp(src, "ART/2PMSCR.RFA")
	if div == null:
		return "could not read ART/2PMSCR.RFA"
	div.convert(Image.FORMAT_RGB8)
	for name in DIVIDER_2P:
		var r: Array = DIVIDER_2P[name]
		div.get_region(Rect2i(r[0], r[1], r[2], r[3])).save_png(pack_dir.path_join("hud").path_join(name + ".png"))
	return ""


## The list marks' [picture, mask] bitmap resource ids: the install's build, then the CD's (same bytes, renumbered; issue #122).
const LIST_MARK_IDS := [[0x7DA, 0x7D9], [0x418, 0x419]]


## extract_list_marks.py: the Level Selector's three list marks (document 128, issue #102): RFIRE.BIN's bitmap resources 0x7da (the picture, 4 bits a pixel) and 0x7d9 (the mask, 1 bit,
## a set bit is transparent) as one 48 x 16 RGBA strip, written to ui/list_marks.png. "" when the build has none (the engine then draws its own).
static func list_marks(exe: RFExe, pack_dir: String) -> String:
	var picture := {}
	var mask := {}
	for ids in LIST_MARK_IDS:
		picture = _dib(exe.resource(2, ids[0]))
		mask = _dib(exe.resource(2, ids[1]))
		if not picture.is_empty() and not mask.is_empty() and picture["width"] == mask["width"] and picture["height"] == mask["height"]:
			break
		picture = {}
	if picture.is_empty():
		return "this RFIRE.BIN has no bitmap resources 0x7da / 0x7d9 (the install's) or 0x418 / 0x419 (the CD's)"
	var w: int = picture["width"]
	var h: int = picture["height"]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c: Color = picture["pixels"][y * w + x]
			var transparent: bool = mask["pixels"][y * w + x] == Color.WHITE
			img.set_pixel(x, y, Color(0, 0, 0, 0) if transparent else c)
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("ui"))
	img.save_png(pack_dir.path_join("ui").path_join("list_marks.png"))
	return ""


## A device-independent bitmap as stored in a resource: {"width", "height", "pixels"} (top row first, Colors), or {} if it is not a 1, 4 or 8 bit one.
static func _dib(data: PackedByteArray) -> Dictionary:
	if data.size() < 40:
		return {}
	var hs := data.decode_u32(0)
	var w := data.decode_s32(4)
	var h := data.decode_s32(8)
	var bpp := data.decode_u16(14)
	if not bpp in [1, 4, 8]:
		return {}
	var ncol := data.decode_u32(32)
	if ncol == 0:
		ncol = 1 << bpp
	var pal: Array[Color] = []
	for i in ncol:
		pal.append(Color8(data[hs + i * 4 + 2], data[hs + i * 4 + 1], data[hs + i * 4]))
	var stride := ((w * bpp + 31) / 32) * 4
	var base := hs + ncol * 4
	var pixels: Array[Color] = []
	for y in range(h - 1, -1, -1):   # bottom-up
		for x in w:
			var row := base + y * stride
			var v := 0
			if bpp == 4:
				v = (data[row + x / 2] >> (4 if x % 2 == 0 else 0)) & 15
			elif bpp == 1:
				v = (data[row + x / 8] >> (7 - x % 8)) & 1
			else:
				v = data[row + x]
			pixels.append(pal[v])
	return {"width": w, "height": h, "pixels": pixels}


## extract_level_previews.py: each level's 256 x 256 preview, drawn as the original's Level Selector does (document 125): the .RFM's 128 x 128 tile bytes, each the 2 x 2 pixel
## pattern ART/2X2.RFA holds for that byte (20 x 12 patterns, its own palette). `rfm_files`: every .RFM of WORLDS; written to levels/<NAME>/preview.png when that level exists.
static func level_previews(src: RFSource, rfm_files: Array[String], pack_dir: String) -> String:
	var pat := _bmp(src, "ART/2X2.RFA")
	if pat == null:
		return "could not read ART/2X2.RFA"
	pat.convert(Image.FORMAT_RGB8)
	for f in rfm_files:
		var data := src.read_file(f)
		if data.size() < 0x4C:
			continue
		var off := data.decode_u32(0x48)
		if off + 128 * 128 > data.size():
			continue
		var stem := f.get_file().get_basename()
		var out_dir := pack_dir.path_join("levels").path_join(stem)
		if not DirAccess.dir_exists_absolute(out_dir):
			continue
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var b := data[off + y * 128 + x]
				var bx := (b % 20) * 2
				var by := (b / 20) * 2
				for dy in 2:
					for dx in 2:
						img.set_pixel(x * 2 + dx, y * 2 + dy, pat.get_pixel(bx + dx, by + dy))
		img.save_png(out_dir.path_join("preview.png"))
	return ""


## extract_win_banners.py: the four victory ribbons, pure black made transparent (a recorded PORT CHOICE there).
static func win_banners(src: RFSource, pack_dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(pack_dir.path_join("hud"))
	for file in BANNERS:
		var img := _bmp(src, "TITLE/" + file)
		if img == null:
			return "could not read TITLE/%s" % file
		img.convert(Image.FORMAT_RGBA8)
		var px := img.get_data()
		for i in range(0, px.size(), 4):
			if px[i] == 0 and px[i + 1] == 0 and px[i + 2] == 0:
				px[i + 3] = 0
		img = Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, px)
		img.save_png(pack_dir.path_join("hud").path_join(BANNERS[file] + ".png"))
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
static func music(exe: RFExe, cd: RFSource, pack_dir: String) -> String:
	var at := exe.tables()
	var table := []
	for i in 32:
		table.append(exe.dword(int(at["music_offsets"]) + 4 * i))
	var lines := []
	for i in 18:
		var b := exe.off(int(at["music_lines"]) + i * 0x2c)
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
	var wav := cd.read_file("SOUND/SCORE.WAV")
	if wav.size() < 44 or wav.slice(0, 4).get_string_from_ascii() != "RIFF" or wav.slice(8, 16).get_string_from_ascii() != "WAVEfmt ":
		return "the CD has no music file (SOUND/SCORE.WAV)"
	var drums := cd.read_file("SOUND/DRUMS.WAV")
	if drums.size() < 44 or drums.slice(0, 4).get_string_from_ascii() != "RIFF" or drums.slice(8, 16).get_string_from_ascii() != "WAVEfmt ":
		return "the CD has no title music file (SOUND/DRUMS.WAV)"
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
static func win_jingles(exe: RFExe, cd: RFSource, pack_dir: String) -> String:
	var at := exe.tables()
	var out_dir := pack_dir.path_join("music")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var by_levl := []
	for i in 10:
		by_levl.append(exe.dword(int(at["jingle_by_level"]) + 4 * i))
	var tiers := []
	for t in 4:
		var src := exe.cstr(exe.dword(int(at["jingle_files"]) + 4 * t))   # e.g. "TITLE\Win1.stm"
		var stm := cd.read_file(src)
		if stm.size() < 0x1000 or stm.slice(12, 16).get_string_from_ascii() != "auds":
			return "the CD has no victory jingle %s" % src
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
