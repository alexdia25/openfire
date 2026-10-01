class_name RFImporter
extends RefCounted
## "Open Fire" mode's importer (issue #61): turns the player's own Return Fire (PC) install into the game's base pack,
## inside the game, with nothing else installed. The GDScript port of tools/import_original.py and the scripts it runs;
## the Python pipeline is the reference it is checked against (tools/tests/importer_parity_check.gd) until parity holds,
## after which this is the canonical one (issue #61, "Correction to decision 3").
##
##   var why := RFImporter.new().run(install_dir, "user://packs/original_pc", progress)   # "" = success
##
## Blocking, and safe to run on a worker thread: it touches no scene tree. `progress.call(fraction, message)` is
## called on the thread that runs it, so a UI should forward it with call_deferred. The pack is assembled in
## "<out_dir>.partial" and swapped into place only when every step has succeeded: a failed or interrupted import never
## leaves a half-built pack where the game looks for one, and never touches a good pack that is already there.
##
## Validation is deliberately loose (issue #61, decision 2): the expected files exist and are roughly the right size.
## It is all in validate_install(), so tightening it later (hashes of known releases) touches nothing else.

## path under the install -> minimum plausible size in bytes
const REQUIRED_FILES := {"RFIRE.BIN": 300000, "ART/ART.CAR": 1000000}
## directory under the install, extension, minimum count (recursive)
const REQUIRED_SETS := [["SOUND", "SDT", 30], ["WORLDS", "RFM", 100], ["TITLE", "BMP", 4]]
const MUSIC_MIN_BYTES := 1000000   ## the install's own SOUND/SCORE.WAV is a 20-byte stub; the CD's is the real music

var warnings: Array[String] = []
var counts := {}
var _progress := Callable()
var _step_base := 0.0
var _step_span := 0.0


## Why `dir` is not a usable PC install ("" if it is), worded for the player.
static func validate_install(dir: String) -> String:
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		return "%s is not a folder." % dir
	if find_ci(dir, "RFIRE.BIN") == "":
		for f in _list(dir, true):
			if f.get_extension().to_lower() == "cue":
				return "This looks like the 3DO version of Return Fire (a disc image). Only the PC (Windows 95) release is supported for now: choose the folder it was installed to."
	for rel in REQUIRED_FILES:
		var path := find_ci(dir, rel)
		if path == "":
			return "%s is missing. Is this the folder Return Fire (PC) was installed to?" % rel
		var size := FileAccess.open(path, FileAccess.READ).get_length()
		if size < REQUIRED_FILES[rel]:
			return "%s is smaller than expected (%d bytes); the install may be damaged." % [rel, size]
	for s in REQUIRED_SETS:
		var sub := find_ci(dir, s[0])
		var n := 0
		if sub != "":
			for f in _list(sub, true):
				if f.get_extension().to_upper() == s[1]:
					n += 1
		if n < s[2]:
			return "Expected at least %d %s files under %s, found %d; the install may be incomplete." % [s[2], s[1], s[0], n]
	return ""


## `rel` ("ART/ART.CAR") under `dir`, matching each part without regard to case (an install copied onto a
## case-sensitive file system keeps whatever case it had); "" if absent.
static func find_ci(dir: String, rel: String) -> String:
	var at := dir
	for part in rel.split("/"):
		var d := DirAccess.open(at)
		if d == null:
			return ""
		var found := ""
		for name in Array(d.get_files()) + Array(d.get_directories()):
			if String(name).to_upper() == part.to_upper():
				found = name
				break
		if found == "":
			return ""
		at = at.path_join(found)
	return at


## Every file under `dir` (recursively if asked), as full paths, sorted.
static func _list(dir: String, recursive: bool) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	if recursive:
		for sub in d.get_directories():
			out.append_array(_list(dir.path_join(sub), true))
	out.sort()
	return out


## Where the music and jingles come from: an .iso of the game CD (in the install folder, or `cd` if given), or a
## folder (a mounted CD, or `cd`) holding the real SOUND/SCORE.WAV. Returns {"iso": RFIso9660} or {"dir": path}, or {}.
static func find_cd(install: String, cd := "") -> Dictionary:
	var candidates: Array[String] = []
	if cd != "":
		candidates.append(cd)
	for f in _list(install, false):
		if f.get_extension().to_lower() != "iso":
			continue
		if f.get_file().to_upper() == "RFIRE US.ISO" and cd == "":
			candidates.push_front(f)
		else:
			candidates.append(f)
	candidates.append(install)
	for c in candidates:
		if c.get_extension().to_lower() == "iso" and FileAccess.file_exists(c):
			var iso := RFIso9660.open(c)
			if iso != null and iso.has_file("SCORE.WAV"):
				return {"iso": iso}
		elif DirAccess.dir_exists_absolute(c):
			var score := find_ci(c, "SOUND/SCORE.WAV")
			if score != "" and FileAccess.open(score, FileAccess.READ).get_length() > MUSIC_MIN_BYTES:
				return {"dir": c}
	return {}


