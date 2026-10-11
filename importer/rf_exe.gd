class_name RFExe
extends RefCounted
## RFIRE.BIN read by virtual address, through its PE section table: the GDScript twin of tools/rfexe.py. The importer
## reads a few traced tables straight out of the player's own executable (the music's track offsets and lines, the
## victory jingles' file names); the addresses are the traced ones, the bytes are theirs.
##
## The retail CD's RFIRE.BIN and the installed one are different builds (the CD's is the older, 432,128 bytes against
## 401,920), so the same tables sit at different addresses; their contents were compared and are identical. BUILDS
## names each build by its file size. A build that is not here has no `tables()`, and the importer then skips the
## music rather than reading the wrong bytes.
const BUILDS := {
	401920: {"music_offsets": 0x449470, "music_lines": 0x4463b8, "jingle_files": 0x44e110, "jingle_by_level": 0x44e120},   ## the install's (traced, documents 98 and 101)
	432128: {"music_offsets": 0x449ef0, "music_lines": 0x44a368, "jingle_files": 0x451bd8, "jingle_by_level": 0x451be8},   ## the CD's
}

var data: PackedByteArray
var _sections: Array = []   ## [virtual address, size, file offset]


static func open(path: String) -> RFExe:
	return from_bytes(FileAccess.get_file_as_bytes(path))


static func from_bytes(bytes: PackedByteArray) -> RFExe:
	var e := RFExe.new()
	e.data = bytes
	if e.data.size() < 0x40 or e.data.slice(0, 2).get_string_from_ascii() != "MZ":
		return null
	var pe := e.data.decode_u32(0x3c)
	var nsec := e.data.decode_u16(pe + 6)
	var opt := e.data.decode_u16(pe + 20)
	var image_base := e.data.decode_u32(pe + 24 + 28)
	for i in nsec:
		var s := pe + 24 + opt + i * 40
		var vsize := e.data.decode_u32(s + 8)
		var va := e.data.decode_u32(s + 12)
		var rsize := e.data.decode_u32(s + 16)
		var roff := e.data.decode_u32(s + 20)
		e._sections.append([image_base + va, maxi(vsize, rsize), roff])
	return e


## Where this build keeps the importer's tables (BUILDS), or {} if it is not a build the importer knows.
func tables() -> Dictionary:
	return BUILDS.get(data.size(), {})


## The file offset of virtual address `va` (-1 if no section holds it).
func off(va: int) -> int:
	for s in _sections:
		if va >= s[0] and va < s[0] + s[1]:
			return s[2] + va - s[0]
	return -1


func byte(va: int) -> int:
	return data[off(va)]


func dword(va: int) -> int:
	return data.decode_u32(off(va))


func sdword(va: int) -> int:
	return data.decode_s32(off(va))


## The NUL-terminated string at `va`, latin-1.
func cstr(va: int) -> String:
	var o := off(va)
	return RFPyCompat.latin1(RFPyCompat.until_nul(data.slice(o, o + 256)))


## The bytes of resource `id` of type `type` (2 = RT_BITMAP, 6 = RT_STRING ...) from the resource tree, first language (the twin of rfexe.resource), or empty.
func resource(type: int, id: int) -> PackedByteArray:
	var pe := data.decode_u32(0x3c)
	var rva := data.decode_u32(pe + 24 + 96 + 16)   # data directory 2: the resource table
	if rva == 0:
		return PackedByteArray()
	var image_base := data.decode_u32(pe + 24 + 28)
	var root := off(image_base + rva)
	var ofs := _resource_entry(root, type)
	if ofs < 0 or ofs & 0x80000000 == 0:
		return PackedByteArray()
	ofs = _resource_entry(root + (ofs & 0x7fffffff), id)
	if ofs < 0 or ofs & 0x80000000 == 0:
		return PackedByteArray()
	ofs = _resource_entry(root + (ofs & 0x7fffffff), -1)   # the first language
	if ofs < 0 or ofs & 0x80000000 != 0:
		return PackedByteArray()
	var start := off(image_base + data.decode_u32(root + ofs))
	return data.slice(start, start + data.decode_u32(root + ofs + 4))


## The offset field of the entry of a resource directory at `dir` whose id is `wanted` (-1: the first entry), or -1.
func _resource_entry(dir: int, wanted: int) -> int:
	var named := data.decode_u16(dir + 12)
	for i in named + data.decode_u16(dir + 14):
		var e := dir + 16 + i * 8
		if wanted < 0 or (i >= named and data.decode_u32(e) == wanted):
			return data.decode_u32(e + 4)
	return -1
