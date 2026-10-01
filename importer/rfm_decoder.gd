class_name RFRfmDecoder
extends RefCounted
## A .RFM level: the GDScript port of tools/convert_rfm.py's parse_rfm() and tools/rf_tile_art.py's lookups (both
## docstrings hold how each field was traced). Produces exactly what build_pack.py copies into levels/<name>/:
## level.json (the metadata dict) and art.bin (one resolved art id per tile).
##
##   0x00 "WRL\0"; 0x08 u16 width, u16 height; 0x0E/0x12 DOS created/modified date+time; 0x16 mode byte;
##   0x17 15-byte author; 0x40 enabled byte; 0x44 u32 grid size; 0x48 u32 end of the chunk table = start of the grid;
##   0x50.. chunks [tag(4)][record length(4)][payload] (NAME, LEVL, VHCL; others round-tripped as hex).

const CHUNK_TABLE_START := 0x50
const TILE_SPAWN_P1 := 0x39
const TILE_SPAWN_P2 := 0x4D
const TILE_CANDIDATE_A := 0xB4
const TILE_CANDIDATE_B := 0xDC
const VHCL_DEFAULTS := {"A": 3, "H": 3, "J": 8, "T": 3, "unk4": 0xFF, "M": 0xFF}
const VHCL_FIELD_ORDER := ["A", "H", "J", "T", "unk4", "M"]

var _primary: Array = []      ## tools/data/tile_lookup_tables.json "primary_table", index = raw byte
var _coastal: Dictionary = {} ## "coastal_table": str(coastal id) -> entry


func _init(tile_tables: Dictionary) -> void:
	_primary = tile_tables["primary_table"]
	_coastal = tile_tables["coastal_table"]


## rf_tile_art.raw_tile_to_art_id(), with None as -1.
func art_id(raw: int) -> int:
	if raw >= 240:
		raw = 0
	var e: Dictionary = _primary[raw]
	var transform := int(e["transform_byte"])
	var coastal_id := int(e["coastal_id"])
	if transform == 0xFF and coastal_id == 0:
		return -1
	var art := transform
	if coastal_id != 0:
		var c: Variant = _coastal.get(str(coastal_id))
		if c != null and int(c["valid"]) != 0 and int(c["base_art"]) != 0xFF:
			art = int(c["base_art"])
	return art & 0x7F


func coastal_id(raw: int) -> int:
	return int(_primary[raw if raw < 240 else 0]["coastal_id"])


static func _dos_datetime(d: int, t: int) -> String:
	return "%04d-%02d-%02d %02d:%02d:%02d" % [1980 + (d >> 9), (d >> 5) & 0xF, d & 0x1F, (t >> 11) & 0x1F, (t >> 5) & 0x3F, (t & 0x1F) * 2]


## convert_rfm.parse_bracket_params(): an [A3H5T2]-style suffix in the file name.
static func _bracket_params(filename: String) -> Dictionary:
	var start := filename.find("[")
	if start < 0:
		return {}
	var out := {}
	var i := start + 1
	var n := filename.length()
	while i < n and filename[i] != "]":
		var ch := filename[i]
		if _is_alpha(ch):
			var j := i + 1
			var digits := ""
			while j < n and filename[j] >= "0" and filename[j] <= "9":
				digits += filename[j]
				j += 1
			if digits != "":
				var val := int(digits)
				var letter := ch.to_upper()
				if letter == "A" and val < 10:
					out["A"] = val
				elif letter == "H" and val < 10:
					out["H"] = val
				elif letter == "J" and val > 0 and val < 10:
					out["J"] = val
				elif letter == "M" and val < 0xC9:
					out["M"] = val
				elif letter == "T" and val < 10:
					out["T"] = val
				i = j
				continue
		i += 1
	return out


static func _is_alpha(ch: String) -> bool:
	var c := ch.unicode_at(0)
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c >= 0xC0


