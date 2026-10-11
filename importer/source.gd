class_name RFSource
extends RefCounted
## The player's copy of Return Fire (PC), read by path whatever it is: the folder the game was installed to, a folder
## holding a copy of the CD (or the mounted CD), or the CD's own image (an ISO 9660 .iso). The CD carries every file
## the importer needs (the sprites, levels, sound effects, title art and RFIRE.BIN as well as the music), so any one of
## them is enough to import from. The importer reads only through this class, with paths like "ART/ART.CAR", any case.
##
## Two things differ between the CD and an install, and both are absorbed here or in RFExe, not in the importer:
## - the install's SOUND/SCORE.WAV (the music) is a 20-byte stub, so an install alone has no music: music_source()
##   looks for a .iso beside it, which is how an install plus its CD image still imports with music;
## - the CD names two pictures differently (ALIASES: pixel-identical, checked on the retail disc), and its RFIRE.BIN is
##   an older build (RFExe.BUILDS).

const READ_DIRS := ["ART", "SOUND", "WORLDS", "TITLE"]   ## the folders the importer reads; nothing else under a folder source is walked
const MUSIC_MIN_BYTES := 1000000   ## the install's SOUND/SCORE.WAV is a 20-byte stub; the CD's is the real music
## the install's file name -> the same picture under the CD's name (English)
const ALIASES := {"ART/NEWREQLG.RFA": "ART/HIBCKENG.RFA", "ART/NEWREQSM.RFA": "ART/LOBCKENG.RFA"}
## path under the source -> minimum plausible size in bytes
const REQUIRED_FILES := {"RFIRE.BIN": 300000, "ART/ART.CAR": 1000000}
## directory under the source, extension, minimum count (recursive)
const REQUIRED_SETS := [["SOUND", "SDT", 30], ["WORLDS", "RFM", 100], ["TITLE", "BMP", 4]]

var path := ""
var is_disc := false      ## a .iso (otherwise a folder)
var error := ""           ## why `path` can't be read at all ("" if it can)
var _iso: RFIso9660
var _real := {}           ## upper-case path -> the path as it is on disk / on the disc
var _keys: Array = []     ## the keys of `_real`, sorted


## Opens a folder or a .iso. Never null: `error` says why a source that can't be read can't.
static func open(p: String) -> RFSource:
	var s := RFSource.new()
	s.path = p.strip_edges()
	if s.path == "":
		s.error = "Choose the folder Return Fire (PC) was installed to, or the game CD's .iso."
	elif DirAccess.dir_exists_absolute(s.path):
		s._index_folder()
	elif FileAccess.file_exists(s.path) and s.path.get_extension().to_lower() == "iso":
		s.is_disc = true
		s._iso = RFIso9660.open(s.path)
		if s._iso == null:
			s.error = "%s is not a readable CD image." % s.path
		else:
			for p2 in s._iso.paths():
				s._real[p2] = p2
	else:
		s.error = "%s is not a folder or a CD image (.iso)." % s.path
	s._keys = s._real.keys()
	s._keys.sort()
	return s


func _index_folder() -> void:
	var d := DirAccess.open(path)
	for f in d.get_files():
		_real[f.to_upper()] = f
	for sub in d.get_directories():
		if READ_DIRS.has(sub.to_upper()):
			_add_tree(sub)


func _add_tree(rel: String) -> void:
	var d := DirAccess.open(path.path_join(rel))
	if d == null:
		return
	for f in d.get_files():
		_real[(rel + "/" + f).to_upper()] = rel + "/" + f
	for sub in d.get_directories():
		_add_tree(rel + "/" + sub)


func _key(rel: String) -> String:
	var k := rel.replace("\\", "/").to_upper()
	if not _real.has(k) and ALIASES.has(k) and _real.has(ALIASES[k].to_upper()):
		return ALIASES[k].to_upper()
	return k


func has_file(rel: String) -> bool:
	return _real.has(_key(rel))


## The file's size in bytes, -1 if there is no such file.
func file_size(rel: String) -> int:
	var k := _key(rel)
	if not _real.has(k):
		return -1
	if is_disc:
		return _iso.file_size(k)
	var f := FileAccess.open(path.path_join(_real[k]), FileAccess.READ)
	return -1 if f == null else f.get_length()