func _step(base: float, span: float, message: String) -> void:
	_step_base = base
	_step_span = span
	_report(0.0, message)


func _report(fraction: float, message: String) -> void:
	if _progress.is_valid():
		_progress.call(clampf(_step_base + _step_span * fraction, 0.0, 1.0), message)


## Imports `install` into `out_dir`. "" on success, else what went wrong (nothing is left at `out_dir` that wasn't
## there before). `cd`: an .iso or a mounted-CD folder for the music, if it isn't in the install folder.
func run(install: String, out_dir: String, progress := Callable(), cd := "") -> String:
	_progress = progress
	warnings.clear()
	_step(0.0, 0.01, "Checking the install")
	var why := validate_install(install)
	if why != "":
		return why
	var partial := out_dir + ".partial"
	remove_tree(partial)
	DirAccess.make_dir_recursive_absolute(partial)
	why = _build(install, partial, cd)
	if why == "":
		why = _swap_into_place(partial, out_dir)
	if why != "":
		remove_tree(partial)
		return why
	_step(1.0, 0.0, "Done")
	return ""


func _build(install: String, out: String, cd: String) -> String:
	var car := RFCarDecoder.new()
	var why := car.load(FileAccess.get_file_as_bytes(find_ci(install, "ART/ART.CAR")))
	if why != "":
		return why
	var builder := RFPackBuilder.new()
	builder.out_dir = out
	builder.car = car
	counts = builder.counts

	_step(0.01, 0.45, "Converting the sprites")
	why = builder.sprites_and_tiles(_report)
	if why != "":
		return why

	_step(0.46, 0.08, "Converting the levels")
	var tables: Variant = RFPackBuilder.data("tile_lookup_tables.json")
	if not (tables is Dictionary):
		return "the importer's tile tables are missing (tools/data/tile_lookup_tables.json)"
	var rfm := RFRfmDecoder.new(tables)
	var worlds := find_ci(install, "WORLDS")
	var files := _list(worlds, true).filter(func(f): return f.get_extension().to_upper() == "RFM")
	var decoded := {}
	for i in files.size():
		var f: String = files[i]
		var r := rfm.decode(FileAccess.get_file_as_bytes(f), f.get_file(), f.trim_prefix(worlds + "/"))
		if r.has("error"):
			warnings.append("%s: %s (skipped)" % [f.get_file(), r["error"]])
			continue
		decoded[f.get_file().get_basename()] = r   # a later file of the same name wins, as in the Python pipeline
		if i % 20 == 0:
			_report(float(i) / files.size(), "Converting the levels: %d of %d" % [i, files.size()])
	if decoded.is_empty():
		return "none of the levels could be read"

	_step(0.54, 0.02, "Converting the sound effects")
	var sound := {}
	for f in _list(find_ci(install, "SOUND"), false):
		if f.get_extension().to_upper() != "SDT":
			continue
		var bytes := FileAccess.get_file_as_bytes(f)
		var problem := sdt_problem(bytes)
		if problem != "":
			warnings.append("%s: %s (skipped)" % [f.get_file(), problem])
			continue
		sound[(f.get_file().get_basename() + ".wav").to_upper()] = bytes

	_step(0.56, 0.04, "Assembling the pack")
	builder.decorations()
	builder.manifest()
	why = builder.vehicles(sound)
	if why != "":
		return why
	builder.small_tables()
	builder.home_pad()
	builder.hud()
	builder.world_tables(sound)
	builder.levels(decoded)

	_step(0.60, 0.04, "Matching the team colours")
	builder.team_colours()

	_step(0.64, 0.02, "Extracting the HUD and victory art")
	for result in [RFExtras.hud_strips(find_ci(install, "ART"), out), RFExtras.win_banners(find_ci(install, "TITLE"), out),
			RFExtras.compass_lamps(car, out)]:
		if result != "":
			return result

	var source := find_cd(install, cd)
	if source.is_empty():
		warnings.append("No game CD image (RFIRE US.iso) or mounted CD was found, so the game has no music. Import again with one to add it.")
	else:
		var exe := RFExe.open(find_ci(install, "RFIRE.BIN"))
		if exe == null:
			return "RFIRE.BIN is not a Windows executable"
		var iso: RFIso9660 = source.get("iso")
		if iso == null:
			iso = _FolderCd.new(source["dir"])
		_step(0.66, 0.24, "Extracting the music")
		why = RFExtras.music(exe, iso, out)
		if why != "":
			return why
		_step(0.90, 0.06, "Extracting the victory jingles")
		why = RFExtras.win_jingles(exe, iso, out)
		if why != "":
			return why

	_step(0.96, 0.04, "Checking the pack")
	return validate_pack(out)


