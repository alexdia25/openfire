class_name RFIso9660
extends RefCounted
## Reads files out of the game CD's image (an ISO 9660 .iso) without loading the whole image: the primary volume
## descriptor at sector 16 gives the root directory; directories are walked record by record. The Python pipeline
## found the same files by searching the raw image for "NAME;1" (tools/extract_music.py); this finds the same
## directory records the proper way.

const SECTOR := 2048

var _f: FileAccess
var _files: Dictionary = {}   ## upper-case file name (no ";1") -> [lba, size]


static func open(path: String) -> RFIso9660:
	var iso := RFIso9660.new()
	iso._f = FileAccess.open(path, FileAccess.READ)
	if iso._f == null or iso._f.get_length() < 17 * SECTOR:
		return null
	iso._f.seek(16 * SECTOR)
	var pvd := iso._f.get_buffer(SECTOR)
	if pvd[0] != 1 or pvd.slice(1, 6).get_string_from_ascii() != "CD001":
		return null
	var root := pvd.slice(156, 156 + 34)
	iso._walk(root.decode_u32(2), root.decode_u32(10), 0)
	return iso


func _walk(lba: int, size: int, depth: int) -> void:
	if depth > 8:
		return
	_f.seek(lba * SECTOR)
	var dir := _f.get_buffer(size)
	var pos := 0
	while pos < dir.size():
		var length := dir[pos]
		if length == 0:   # records never cross a sector: skip to the next one
			pos = (pos / SECTOR + 1) * SECTOR
			continue
		var flags := dir[pos + 25]
		var name_len := dir[pos + 32]
		var ident := dir.slice(pos + 33, pos + 33 + name_len)
		var rec_lba := dir.decode_u32(pos + 2)
		var rec_size := dir.decode_u32(pos + 10)
		if not (name_len == 1 and ident[0] <= 1):   # "." and ".."
			var name := ident.get_string_from_ascii().to_upper()
			if flags & 2:
				_walk(rec_lba, rec_size, depth + 1)
			elif not _files.has(name.get_slice(";", 0)):
				_files[name.get_slice(";", 0)] = [rec_lba, rec_size]
		pos += length


func has_file(name: String) -> bool:
	return _files.has(name.to_upper())


## The whole file `name` (any directory; the first one found by that name), or an empty array.
func read_file(name: String) -> PackedByteArray:
	var rec: Variant = _files.get(name.to_upper())
	if rec == null:
		return PackedByteArray()
	_f.seek(int(rec[0]) * SECTOR)
	return _f.get_buffer(int(rec[1]))
