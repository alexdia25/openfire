# The golden parity check of issue #61 (decision 3): the in-game GDScript importer (importer/, RFImporter) and the
# Python pipeline (tools/import_original.py) are run on the same install and must produce the same pack. Every file the
# Python pack has must be in the GDScript one and match: JSON by value (numbers to 1e-9 relative: a float that
# lost digits on the way is a difference), images by their pixels, everything else byte for byte. The one recorded difference
# (importer/extras.gd's PORT CHOICE): music and jingle audio are QOA .res where Python wrote Ogg Vorbis, so those are
# compared by duration, and their file names in music.json / jingles.json by name without the extension.
#
# Needs the player files, so it is a dev check, not part of a plain run of the suite:
#   RF_GAME_DIR=<the Return Fire (PC) install>       the install (skipped if unset)
#   RF_PARITY_REFERENCE=<dir>                        the Python-built pack (default: res://packs/original_pc)
#   RF_PARITY_REUSE=1                                compare the last GDScript import again instead of re-importing
# Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/importer_parity_check.gd
extends SceneTree

const OUT := "user://importer_parity/original_pc"
const MAX_REPORTED := 25

var _diffs: Array[String] = []
var _compared := 0


func _diff(what: String) -> void:
	if _diffs.size() < MAX_REPORTED:
		print("DIFF  ", what)
	_diffs.append(what)


func _init() -> void:
	var install := OS.get_environment("RF_GAME_DIR")
	if install == "":
		print("importer_parity_check: SKIP (set RF_GAME_DIR to a Return Fire install to run it)")
		quit(0)
		return
	var reference := OS.get_environment("RF_PARITY_REFERENCE")
	if reference == "":
		reference = ProjectSettings.globalize_path("res://packs/original_pc")
	var out := ProjectSettings.globalize_path(OUT)

	if OS.get_environment("RF_PARITY_REUSE") != "1" or not DirAccess.dir_exists_absolute(out):
		var t0 := Time.get_ticks_msec()
		var last := [-1]
		var importer := RFImporter.new()
		var why := importer.run(install, out, func(f: float, msg: String) -> void:
			if int(f * 10) != last[0]:
				last[0] = int(f * 10)
				print("  %3d%%  %s" % [int(f * 100), msg]))
		print("import: %s in %.1f s; %s" % ["ok" if why == "" else why, (Time.get_ticks_msec() - t0) / 1000.0, importer.counts])
		for w in importer.warnings:
			print("  warning: ", w)
		if why != "":
			print("FAIL  the GDScript import failed: ", why)
			quit(1)
			return

	_compare_tree(reference, out, "")
	var extra := _files(out).filter(func(rel): return not FileAccess.file_exists(reference.path_join(_reference_name(rel))))
	for rel in extra:
		_diff("%s: only in the GDScript pack" % rel)
	print("compared %d files: %s" % [_compared, "no differences" if _diffs.is_empty() else "%d differences" % _diffs.size()])
	print("importer_parity_check: %s" % ("PASS" if _diffs.is_empty() else "FAIL"))
	quit(0 if _diffs.is_empty() else 1)


## The reference file a GDScript pack file corresponds to: a QOA .res stands for Python's .ogg.
static func _reference_name(rel: String) -> String:
	return rel.get_basename() + ".ogg" if rel.get_extension() == "res" else rel


static func _files(root: String, rel := "") -> Array:
	var out := []
	var d := DirAccess.open(root.path_join(rel))
	if d == null:
		return out
	for f in d.get_files():
		out.append(rel.path_join(f) if rel != "" else f)
	for sub in d.get_directories():
		out.append_array(_files(root, rel.path_join(sub) if rel != "" else sub))
	return out


func _compare_tree(ref_root: String, out_root: String, _rel: String) -> void:
	for rel in _files(ref_root):
		var ref_path := ref_root.path_join(rel)
		var out_rel: String = rel.get_basename() + ".res" if rel.get_extension() == "ogg" else rel
		var out_path := out_root.path_join(out_rel)
		if not FileAccess.file_exists(out_path):
			_diff("%s: missing from the GDScript pack" % out_rel)
			continue
		_compared += 1
		match rel.get_extension():
			"json":
				var a: Variant = JSON.parse_string(FileAccess.get_file_as_string(ref_path))
				var b: Variant = JSON.parse_string(FileAccess.get_file_as_string(out_path))
				_compare_value(_normalise_audio_names(a), _normalise_audio_names(b), rel)
			"png":
				_compare_png(ref_path, out_path, rel)
			"ogg":
				var a := AudioFiles.load_stream(ref_path)
				var b := AudioFiles.load_stream(out_path)
				if a == null or b == null:
					_diff("%s: does not load (%s / %s)" % [rel, a, b])
				elif absf(a.get_length() - b.get_length()) > 0.05:
					_diff("%s: %.3f s vs %.3f s" % [rel, a.get_length(), b.get_length()])
			_:
				if FileAccess.get_md5(ref_path) != FileAccess.get_md5(out_path):
					_diff("%s: bytes differ" % rel)


## music.json / jingles.json name their audio files: compared without the extension (ogg vs res).
static func _normalise_audio_names(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			var x: Variant = v[k]
			if k == "file" and x is String and (String(x).ends_with(".ogg") or String(x).ends_with(".res")):
				x = String(x).get_basename()
			out[k] = _normalise_audio_names(x)
		return out
	if v is Array:
		return (v as Array).map(func(x): return _normalise_audio_names(x))
	return v


func _compare_value(a: Variant, b: Variant, where: String) -> void:
	if (a is float or a is int) and (b is float or b is int):
		if absf(float(a) - float(b)) > 1e-9 * maxf(1.0, absf(float(a))):
			_diff("%s: %s vs %s" % [where, a, b])
		return
	if typeof(a) != typeof(b):
		_diff("%s: %s vs %s" % [where, type_string(typeof(a)), type_string(typeof(b))])
		return
	if a is Dictionary:
		for k in a:
			if not b.has(k):
				_diff("%s.%s: missing" % [where, k])
			else:
				_compare_value(a[k], b[k], "%s.%s" % [where, k])
		for k in b:
			if not a.has(k):
				_diff("%s.%s: extra" % [where, k])
	elif a is Array:
		if a.size() != b.size():
			_diff("%s: %d items vs %d" % [where, a.size(), b.size()])
			return
		for i in a.size():
			_compare_value(a[i], b[i], "%s[%d]" % [where, i])
	elif a != b:
		_diff("%s: %s vs %s" % [where, str(a).left(80), str(b).left(80)])


func _compare_png(ref_path: String, out_path: String, rel: String) -> void:
	var a := Image.load_from_file(ref_path)
	var b := Image.load_from_file(out_path)
	if a == null or b == null:
		_diff("%s: does not load" % rel)
		return
	if a.get_size() != b.get_size():
		_diff("%s: %s vs %s" % [rel, a.get_size(), b.get_size()])
		return
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	if a.get_data() != b.get_data():
		var pa := a.get_data()
		var pb := b.get_data()
		var n := 0
		for i in range(0, pa.size(), 4):
			if pa[i] != pb[i] or pa[i + 1] != pb[i + 1] or pa[i + 2] != pb[i + 2] or pa[i + 3] != pb[i + 3]:
				n += 1
		_diff("%s: %d of %d pixels differ" % [rel, n, pa.size() / 4])
