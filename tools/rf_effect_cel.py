"""Decoder for ART.CAR's PRE0 != 0 blend-effect cels -- CONFIRMED, supersedes rfcel.py.

`rfcel.py`'s hypothesis (a literal-run/skip-run/repeat-run bit-packed opcode
stream, i.e. actual compressed per-pixel COLOR data) was wrong -- it produced
noise, not sprites, and was never trusted (see docs/PORTING_PLAN.md section
1.6's standing lesson: "a plausible byte count is not a correctness proof").

**What these cels actually are, reverse engineered from RFIRE.BIN's real
renderer via Ghidra (2026-09-04, tint mechanism fully traced 2026-09-05):**
89 of the 93 non-zero-`PRE0` cels (all but the 4 `PRE0==17` ones -- see below)
are COVERAGE MASKS for a masked palette-translation blend effect (shadows,
colour tints, glow blobs) -- the mask says WHERE to draw, and the colour
comes from remapping whatever is ALREADY on screen underneath through one of
4 shared 256-entry translation tables built/loaded once at startup
(`FUN_00424420`; tries `Art\\Trans.tbl` first, generates one if missing/
invalid), not from any colour stored in the cel itself.

Traced end-to-end from the real per-frame cel dispatcher (`FUN_00418ef0`,
switches on the CCB's raw 32-bit `PRE0` field -- NOT `PRE0 & 7` as an earlier
draft of this investigation assumed) down through the three mask-blit
routines, and validated by decoding and eyeballing real cels: they produce
clean, structured silhouettes (a blob/splat shape for a PRE0=13 cel, a
rectangular notched-block shape for a PRE0=1 cel), not noise.

**How the 4 shared tables are built (`FUN_00424420`'s fallback-generation
path, when `Art\\Trans.tbl` is absent or fails its version check), and what
each one actually is** -- this was the missing piece behind "the mask shape
is solved but not the exact tint colour" (PORTING_PLAN.md section 1.6/4, now
resolved):

  1. A 256-colour "master palette" is realized as a real Win32 `HPALETTE`
     (`DAT_0046a8f4`) from a block of raw file bytes sitting right after cel
     0's own PLUT (`ART.CAR`'s main palette, `+0x400` bytes past it) --
     `ART.CAR` embeds this ready-made LOGPALETTE-shaped table for exactly
     this purpose, it is not built from scratch.
  2. `DAT_0046aa0c`: a full 256x256 = 65536-byte table, filled by
     `aa0c[i*256+j] = GetNearestPaletteIndex(masterPalette, average(pal[i], pal[j]))`
     for every pair of palette indices `i, j` -- i.e. "the palette entry
     closest to a 50% blend of colours i and j", for *any* pair. This is a
     general-purpose colour-tint table: pick a row `i` (the colour to tint
     toward) and every column `j` (a background colour) gives the tinted
     result.
  3. `DAT_0046aa20`: a 32x256 = 8192-byte "darken" table -- 32 brightness
     levels from ~97% down to 0%, each level a full 256-entry remap of every
     palette colour to its darkened equivalent (also via `GetNearestPaletteIndex`).
  4. `DAT_0046aa14`: a 32x256 = 8192-byte "brighten" table -- 32 levels of
     +3 to +96 per RGB channel (clamped at 255), same construction.
  5. `DAT_0046a8f0` and `DAT_0046aa08` are NOT separate tables at all -- they
     are fixed ROWS 4 and 2 of the darken table above (~84% and ~91%
     brightness respectively), kept as named pointers because they are the
     two constant "shadow strength" tables the game actually uses.

**Per-`PRE0`-value semantics, confirmed against the real per-pixel formula in
each blit routine AND against the real mask byte values in every one of the
93 real cels** (this second check mattered: it caught that the mask byte's
*value*, not just whether it's zero, carries real information for 3 of the
6 `PRE0` values):

  - **`PRE0` 1** (11 cels) -- `FUN_00419920`: `dest = darken_row4[dest]`
    wherever mask != 0. A flat, single-strength shadow. Real mask bytes:
    exactly `{0, 11}` in every cel checked -- genuinely binary, coverage only.
  - **`PRE0` 2** (21 cels) -- same routine, `dest = darken_row2[dest]`. A
    flat, slightly lighter shadow. Real mask bytes: exactly `{0, 243}` --
    also genuinely binary.
  - **`PRE0` 3 (and the unobserved 4)** (9 real cels) -- `FUN_00419af0`:
    `dest = aa0c[mask_value*256 + dest]`. The mask's raw BYTE VALUE selects
    the tint-target row of the full 256x256 table -- **the mask is not
    boolean here, it stores which palette colour to tint the background
    toward, per pixel.** Confirmed: real `PRE0==3` cels have 8-10 distinct
    nonzero byte values each, clustered in a narrow band (e.g. 35-51), not
    a single constant -- exactly consistent with "this is a real palette
    index," not a coverage flag.
  - **`PRE0` 5** (2 cels) -- same routine, `dest = brighten[mask_value*256 + dest]`.
    The mask value selects a brightness LEVEL (0-31 range of the 32-row
    brighten table) -- a genuine per-pixel glow gradient. Confirmed: the 2
    real `PRE0==5` cels have 16-25 distinct nonzero values each, spanning a
    continuous 0-24ish range -- a real gradient, not a flag. This is almost
    certainly the "explosion starburst / glow" effect.
  - **`PRE0` 13** (46 cels, span-encoded, the majority) -- `FUN_004109a0`:
    `dest = darken_row4[dest]` for every covered span -- the SAME fixed
    shadow table as `PRE0` 1, just span-encoded instead of a flat bitmap.
    Being the majority and using the shadow table strongly suggests this is
    specifically the vehicle/structure DROP SHADOW shape.
  - **`PRE0` 17** (4 cels) -- **not a coverage mask at all.** `FUN_00419ea0`
    does `dest = OwnPLUT[mask_value]`, a direct indexed-colour lookup
    through the CEL'S OWN embedded palette (`*(CCB+0xc)`, its own
    `PLUTPtr`) with the standard index-0-transparent convention -- there is
    no background blending. Structurally this is an ordinary sprite, not an
    effect; `convert_car.py` extracts these 4 as real sprites, not masks.
    This also fully explains section 1.6's previously-unexplained "3
    distinct PLUTPtr values" oddity: the 2 oddball PLUTs (`0x28AD0`,
    `0x28AE0`, 2 cels each) belong exactly to these 4 cels. Rendered through
    their own palette, all 4 are fully opaque 16x16 blocks of a handful of
    highly saturated, unrelated-looking colours -- visually this reads more
    like a small colour swatch than in-world art (a plausible, UNCONFIRMED
    lead for how team/UI accent colours might work -- see PORTING_PLAN.md
    section 4 open question on team colouring), but no code path referencing
    these specific 4 cels has been traced yet, so treat that as a guess.

Two mask *shape* encodings, orthogonal to the tint semantics above:

  MASK_FAMILY_LINEAR = {1, 2, 3, 4, 5}
    The mask is a plain Width*Height byte array at SourcePtr, exactly like
    an ordinary unpacked cel -- one byte per pixel. For PRE0 1/2 only the
    zero/nonzero distinction matters (see above); for PRE0 3/4/5 the actual
    byte value matters too, and is preserved rather than collapsed to a
    boolean (see `decode_linear_mask`'s `preserve_value` below).

  MASK_FAMILY_SPAN = {13}
    SourcePtr points to a table of Height little-endian u16 row offsets (the
    same row-table structure rfcel.py found -- that part of the earlier
    investigation WAS correct), each either 0 (row fully uncovered) or an
    offset from SourcePtr to that row's span list: repeating (x0_byte,
    x1_byte) pairs, terminated by a pair whose first byte is 0. x0/x1 are
    NOT literal pixel columns -- they are 0-255 values proportional across
    the row (`FUN_004109a0` maps them through the CCB's affine HDX/edge
    deltas at render time; for an unscaled 1:1 read, scale linearly to
    [0, Width-1]). Each pair means "cover columns x0..x1 on this row".
    (Confirmed: cel 120, PRE0=13, 16x16, decodes to a clean roughly-circular
    splat/blob silhouette with this scheme.)
"""