## convert_sdt.py's check: a .SDT must be a plain PCM RIFF/WAVE (copied as-is).
static func sdt_problem(data: PackedByteArray) -> String:
	if data.size() < 12 or data.slice(0, 4).get_string_from_ascii() != "RIFF" or data.slice(8, 12).get_string_from_ascii() != "WAVE":
		return "not a RIFF/WAVE file"
	var pos := 12
	var fmt := -1
	var has_data := false
	while pos + 8 <= data.size():
		var tag := data.slice(pos, pos + 4).get_string_from_ascii()
		var size := data.decode_u32(pos + 4)
		if tag == "fmt ":
			fmt = data.decode_u16(pos + 8)
		elif tag == "data":
			has_data = true
		pos += 8 + size + (size & 1)
	if fmt < 0:
		return "no 'fmt ' chunk"
	if fmt != 1:
		return "format tag 0x%04X is not PCM" % fmt
	if not has_data:
		return "no 'data' chunk"
	return ""


## validate_pack.py's checks, on the pack just built.
static func validate_pack(dir: String) -> String:
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("pack.json")))
	if not (manifest is Dictionary):
		return "the pack has no pack.json"
	for f in ModValidator.REQUIRED_PACK_FIELDS:
		if not manifest.has(f):
			return "pack.json has no \"%s\"" % f
	var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("sprites/sprites.json")))
	if not (doc is Dictionary):
		return "the pack has no sprites/sprites.json"
	var sprites: Dictionary = doc["sprites"]
	for id in sprites:
		var e: Dictionary = sprites[id]
		if not FileAccess.file_exists(dir.path_join("sprites").path_join(e["file"])):
			return "sprite %s: frame %s is missing" % [id, e["file"]]
	var reg: Variant = JSON.parse_string(FileAccess.get_file_as_string(RFPackBuilder.REGISTRY))
	var known := {}
	for c in reg["cels"].values():
		known[c["id"]] = true
	for id in sprites:
		if not known.has(id):
			return "sprite %s is not in the asset registry" % id
	var tiles: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("terrain/tileset.json")))
	for art_id in tiles["tiles"]:
		if not sprites.has(tiles["tiles"][art_id]["sprite_id"]):
			return "tileset art id %s names a missing sprite" % art_id
	if not DirAccess.dir_exists_absolute(dir.path_join("levels")):
		return "the pack has no levels"
	return ""


## Moves the finished pack over any older one: the old one is set aside first and removed only once the new one is
## in place, so a failure here still leaves one complete pack.
static func _swap_into_place(partial: String, out_dir: String) -> String:
	var old := out_dir + ".old"
	remove_tree(old)
	if DirAccess.dir_exists_absolute(out_dir) and DirAccess.rename_absolute(out_dir, old) != OK:
		return "could not replace the existing pack at %s" % out_dir
	if DirAccess.rename_absolute(partial, out_dir) != OK:
		if DirAccess.dir_exists_absolute(old):
			DirAccess.rename_absolute(old, out_dir)
		return "could not move the new pack into %s" % out_dir
	remove_tree(old)
	return ""


## Deletes `dir` and everything under it (no-op if it doesn't exist). Follows no links: a directory link is removed,
## not entered.
static func remove_tree(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.include_hidden = true
	for f in d.get_files():
		DirAccess.remove_absolute(dir.path_join(f))
	for sub in d.get_directories():
		if d.is_link(sub):
			DirAccess.remove_absolute(dir.path_join(sub))
		else:
			remove_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)


## A mounted CD (or a copy of it) read through the same calls as an RFIso9660: files found by name, any directory.
class _FolderCd extends RFIso9660:
	var _by_name := {}

	func _init(root: String) -> void:
		for f in RFImporter._list(root, true):
			var key := f.get_file().to_upper()
			if not _by_name.has(key):
				_by_name[key] = f

	func has_file(name: String) -> bool:
		return _by_name.has(name.to_upper())

	func read_file(name: String) -> PackedByteArray:
		return FileAccess.get_file_as_bytes(_by_name[name.to_upper()]) if has_file(name) else PackedByteArray()
