"""Decoder for ART.CAR's 93 "PRE0 != 0" cels -- CONFIRMED, supersedes rfcel.py.

`rfcel.py`'s hypothesis (a literal-run/skip-run/repeat-run bit-packed opcode
stream, i.e. actual compressed per-pixel COLOR data) was wrong -- it produced
noise, not sprites, and was never trusted (see docs/PORTING_PLAN.md section
1.6's standing lesson: "a plausible byte count is not a correctness proof").

**What these 93 cels actually are, reverse engineered from RFIRE.BIN's real
renderer via Ghidra (2026-09-04):** not sprites at all. They are COVERAGE
MASKS for a masked palette-translation blend effect (shadows, scorch marks,
structure footprints, glow blobs, etc.) -- the mask says WHERE to draw, and
the colour comes from remapping whatever is ALREADY on screen underneath
through a small runtime-built/loaded 256-byte translation table (loaded from
"Art\\Trans.tbl" if present, else generated -- see `FUN_00424420`, not fully
traced), not from any colour stored in the cel itself. Concretely, for every
covered pixel the renderer does `dest[x,y] = TransTable[dest[x,y]]` -- an
in-place recolour of the background, gated by the mask.

Traced end-to-end from the real per-frame cel dispatcher (`FUN_00418ef0`,
switches on the CCB's raw 32-bit `PRE0` field -- NOT `PRE0 & 7` as an earlier
draft of this investigation assumed) down to the two pixel-writing routines,
and validated by decoding and eyeballing real cels: both produce clean,
structured silhouettes (a blob/splat shape for a PRE0=13 cel, a rectangular
notched-block shape for a PRE0=1 cel), not noise.

Every nonzero PRE0 value actually present in ART.CAR (confirmed by scanning
all 2165 CCBs directly, not inferred): 1 (x11), 2 (x21), 3 (x9), 5 (x2),
13/0x0D (x46), 17/0x11 (x4) -- 93 total, exactly matching the known count.
Two distinct mask encodings, selected by which of those values PRE0 holds:

  MASK_FAMILY_LINEAR = {1, 2, 3, 4, 5, 17}   (4 not observed in real data but
                                               handled identically -- see
                                               FUN_00418ef0 case 4)
    The mask is a plain Width*Height byte array at SourcePtr, exactly like
    an ordinary unpacked cel -- one byte per pixel, 0 = not covered, nonzero
    = covered. (Confirmed: cel 217, PRE0=1, 64x64, decodes to a clean
    rectangular notched-block silhouette reading it this way.)

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

Which shared translation table a linear-family cel uses (irrelevant for the
mask itself, but recorded per cel in case Godot-side code wants to
approximate the resulting tint later): PRE0 1->table A, 2->table B, 3 or
4->table C, 5->table D. PRE0=13 (span family) also uses table A. PRE0=17 is
special: it uses the CEL'S OWN embedded PLUT as the remap source instead of
one of the 4 shared tables (`FUN_00418ef0` case 0x11 sets the remap pointer
to `*(CCB+0xc)`, i.e. the CCB's own PLUTPtr field). The 4 shared tables
themselves live in runtime BSS (all zero in the static binary -- they are
filled in by `FUN_00424420` at startup, not stored as file data) and were
NOT extracted this pass; this converter therefore cannot reproduce the exact
on-screen colour of these effects yet, only their shape/coverage.
"""

import struct

MASK_FAMILY_LINEAR = {1, 2, 3, 4, 5, 17}
MASK_FAMILY_SPAN = {13}

# Informational only (see docstring) -- which shared table a cel's blend uses.
_TABLE_FOR_PRE0 = {1: "A", 2: "B", 3: "C", 4: "C", 5: "D", 13: "A", 17: "own_plut"}


class EffectCelError(Exception):
    pass


def table_for_pre0(pre0):
    return _TABLE_FOR_PRE0.get(pre0, "unknown")


def decode_linear_mask(data, source_ptr, width, height):
    """PRE0 in MASK_FAMILY_LINEAR: plain Width*Height byte mask, 0/nonzero."""
    n = width * height
    if source_ptr + n > len(data):
        raise EffectCelError(
            "linear mask runs past end of file (source_ptr=0x%X, need %d bytes)" % (source_ptr, n)
        )
    return bytes(255 if b else 0 for b in data[source_ptr:source_ptr + n])


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
    convert_car.py's CCB_FIELDS). Returns a Width*Height bytes mask (0 or
    255 per pixel) plus which shared translation table it nominally uses."""
    pre0 = ccb["PRE0"]
    w, h, src = ccb["Width"], ccb["Height"], ccb["SourcePtr"]
    if pre0 in MASK_FAMILY_LINEAR:
        mask = decode_linear_mask(data, src, w, h)
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