## The whole file, or an empty array if there is none.
func read_file(rel: String) -> PackedByteArray:
	var k := _key(rel)
	if not _real.has(k):
		return PackedByteArray()
	return _iso.read_file(k) if is_disc else FileAccess.get_file_as_bytes(path.path_join(_real[k]))


## The files directly under `dir` ("SOUND"), or all the way down if `recursive`, as paths from the root ("SOUND/AR1.SDT"),
## sorted; only those with extension `ext` if given. Paths are spelt as they are on disk, so they can be read back or used
## as a level's own relative path.
func list_files(dir: String, ext := "", recursive := false) -> Array[String]:
	var prefix := dir.replace("\\", "/").to_upper() + "/"
	var out: Array[String] = []
	for k in _keys:
		if not k.begins_with(prefix):
			continue
		if not recursive and k.substr(prefix.length()).contains("/"):
			continue
		if ext != "" and k.get_extension() != ext.to_upper():
			continue
		out.append(_real[k])
	return out


func _count(dir: String, ext: String) -> int:
	return list_files(dir, ext, true).size()


## Why this is not a usable PC release ("" if it is), worded for the player. Deliberately loose (issue #61, decision 2):
## the expected files exist and are roughly the right size. Tightening it later (hashes of known releases) touches
## nothing else.
func validate() -> String:
	if error != "":
		return error
	if not has_file("RFIRE.BIN"):
		if is_disc:
			return "This CD image does not hold Return Fire (PC): RFIRE.BIN is missing."
		var isos: Array[String] = []
		var cue := false
		for f in _list_all(path):
			match f.get_extension().to_lower():
				"cue":
					cue = true
				"iso":
					if f.get_base_dir() == path:
						isos.append(f)
		if cue:
			return "This looks like the 3DO version of Return Fire (a disc image). Only the PC (Windows 95) release is supported for now: choose the folder it was installed to, or its CD's .iso."
		if not isos.is_empty():
			return "RFIRE.BIN is missing: this folder holds a disc image (%s) but not the game. Choose the .iso itself." % isos[0].get_file()
	for rel in REQUIRED_FILES:
		var size := file_size(rel)
		if size < 0:
			return "%s is missing. Is this %s?" % [rel, "the Return Fire (PC) CD" if is_disc else "the folder Return Fire (PC) was installed to"]
		if size < REQUIRED_FILES[rel]:
			return "%s is smaller than expected (%d bytes); the %s may be damaged." % [rel, size, "CD image" if is_disc else "install"]
	for s in REQUIRED_SETS:
		var n := _count(s[0], s[1])
		if n < s[2]:
			return "Expected at least %d %s files under %s, found %d; the %s may be incomplete." % [s[2], s[1], s[0], n, "CD image" if is_disc else "install"]
	return ""


func has_music() -> bool:
	return file_size("SOUND/SCORE.WAV") > MUSIC_MIN_BYTES


## Where the music and the victory jingles come from: this source if it holds the real SOUND/SCORE.WAV (a disc, or a
## copy of one), else a .iso sitting in the same folder (an install keeps its CD image beside it) that does; null if
## there is none. `RFIRE US.iso`, the retail disc's usual name, is tried first.
func music_source() -> RFSource:
	if has_music():
		return self
	if is_disc or error != "":
		return null
	var isos: Array[String] = []
	for f in DirAccess.get_files_at(path):
		if f.get_extension().to_lower() == "iso":
			isos.append(path.path_join(f))
	isos.sort_custom(func(a: String, b: String) -> bool:
		return [a.get_file().to_upper() != "RFIRE US.ISO", a] < [b.get_file().to_upper() != "RFIRE US.ISO", b])
	for f in isos:
		var s := RFSource.open(f)
		if s.error == "" and s.has_music():
			return s
	return null


## Every file under `dir`, as full paths (only walked to tell the 3DO release from a wrong folder).
static func _list_all(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_list_all(dir.path_join(sub)))
	return out
