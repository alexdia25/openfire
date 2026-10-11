class_name RFImporter
extends RefCounted
## "Open Fire" mode's importer (issue #61): turns the player's own Return Fire (PC) install -- or the game CD's image -- into the game's
## base pack, inside the game, with nothing else installed. The GDScript port of tools/import_original.py and the scripts it runs;
## the Python pipeline is the reference it is checked against (tools/tests/importer_parity_check.gd) until parity holds,
## after which this is the canonical one (issue #61, "Correction to decision 3").
##
##   var why := RFImporter.new().run(install_dir_or_iso, "user://packs/original_pc", progress)   # "" = success
##
## Blocking, and safe to run on a worker thread: it touches no scene tree. `progress.call(fraction, message)` is
## called on the thread that runs it, so a UI should forward it with call_deferred. The pack is assembled in
## "<out_dir>.partial" and swapped into place only when every step has succeeded: a failed or interrupted import never
## leaves a half-built pack where the game looks for one, and never touches a good pack that is already there.
##
## Validation is deliberately loose (issue #61, decision 2): the expected files exist and are roughly the right size.
## It is all in RFSource.validate(), so tightening it later (hashes of known releases) touches nothing else.
##
## One source is enough (RFSource): the install folder, a folder holding the CD, or the CD's .iso each hold everything
## the pack is made from. Only the music is not in an install (its SCORE.WAV is a stub): from an install alone the pack
## is built without music and a warning says so, unless a .iso sits beside it.

var warnings: Array[String] = []
var counts := {}
var _progress := Callable()
var _step_base := 0.0
var _step_span := 0.0


## Why `path` (an install folder, a folder holding the CD, or the CD's .iso) is not a usable PC release ("" if it is).
static func validate_install(path: String) -> String:
	return RFSource.open(path).validate()


func _step(base: float, span: float, message: String) -> void:
	_step_base = base
	_step_span = span
	_report(0.0, message)


func _report(fraction: float, message: String) -> void:
	if _progress.is_valid():
		_progress.call(clampf(_step_base + _step_span * fraction, 0.0, 1.0), message)


## Imports `source` (an install folder, a folder holding the CD, or the CD's .iso) into `out_dir`. "" on success, else
## what went wrong (nothing is left at `out_dir` that wasn't there before).
func run(source: String, out_dir: String, progress := Callable()) -> String:
	_progress = progress
	warnings.clear()
	_step(0.0, 0.01, "Checking the game files")
	var src := RFSource.open(source)
	var why := src.validate()
	if why != "":
		return why
	var partial := out_dir + ".partial"
	remove_tree(partial)
	DirAccess.make_dir_recursive_absolute(partial)
	why = _build(src, partial)
	if why == "":
		why = _swap_into_place(partial, out_dir)
	if why != "":
		remove_tree(partial)
		return why
	_step(1.0, 0.0, "Done")
	return ""


func _build(src: RFSource, out: String) -> String:
	var car := RFCarDecoder.new()
	var why := car.load(src.read_file("ART/ART.CAR"))
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
	var files := src.list_files("WORLDS", "RFM", true)
	var decoded := {}
	for i in files.size():
		var f: String = files[i]
		var r := rfm.decode(src.read_file(f), f.get_file(), f.trim_prefix("WORLDS/"))
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
	for f in src.list_files("SOUND", "SDT"):
		var bytes := src.read_file(f)
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
	for result in [RFExtras.hud_strips(src, out), RFExtras.win_banners(src, out),
			RFExtras.compass_lamps(car, out), RFExtras.level_previews(src, files, out)]:
		if result != "":
			return result

	var cd := src.music_source()
	var exe := RFExe.from_bytes(src.read_file("RFIRE.BIN"))
	if cd == null:
		warnings.append("The game CD was not found, so the game has no music: an installed copy of Return Fire has only a placeholder for it. Import again from the CD's image (.iso) to add the music.")
	elif exe == null or exe.tables().is_empty():
		warnings.append("This RFIRE.BIN is a build the importer does not know, so the game has no music.")
	else:
		# Music and the victory jingles (audio and video) are extras: if either can't be read the game still plays, so
		# the player is told what is missing and the import carries on without it.
		_step(0.66, 0.24, "Extracting the music")
		why = RFExtras.music(exe, cd, out)
		if why != "":
			warnings.append("The game has no music: %s." % why)
			_remove_files(out.path_join("music"), "track_", "music.json")
		_step(0.90, 0.06, "Extracting the victory jingles")
		why = RFExtras.win_jingles(exe, cd, out)
		if why != "":
			warnings.append("The victory jingles and their video are missing: %s." % why)
			_remove_files(out.path_join("music"), "win_", "jingles.json")

	_step(0.96, 0.04, "Checking the pack")
	return validate_pack(out)


## Deletes what a failed extra left half-written: the files in `dir` starting with `prefix`, and `extra`.
static func _remove_files(dir: String, prefix: String, extra: String) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(prefix) or f == extra:
			DirAccess.remove_absolute(dir.path_join(f))


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