import struct

MASK_FAMILY_LINEAR = {1, 2, 3, 4, 5}
MASK_FAMILY_SPAN = {13}

# PRE0 values whose mask byte VALUE (not just zero/nonzero) is meaningful --
# it selects a row (tint colour or brightness level) in a 2D table rather
# than acting as a plain coverage flag. See docstring.
_VALUE_MEANINGFUL_PRE0 = {3, 4, 5}

# Informational -- which shared table a cel's blend uses (see docstring for
# what each one actually contains; A/B are fixed shadow-strength rows of the
# darken table, C/D are the full variable-row tables).
_TABLE_FOR_PRE0 = {1: "A", 2: "B", 3: "C", 4: "C", 5: "D", 13: "A"}


class EffectCelError(Exception):
    pass


def table_for_pre0(pre0):
    return _TABLE_FOR_PRE0.get(pre0, "unknown")


def decode_linear_mask(data, source_ptr, width, height, preserve_value=False):
    """PRE0 in MASK_FAMILY_LINEAR: plain Width*Height byte mask.

    For PRE0 1/2, only zero/nonzero matters (a plain coverage flag) --
    collapse to 0/255. For PRE0 3/4/5 (`preserve_value=True`), the real
    renderer uses the byte's actual magnitude as a row selector into a 2D
    translation table (see module docstring), so it's returned unmodified.
    """
    n = width * height
    if source_ptr + n > len(data):
        raise EffectCelError(
            "linear mask runs past end of file (source_ptr=0x%X, need %d bytes)" % (source_ptr, n)
        )
    raw = data[source_ptr:source_ptr + n]
    if preserve_value:
        return bytes(raw)
    return bytes(255 if b else 0 for b in raw)