## {"meta": level.json dict, "art": PackedByteArray} for one file, or {"error": why}.
## `filename` is the file's own name, `rel_path` its path under WORLDS/ with forward slashes.
func decode(data: PackedByteArray, filename: String, rel_path: String) -> Dictionary:
	if data.size() < CHUNK_TABLE_START or data.slice(0, 4) != PackedByteArray([0x57, 0x52, 0x4C, 0]):
		return {"error": "bad magic"}
	var width := data.decode_u16(0x08)
	var height := data.decode_u16(0x0A)
	var mode_byte := data[0x16]
	var enabled := data[0x40] != 0
	var author := RFPyCompat.cp1252(RFPyCompat.until_nul(data.slice(0x17, 0x17 + 15)))
	var grid_size := data.decode_u32(0x44)
	var table_end := data.decode_u32(0x48)
	if table_end + grid_size != data.size():
		return {"error": "size check failed: chunk_table_end(%d) + grid_size(%d) != filesize(%d)" % [table_end, grid_size, data.size()]}
	if grid_size != width * height:
		return {"error": "grid_size(%d) != width*height" % grid_size}
	if not enabled:
		return {"error": "'enabled' byte at 0x40 is zero"}

	var name: Variant = null
	var levl_raw: Variant = null
	var vhcl: Variant = null
	var tags_seen := []
	var unrecognized := {}
	var pos := CHUNK_TABLE_START
	var guard := 0
	while pos < table_end:
		guard += 1
		if guard > 10000 or pos + 8 > data.size():
			return {"error": "corrupt chunk table"}
		var tag := data.slice(pos, pos + 4)
		var reclen := data.decode_u32(pos + 4)
		if reclen < 8 or pos + reclen > data.size():
			return {"error": "bad chunk record length %d at 0x%X" % [reclen, pos]}
		var payload := data.slice(pos + 8, pos + reclen)
		var tag_str := RFPyCompat.latin1(tag)   # the tags seen are ASCII
		tags_seen.append(tag_str)
		if tag_str == "NAME" and name == null:
			name = RFPyCompat.cp1252(RFPyCompat.until_nul(payload))
		elif tag_str == "LEVL" and levl_raw == null:
			if not payload.is_empty():
				levl_raw = payload[0]
		elif tag_str == "VHCL" and vhcl == null:
			vhcl = payload
		elif not tag_str in ["NAME", "LEVL", "VHCL"]:
			unrecognized[tag_str] = RFPyCompat.hex(payload)
		pos += reclen

	# defaults -> the file name's [..] suffix -> the VHCL chunk (FUN_00413f00)
	var values := VHCL_DEFAULTS.duplicate()
	var sources := {}
	for k in values:
		sources[k] = "default"
	var from_name := _bracket_params(filename)
	for k in from_name:
		values[k] = from_name[k]
		sources[k] = "filename"
	if vhcl != null:
		for idx in VHCL_FIELD_ORDER.size():
			if idx < (vhcl as PackedByteArray).size() and vhcl[idx] != 0xFF:
				values[VHCL_FIELD_ORDER[idx]] = vhcl[idx]
				sources[VHCL_FIELD_ORDER[idx]] = "chunk"
	if values["M"] == 0xFF and mode_byte == 2:
		values["M"] = 0
		sources["M"] = "mode2_default"

	var grid := data.slice(table_end, table_end + grid_size)
	var art := PackedByteArray()
	art.resize(grid_size)
	var tile_seed := 0
	var decorations := []
	var spawn_points := []
	var cand_a := []
	var cand_b := []
	for i in grid_size:
		var raw := grid[i]
		var a := art_id(raw)
		art[i] = a if a > 0 else 0
		tile_seed += raw
		var cid := coastal_id(raw)
		if cid != 0:
			decorations.append({"x": i % width, "y": i / width, "coastal_id": cid,
					"variant": int(_primary[raw if raw < 240 else 0]["param4"])})
	for i in grid_size:
		var raw := grid[i]
		var p := {"x": i % width, "y": i / width}
		if raw == TILE_SPAWN_P1:
			spawn_points.append({"team": 0, "x": p["x"], "y": p["y"]})
		elif raw == TILE_SPAWN_P2:
			spawn_points.append({"team": 1, "x": p["x"], "y": p["y"]})
		elif raw == TILE_CANDIDATE_A:
			cand_a.append(p)
		elif raw == TILE_CANDIDATE_B:
			cand_b.append(p)

	var levl_value: Variant = null
	if levl_raw != null:
		var v: int = levl_raw - 1
		levl_value = v if v >= 0 and v < 9 else 8

	var meta := {
		"source": filename, "width": width, "height": height, "mode_byte": mode_byte, "enabled": enabled,
		"name": name, "author": author,
		"created": _dos_datetime(data.decode_u16(0x0E), data.decode_u16(0x10)),
		"modified": _dos_datetime(data.decode_u16(0x12), data.decode_u16(0x14)),
		"levl_raw": levl_raw, "levl_value": levl_value, "vehicle_params": values, "vehicle_param_sources": sources,
		"chunk_tags_seen": tags_seen, "unrecognized_chunks": unrecognized, "spawn_points": spawn_points,
		"candidate_pools": {"a": cand_a, "b": cand_b}, "decorations": decorations,
		"tile_seed": tile_seed & 0xFFFFFFFF, "rel_path": rel_path}
	return {"meta": meta, "art": art}
