"""SUPERSEDED, kept only as an investigative record -- do not use for real
conversion. See rf_effect_cel.py, which convert_car.py actually uses.

This module's hypothesis was that PRE0-nonzero cels are compressed sprite
COLOUR data using a literal/skip/repeat bit-packed opcode stream (the real
3DO MADAM cel-engine convention). That was checked against Ghidra's
decompilation of RFIRE.BIN's actual renderer (2026-09-04) and found wrong:
these cels are coverage MASKS for a masked palette-translation blend effect
(the colour comes from remapping the existing background pixel, not from
data stored in the cel), and the row data for one of the two mask families
is a proportionally-scaled (x0,x1) span list, not a bit-packed opcode
stream. Confirmed by decoding real cels and rendering them: the result is
recognisable iconography (radar-sweep rings, explosion starbursts,
targeting wedges), not noise. Full writeup in rf_effect_cel.py and
docs/PORTING_PLAN.md section 1.6.

Original (wrong) docstring kept below for the historical record of what was
tried and why it was rejected -- see docs/PORTING_PLAN.md section 5's
standing lesson: "a plausible byte count is not a correctness proof."

---

Most cels in ART.CAR are 8bpp unpacked linear (exactly Width*Height bytes at
SourcePtr -- handled directly by the caller). A minority (93 of 2165, as of
the 1996 retail build) have PRE0 != 0: their low 3 bits are the 3DO bit-depth
code, and their pixel data is packed with a row-oriented RLE scheme.

This is NOT the literal 3DO hardware CCB_PACKED format (that reads a length
prefix inline at the start of each row's own data, and is gated by a Flags
bit that is not actually set on these cels). It was reverse engineered
directly against this file by:

  1. Getting the real bit-depth-code and opcode semantics from a 3DO MADAM
     cel-engine reimplementation (trapexit/3doplay, Madam.cpp) -- PRE0 bits
     0-2 select bpp (1/1/2/4/6/8/16 for codes 0-6), and packed rows use a
     2-bit opcode + 6-bit (count-1) scheme: 0=end-of-row, 1=literal run,
     2=transparent-skip run, 3=repeat-pixel run.
  2. Finding empirically that this PC port does NOT use that engine's
     inline per-row length prefix. Instead, `Height` little-endian offsets
     (1 byte each if bpp < 8, else 2 bytes each) are stored starting at
     SourcePtr -- one per row -- each either 0 (row is fully transparent) or
     an ABSOLUTE byte offset from SourcePtr to that row's bit-packed opcode
     stream. Confirmed by hand-decoding cel 120 (16x16, 8bpp): the offset
     table's values point exactly at the byte where plausible opcode/pixel
     bytes begin, immediately after the table.
  3 Validating by decoding all 93 cels and checking each decodes to exactly
    Width*Height pixels while consuming a plausible (<= 2x unpacked) byte
    span: 92/93 pass; see KNOWN_BAD below for the one exception.

Row decoding is width-driven (stop once Width pixels are produced, or on an
explicit end-of-row opcode) rather than length-driven -- the per-row offset
table gives a start position, not an end position, so no hard boundary is
enforced. This matches the self-terminating nature of the opcode stream.
"""

BPP_FOR_CODE = {0: 1, 1: 1, 2: 2, 3: 4, 4: 6, 5: 8, 6: 16, 7: 1}

# Cels that fail the plausibility check even with this algorithm. Recorded so
# the caller can flag them rather than silently render garbage.
KNOWN_BAD = {2077}


class PackedCelError(Exception):
    pass


class _BitReader:
    """MSB-first bit reader over a byte buffer, starting at a byte offset."""

    __slots__ = ("data", "pos")

    def __init__(self, data, start_byte):
        self.data = data
        self.pos = start_byte * 8

    def read(self, nbits):
        v = 0
        data = self.data
        pos = self.pos
        for _ in range(nbits):
            byte_idx = pos >> 3
            bit_idx = 7 - (pos & 7)
            v = (v << 1) | ((data[byte_idx] >> bit_idx) & 1)
            pos += 1
        self.pos = pos
        return v

    def skip(self, nbits):
        self.pos += nbits

    def byte_pos(self):
        return (self.pos + 7) // 8


def bpp_for_pre0(pre0):
    return BPP_FOR_CODE[pre0 & 0x7]


def decode_packed_cel(data, source_ptr, width, height, bpp):
    """Decode a packed cel's pixel data.

    Returns (pixels, end_offset) where `pixels` is a bytes of length
    width*height (palette indices, one byte per pixel -- valid for bpp <= 8,
    which is everything observed in this file) and `end_offset` is the
    file offset just past the last byte the decode touched, for diagnostics.
    """
    offsetl = 1 if bpp < 8 else 2
    table_size = height * offsetl

    row_offsets = []
    for row in range(height):
        o = source_ptr + row * offsetl
        if offsetl == 1:
            val = data[o]
        else:
            val = data[o] | (data[o + 1] << 8)  # little-endian
        row_offsets.append(val)

    pixels = bytearray(width * height)  # 0 = transparent, matches confirmed alpha rule
    max_end = source_ptr + table_size

    for row, val in enumerate(row_offsets):
        if val == 0:
            continue  # fully transparent row -- nothing to decode
        reader = _BitReader(data, source_ptr + val)
        col = 0
        ops = 0
        while col < width:
            ops += 1
            if ops > 4 * width + 16:
                raise PackedCelError("runaway opcode loop at row %d" % row)
            typ = reader.read(2)
            cnt = reader.read(6) + 1
            if typ == 0:  # end of row -- rest stays transparent
                break
            elif typ == 1:  # literal run
                n = min(cnt, width - col)
                for _ in range(n):
                    pixels[row * width + col] = reader.read(bpp)
                    col += 1
                if cnt > n:
                    reader.skip(bpp * (cnt - n))
            elif typ == 2:  # transparent-skip run
                col += min(cnt, width - col)
            elif typ == 3:  # repeat-pixel run
                v = reader.read(bpp)
                n = min(cnt, width - col)
                for _ in range(n):
                    pixels[row * width + col] = v
                    col += 1
        max_end = max(max_end, reader.byte_pos())

    return bytes(pixels), max_end
