class_name RFPyCompat
extends RefCounted
## The few places where the Python pipeline's output depends on Python's own semantics, reproduced exactly so the
## GDScript importer writes the same pack (issue #61's parity check): Python's round() (half to even), its float %
## (sign of the divisor), colorsys.rgb_to_hsv, the cp1252 decoder, bytes.hex(), and how a tuple prints.

const _CP1252_HIGH := [   # 0x80-0x9F; 0 = undefined in cp1252 (Python's "replace" gives U+FFFD)
	0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
	0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178]


## Python's round(v) for a float: to the nearest integer, a tie to the even one.
static func round_half_even(v: float) -> int:
	var f := floorf(v)
	var d := v - f
	if d > 0.5:
		return int(f) + 1
	if d < 0.5:
		return int(f)
	return int(f) if int(f) % 2 == 0 else int(f) + 1


## Python's round(v, digits) closely enough for the pack's values (pivots w/2 to one place, HSV means to four).
static func round_digits(v: float, digits: int) -> float:
	var scale := pow(10.0, digits)
	return round_half_even(v * scale) / scale


## Python's a % b for floats: the result takes the divisor's sign.
static func fmod_py(a: float, b: float) -> float:
	return a - b * floorf(a / b)


## colorsys.rgb_to_hsv, line for line (inputs 0..1).
static func rgb_to_hsv(r: float, g: float, b: float) -> Vector3:
	var maxc := maxf(r, maxf(g, b))
	var minc := minf(r, minf(g, b))
	var rangec := maxc - minc
	var v := maxc
	if minc == maxc:
		return Vector3(0.0, 0.0, v)
	var s := rangec / maxc
	var rc := (maxc - r) / rangec
	var gc := (maxc - g) / rangec
	var bc := (maxc - b) / rangec
	var h: float
	if r == maxc:
		h = bc - gc
	elif g == maxc:
		h = 2.0 + rc - bc
	else:
		h = 4.0 + gc - rc
	h = fmod_py(h / 6.0, 1.0)
	return Vector3(h, s, v)


## bytes.decode("cp1252", "replace").
static func cp1252(bytes: PackedByteArray) -> String:
	var out := ""
	for b in bytes:
		if b < 0x80 or b >= 0xA0:
			out += char(b)
		else:
			var c: int = _CP1252_HIGH[b - 0x80]
			out += char(c if c != 0 else 0xFFFD)
	return out


## bytes.decode("latin-1").
static func latin1(bytes: PackedByteArray) -> String:
	var out := ""
	for b in bytes:
		out += char(b)
	return out


## bytes.hex().
static func hex(bytes: PackedByteArray) -> String:
	return bytes.hex_encode()


## How Python prints a 2-tuple of ints, e.g. a PIL image size: "(16, 16)".
static func tuple2(a: int, b: int) -> String:
	return "(%d, %d)" % [a, b]


## The bytes before the first NUL (or all of them).
static func until_nul(bytes: PackedByteArray) -> PackedByteArray:
	var i := bytes.find(0)
	return bytes if i < 0 else bytes.slice(0, i)
