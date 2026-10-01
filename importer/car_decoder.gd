class_name RFCarDecoder
extends RefCounted
## ART.CAR, the game's sprite file: the GDScript port of tools/convert_car.py and tools/rf_effect_cel.py (see their
## docstrings for how each rule was traced; the rules are restated here only as far as the code needs them).
##
##   0x00  "CCBA", u32 file size, u32 cel count, u32 end of the CCB array (16 + count * 68)
##   0x10  count CCBs of 17 u32: Flags NextPtr SourcePtr PLUTPtr XPos YPos HDX HDY VDX VDY HDDX HDDY PIXC PRE0 PRE1 Width Height
##
## PRE0 0 and 17 are ordinary 8bpp sprites (Width*Height bytes at SourcePtr, index 0 transparent). The shared PLUT --
## the one most cels use -- needs the runtime shift (document 20: shown colour = shared_plut[k - 10], black below 10);
## a PRE0 17 cel's own small PLUT is read unshifted. PRE0 1-5 and 13 are blend-effect coverage masks, not art: written
## white, with the mask byte (0/255, or its real value for PRE0 3-5) as alpha.
##
## Where the Python converter packed every cel into an atlas that tools/build_pack.py then cut back into frames, this
## produces each frame directly; the pixels are the same.

const CCB_SIZE := 68
const MASK_LINEAR := [1, 2, 3, 4, 5]
const MASK_SPAN := [13]
const VALUE_MEANINGFUL := [3, 4, 5]   ## PRE0 values whose mask byte value, not just zero/nonzero, is kept
const SHARED_PLUT := 0x282CC          ## the shared PLUT's offset in the PC release (build_pack.py reads palettes here)

var data: PackedByteArray
var count := 0
var cels: Array[Dictionary] = []   ## {flags, src, plut, pre0, w, h}
var shared_plut := 0               ## the PLUT most cels use: the one that gets the -10 shift
var _palettes: Dictionary = {}     ## PLUT offset -> PackedByteArray of 256 * RGB


## Parses the header and CCBs; "" on success, else why the file is not a usable ART.CAR.
func load(bytes: PackedByteArray) -> String:
	data = bytes
	if data.size() < 16 or data.slice(0, 4).get_string_from_ascii() != "CCBA":
		return "ART.CAR is not a cel file (bad magic)"
	count = data.decode_u32(8)
	if 16 + count * CCB_SIZE > data.size():
		return "ART.CAR's cel table runs past the end of the file"
	var plut_counts := {}
	for n in count:
		var o := 16 + n * CCB_SIZE
		var c := {"flags": data.decode_u32(o), "src": data.decode_u32(o + 8), "plut": data.decode_u32(o + 12),
				"pre0": data.decode_u32(o + 52), "w": data.decode_u32(o + 60), "h": data.decode_u32(o + 64)}
		cels.append(c)
		plut_counts[c["plut"]] = int(plut_counts.get(c["plut"], 0)) + 1
	var best := -1
	for p in plut_counts:   # Python's max() over a dict keeps the first key on a tie: iterate in first-seen order
		if best < 0 or plut_counts[p] > plut_counts[best]:
			best = p
	shared_plut = best
	return ""


func kind(n: int) -> String:
	var c := cels[n]
	if int(c["w"]) <= 0 or int(c["h"]) <= 0:
		return "skipped"
	if int(c["pre0"]) in MASK_LINEAR or int(c["pre0"]) in MASK_SPAN:
		return "effect"
	return "sprite"


## 256 RGB entries read as Windows RGBQUADs (B, G, R, pad) at `offset`; past the end of the file reads black.
func _palette(offset: int) -> PackedByteArray:
	if _palettes.has(offset):
		return _palettes[offset]
	var pal := PackedByteArray()
	pal.resize(256 * 3)
	for i in 256:
		var o := offset + i * 4
		if o + 4 <= data.size():
			pal[i * 3] = data[o + 2]
			pal[i * 3 + 1] = data[o + 1]
			pal[i * 3 + 2] = data[o]
	_palettes[offset] = pal
	return pal


