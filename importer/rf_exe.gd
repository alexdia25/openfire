class_name RFExe
extends RefCounted
## RFIRE.BIN read by virtual address, through its PE section table: the GDScript twin of tools/rfexe.py. The importer
## reads a few traced tables straight out of the player's own executable (the music's track offsets and lines, the
## victory jingles' file names); the addresses are the traced ones, the bytes are theirs.

var data: PackedByteArray
var _sections: Array = []   ## [virtual address, size, file offset]


static func open(path: String) -> RFExe:
	var e := RFExe.new()
	e.data = FileAccess.get_file_as_bytes(path)
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