def decode_span_mask(data, source_ptr, width, height):
    """PRE0 == 13: row-offset table + per-row (x0, x1) span list, proportionally
    scaled from the stored 0-255 range to [0, width-1]."""
    if source_ptr + height * 2 > len(data):
        raise EffectCelError("span mask row table runs past end of file")
    mask = bytearray(width * height)
    for row in range(height):
        row_off = struct.unpack_from("<H", data, source_ptr + row * 2)[0]
        if row_off == 0:
            continue
        ptr = source_ptr + row_off
        guard = 0
        while True:
            guard += 1
            if guard > 512:
                raise EffectCelError("span mask row %d exceeded 512 spans -- corrupt?" % row)
            if ptr + 2 > len(data):
                raise EffectCelError("span mask row %d span pair runs past end of file" % row)
            x0, x1 = data[ptr], data[ptr + 1]
            if x0 == 0:
                break
            sx0 = round(x0 / 255.0 * (width - 1))
            sx1 = round(x1 / 255.0 * (width - 1))
            if sx0 > sx1:
                sx0, sx1 = sx1, sx0
            row_base = row * width
            for x in range(max(sx0, 0), min(sx1 + 1, width)):
                mask[row_base + x] = 255
            ptr += 2
    return bytes(mask)


def decode_effect_mask(data, ccb):
    """ccb: dict with at least PRE0, SourcePtr, Width, Height (matching
    convert_car.py's CCB_FIELDS). Returns a Width*Height bytes mask plus
    which shared translation table it nominally uses. For PRE0 1/2/13 the
    mask is 0/255 (plain coverage); for PRE0 3/4/5 the real byte value
    (0-255) is preserved -- see module docstring for why.

    PRE0 == 17 is NOT a coverage mask (see docstring) and must not reach
    this function -- convert_car.py routes it through the ordinary sprite
    path instead, using the cel's own embedded PLUT like any other sprite.
    """
    pre0 = ccb["PRE0"]
    w, h, src = ccb["Width"], ccb["Height"], ccb["SourcePtr"]
    if pre0 in MASK_FAMILY_LINEAR:
        mask = decode_linear_mask(data, src, w, h, preserve_value=pre0 in _VALUE_MEANINGFUL_PRE0)
    elif pre0 in MASK_FAMILY_SPAN:
        mask = decode_span_mask(data, src, w, h)
    else:
        raise EffectCelError("unrecognized PRE0 value %d (0x%X) -- not seen in real data" % (pre0, pre0))
    return mask, table_for_pre0(pre0)


if __name__ == "__main__":
    # Self-test against the real file, printing an ASCII render of two known
    # examples (one per family) so the decode can be eyeballed.
    import sys

    path = sys.argv[1] if len(sys.argv) > 1 else r"C:\Users\Alex\Documents\returnfire\ART\ART.CAR"
    with open(path, "rb") as f:
        data = f.read()
    count = struct.unpack_from("<I", data, 8)[0]
    fields = ("Flags", "NextPtr", "SourcePtr", "PLUTPtr", "XPos", "YPos", "HDX", "HDY",
              "VDX", "VDY", "HDDX", "HDDY", "PIXC", "PRE0", "PRE1", "Width", "Height")

    def get_ccb(idx):
        vals = struct.unpack_from("<17I", data, 16 + idx * 68)
        return dict(zip(fields, vals))

    shown = {"span": False, "linear": False}
    for idx in range(count):
        ccb = get_ccb(idx)
        pre0 = ccb["PRE0"]
        fam = "span" if pre0 in MASK_FAMILY_SPAN else ("linear" if pre0 in MASK_FAMILY_LINEAR else None)
        if fam is None or shown[fam]:
            continue
        mask, table = decode_effect_mask(data, ccb)
        w, h = ccb["Width"], ccb["Height"]
        print(f"cel {idx}: PRE0={pre0} family={fam} table={table} {w}x{h}")
        for y in range(h):
            print("".join("#" if mask[y * w + x] else "." for x in range(w)))
        print()
        shown[fam] = True
        if all(shown.values()):
            break