## The cel as an RGBA8 image (a sprite in its colours, an effect mask in white with coverage as alpha), or null if it
## cannot be decoded (the error is in `last_error`).
var last_error := ""
func image(n: int) -> Image:
	var c := cels[n]
	var w: int = c["w"]
	var h: int = c["h"]
	var src: int = c["src"]
	var pre0: int = c["pre0"]
	var rgba := PackedByteArray()
	rgba.resize(w * h * 4)
	if pre0 in MASK_LINEAR or pre0 in MASK_SPAN:
		var mask := _effect_mask(c)
		if mask.is_empty():
			return null
		for i in w * h:
			rgba[i * 4] = 255
			rgba[i * 4 + 1] = 255
			rgba[i * 4 + 2] = 255
			rgba[i * 4 + 3] = mask[i]
	else:
		if src + w * h > data.size():
			last_error = "cel %d: pixels run past the end of ART.CAR" % n
			return null
		var pal := _palette(c["plut"])
		var shifted: bool = c["plut"] == shared_plut
		for i in w * h:
			var idx := data[src + i]
			var k := idx
			if shifted:
				k = idx - 10
			if shifted and idx < 10:
				pass   # black (the buffer is already zero)
			else:
				rgba[i * 4] = pal[k * 3]
				rgba[i * 4 + 1] = pal[k * 3 + 1]
				rgba[i * 4 + 2] = pal[k * 3 + 2]
			rgba[i * 4 + 3] = 0 if idx == 0 else 255
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)


## rf_effect_cel.decode_effect_mask(): Width*Height mask bytes.
func _effect_mask(c: Dictionary) -> PackedByteArray:
	var w: int = c["w"]
	var h: int = c["h"]
	var src: int = c["src"]
	var pre0: int = c["pre0"]
	var mask := PackedByteArray()
	mask.resize(w * h)
	if pre0 in MASK_LINEAR:
		if src + w * h > data.size():
			last_error = "linear mask runs past end of file (source_ptr=0x%X)" % src
			return PackedByteArray()
		var keep: bool = pre0 in VALUE_MEANINGFUL
		for i in w * h:
			var b := data[src + i]
			mask[i] = b if keep else (255 if b != 0 else 0)
		return mask
	# PRE0 13: Height u16 row offsets from SourcePtr, each row a list of (x0, x1) bytes in 0..255, ended by x0 == 0
	if src + h * 2 > data.size():
		last_error = "span mask row table runs past end of file"
		return PackedByteArray()
	for row in h:
		var row_off := data.decode_u16(src + row * 2)
		if row_off == 0:
			continue
		var ptr := src + row_off
		var guard := 0
		while true:
			guard += 1
			if guard > 512 or ptr + 2 > data.size():
				last_error = "span mask row %d is corrupt" % row
				return PackedByteArray()
			var x0 := data[ptr]
			var x1 := data[ptr + 1]
			if x0 == 0:
				break
			var sx0 := RFPyCompat.round_half_even(x0 / 255.0 * (w - 1))
			var sx1 := RFPyCompat.round_half_even(x1 / 255.0 * (w - 1))
			if sx0 > sx1:
				var t := sx0
				sx0 = sx1
				sx1 = t
			for x in range(maxi(sx0, 0), mini(sx1 + 1, w)):
				mask[row * w + x] = 255
			ptr += 2
	return mask


## The game's runtime palette (document 20): slots 0-9 black, then the shared PLUT at SHARED_PLUT from slot 10.
## [[r, g, b] x 256], as build_pack.py writes it to sprites/palette.json.
func runtime_palette() -> Array:
	var out := []
	for k in 256:
		if k < 10:
			out.append([0, 0, 0])
		else:
			var o := SHARED_PLUT + (k - 10) * 4
			out.append([data[o + 2], data[o + 1], data[o]])
	return out


## The 256-colour master palette (a LOGPALETTE 0x400 bytes after cel 0's PLUT, entries R, G, B, flags) that the
## compass lamps' nearest-colour search runs against (tools/extract_compass_lamps.py). [] if it is not where expected.
func master_palette() -> Array:
	var at: int = int(cels[0]["plut"]) + 0x400 + 4
	if at + 1024 > data.size() or data[at - 4] != 0 or data[at - 3] != 3:
		return []
	var out := []
	for i in 256:
		out.append([data[at + i * 4], data[at + i * 4 + 1], data[at + i * 4 + 2]])
	return out
