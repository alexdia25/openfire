# One source is enough to import from: the Return Fire install folder, a folder holding the CD, or the CD's .iso (RFSource).
# The synthetic part runs anywhere: the CD's picture names map onto the install's, paths are read without regard to case, and the
# music comes from a .iso beside an install only when that image really holds the music. With the player's files it also
# imports the install (its CD image beside it) and the .iso alone and requires the two packs to match, file for file, byte for
# byte: the CD's RFIRE.BIN is a different build from the install's (RFExe.BUILDS), and this is what proves the music and the
# victory jingles still come out the same through it.
#   RF_GAME_DIR=<the Return Fire (PC) install, with its CD image beside it>
#   RF_ISO=<the CD image>                (default: "RFIRE US.iso" in RF_GAME_DIR)
# Run:
#   godot --headless --audio-driver Dummy --path . --script tools/tests/import_sources_check.gd
extends SceneTree

const SCRATCH := "user://import_sources_check"

var _failures := 0


func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _init() -> void:
	var root := ProjectSettings.globalize_path(SCRATCH)
	RFImporter.remove_tree(root)
	_synthetic(root)
	var install := OS.get_environment("RF_GAME_DIR")
	if install == "":
		print("(skipping the real import: set RF_GAME_DIR to run it)")
	else:
		_real(install, root)
	if OS.get_environment("RF_KEEP") != "1":
		RFImporter.remove_tree(root)
	print("import_sources_check: %s" % ("PASS" if _failures == 0 else "%d FAILED" % _failures))
	quit(0 if _failures == 0 else 1)


func _synthetic(root: String) -> void:
	var dir := root.path_join("folder")
	_write(dir.path_join("art/hibckeng.rfa"), PackedByteArray([1, 2, 3]))
	_write(dir.path_join("ART/ART.CAR"), PackedByteArray([4]))
	_write(dir.path_join("sound/Boom.SDT"), PackedByteArray([5, 6]))
	_write(dir.path_join("WORLDS/1PLAYER/LEVEL1/rfmap001.rfm"), PackedByteArray([7]))
	_write(dir.path_join("Other/NOTHING.TXT"), PackedByteArray([8]))
	var src := RFSource.open(dir)
	_check(src.error == "" and not src.is_disc, "a folder opens as a source")
	_check(src.has_file("ART/NEWREQLG.RFA") and src.read_file("art\\newreqlg.rfa") == PackedByteArray([1, 2, 3]),
			"the install's name for a picture finds the CD's, whatever the case or slash")
	_check(src.file_size("Art/Art.Car") == 1 and src.file_size("ART/MISSING.BIN") == -1, "sizes are read without regard to case; a missing file is -1")
	_check(src.list_files("SOUND", "SDT") == ["sound/Boom.SDT"], "listing keeps the on-disk spelling: %s" % [src.list_files("SOUND", "SDT")])
	_check(src.list_files("worlds", "RFM", true) == ["WORLDS/1PLAYER/LEVEL1/rfmap001.rfm"], "a recursive listing gives the path under the source")
	_check(not src.has_file("OTHER/NOTHING.TXT"), "folders the importer doesn't read are not walked")
	_check(src.music_source() == null, "an install with no CD image beside it has no music source")

	var big := PackedByteArray()
	big.resize(RFSource.MUSIC_MIN_BYTES + 1)
	var cd := root.path_join("cd")
	_write(cd.path_join("SOUND/SCORE.WAV"), big)
	_check(RFSource.open(cd).music_source() != null, "a folder holding the real SCORE.WAV is its own music source")
	_write(dir.path_join("SOUND/SCORE.WAV"), PackedByteArray([0, 0]))
	_check(RFSource.open(dir).music_source() == null, "a stub SCORE.WAV is not music")

	_check(RFSource.open(root.path_join("nowhere")).validate().contains("not a folder"), "a missing path is refused")
	_check(RFSource.open(root.path_join("folder/ART/ART.CAR")).validate().contains("not a folder or a CD image"), "a file that is not an .iso is refused")
	_write(root.path_join("fake.iso"), big)
	_check(RFSource.open(root.path_join("fake.iso")).validate().contains("not a readable CD image"), "an .iso that is not a disc image is refused")
	_check(RFSource.open(dir).validate().contains("RFIRE.BIN is missing"), "a folder without the game is refused")
	RFImporter.remove_tree(root.path_join("emptied"))
	_write(root.path_join("emptied/Some Disc.iso"), big)
	_check(RFSource.open(root.path_join("emptied")).validate().contains("Choose the .iso itself"), "a folder holding only a disc image says to choose the image")


func _real(install: String, root: String) -> void:
	var iso := OS.get_environment("RF_ISO")
	if iso == "":
		iso = install.path_join("RFIRE US.iso")
	if not FileAccess.file_exists(iso):
		print("FAIL  no CD image at %s (set RF_ISO)" % iso)
		_failures += 1
		return
	var from_folder := root.path_join("from_folder")
	var from_iso := root.path_join("from_iso")
	for job in [[install, from_folder], [iso, from_iso]]:
		var importer := RFImporter.new()
		var t0 := Time.get_ticks_msec()
		var why := importer.run(job[0], job[1])
		_check(why == "" and importer.warnings.is_empty(), "%s imports with no warnings (%.1f s) %s %s" % [job[0].get_file(), (Time.get_ticks_msec() - t0) / 1000.0, why, importer.warnings])
	var a := _files(from_folder)
	var b := _files(from_iso)
	_check(a.size() > 2000 and a == b, "both packs hold the same %d files" % a.size())
	var differing: Array[String] = []
	for rel in a:
		if b.has(rel) and not _same(from_folder.path_join(rel), from_iso.path_join(rel)):
			differing.append(rel)
	_check(differing.is_empty(), "and every one is the same, byte for byte (audio: sample for sample) %s" % [differing.slice(0, 5)])
	_check(FileAccess.file_exists(from_iso.path_join("music/track_01.res")) and FileAccess.file_exists(from_iso.path_join("music/win_3.cvid")),
			"the CD image alone carries the music and the victory jingles")


## Two pack files are the same: identical bytes, or, for an audio .res, the same format and samples.
static func _same(a: String, b: String) -> bool:
	if a.get_extension() == "res":
		var x := load(a) as AudioStreamWAV
		var y := load(b) as AudioStreamWAV
		return x != null and y != null and x.format == y.format and x.mix_rate == y.mix_rate and x.stereo == y.stereo and x.data == y.data
	return FileAccess.get_file_as_bytes(a) == FileAccess.get_file_as_bytes(b)


static func _files(root: String, rel := "") -> Array:
	var out := []
	var d := DirAccess.open(root.path_join(rel))
	if d == null:
		return out
	for f in d.get_files():
		out.append(rel.path_join(f) if rel != "" else f)
	for sub in d.get_directories():
		out.append_array(_files(root, rel.path_join(sub) if rel != "" else sub))
	out.sort()
	return out
