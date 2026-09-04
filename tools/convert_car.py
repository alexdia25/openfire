"""Phase 1c: convert Return Fire ART/ART.CAR to a sprite atlas + JSON manifest.

ART.CAR is a 3DO Cel Control Block array, flattened for the PC port:

    0x000000  char[4]  "CCBA"
    0x000004  u32      total file size
    0x000008  u32      cel count
    0x00000C  u32      end of CCB array (== 16 + count*68)
    0x000010  CCB[count], 68 bytes each (17 x u32 LE)
    <dataoff> u32[count][2]  purpose unknown, values mostly 5
    ...       PLUT palettes, then cel pixel data addressed by SourcePtr

Most cels (2072 of 2165) are 8bpp unpacked linear: exactly Width*Height bytes
at SourcePtr, PRE0 == 0 -- these are real sprite art and go into art_atlas.png.
The remaining 93 have PRE0 != 0 and are NOT sprites at all: they are coverage
masks for a masked palette-translation blend effect (shadow/scorch/glow-style
compositing that recolours whatever's already on screen underneath, rather
than drawing stored colour) -- see rf_effect_cel.py for the full writeup of
how this was confirmed from RFIRE.BIN's real renderer via Ghidra. Their masks
are extracted into a separate small atlas, art_effects.png / .json, since
they don't belong in the sprite atlas and Godot-side code needs to treat
them as a blend effect, not a normal texture.
PLUTs are Windows RGBQUAD (B, G, R, pad) -- NOT 3DO RGB555.

Usage:
    python convert_car.py <returnfire_dir> <out_dir> [--atlas-width N]
                                                     [--padding N]
                                                     [--opaque-zero]
"""

import json
import os
import struct
import sys

from rf_effect_cel import EffectCelError, decode_effect_mask
from rfpng import write_png_rgba

CCB_SIZE = 68
CCB_FIELDS = (
    "Flags", "NextPtr", "SourcePtr", "PLUTPtr",
    "XPos", "YPos", "HDX", "HDY",
    "VDX", "VDY", "HDDX", "HDDY",
    "PIXC", "PRE0", "PRE1", "Width", "Height",
)


def read_palette(data, offset, count=256):
    """Read `count` RGBQUAD entries (B, G, R, pad) at `offset`."""
    pal = []
    for i in range(count):
        o = offset + i * 4
        if o + 4 > len(data):
            pal.append((0, 0, 0))
            continue
        b, g, r = data[o], data[o + 1], data[o + 2]
        pal.append((r, g, b))
    return pal


def main():
    argv = sys.argv[1:]
    args = []
    atlas_width = 2048
    padding = 1
    opaque_zero = False

    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--atlas-width":
            atlas_width = int(argv[i + 1]); i += 2
        elif a == "--padding":
            padding = int(argv[i + 1]); i += 2
        elif a == "--opaque-zero":
            opaque_zero = True; i += 1
        else:
            args.append(a); i += 1

    if len(args) != 2:
        print(__doc__)
        return 2

    src_root, out_dir = args
    car_path = os.path.join(src_root, "ART", "ART.CAR")
    if not os.path.isfile(car_path):
        print("error: %s not found" % car_path)
        return 1

    os.makedirs(out_dir, exist_ok=True)
    with open(car_path, "rb") as f:
        data = f.read()

    # ---- header -----------------------------------------------------------
    if data[:4] != b"CCBA":
        print("error: bad magic %r, expected b'CCBA'" % data[:4])
        return 1

    total, count, dataoff = struct.unpack_from("<III", data, 4)
    print("ART.CAR: %d cels, declared size %d (actual %d), CCB array ends at 0x%X"
          % (count, total, len(data), dataoff))
    if total != len(data):
        print("   WARNING: declared size does not match actual file size")
    if 16 + count * CCB_SIZE != dataoff:
        print("   WARNING: 16 + count*68 (%d) != dataoff (%d)"
              % (16 + count * CCB_SIZE, dataoff))

    # ---- CCB array --------------------------------------------------------
    cels = []
    for n in range(count):
        vals = struct.unpack_from("<17I", data, 16 + n * CCB_SIZE)
        cels.append(dict(zip(CCB_FIELDS, vals)))

    effect_count = sum(1 for c in cels if c["PRE0"] != 0)
    if effect_count:
        print("   %d cels are PRE0 != 0 -- these are blend-effect masks, not sprite "
              "art (see rf_effect_cel.py). Extracted separately to art_effects.png / "
              ".json, excluded from the sprite atlas." % effect_count)

    # ---- palettes ---------------------------------------------------------
    plut_offsets = sorted({c["PLUTPtr"] for c in cels})
    palettes = {off: read_palette(data, off) for off in plut_offsets}
    print("   %d distinct PLUT(s): %s"
          % (len(plut_offsets), ", ".join("0x%X" % o for o in plut_offsets)))

    # ---- extract pixels + index-0 diagnostics -----------------------------
    # Open question from the plan: is index 0 the transparent colour? Rather
    # than assume, measure where index-0 pixels actually fall. If index 0 is
    # transparency, it should be strongly biased toward cel borders.
    border_zero = border_total = 0
    interior_zero = interior_total = 0
    skipped = []
    effect_decoded = 0
    effect_failed = []

    for n, c in enumerate(cels):
        w, h, src = c["Width"], c["Height"], c["SourcePtr"]
        c["_pixels"] = None
        c["_effect_mask"] = None
        if w <= 0 or h <= 0:
            skipped.append(n)
            continue

        if c["PRE0"] != 0:
            # Not sprite art -- a blend-effect mask. Extracted separately below
            # into art_effects.png, never placed in the sprite atlas.
            try:
                mask, table = decode_effect_mask(data, c)
                c["_effect_mask"] = mask
                c["_effect_table"] = table
                effect_decoded += 1
            except EffectCelError as e:
                effect_failed.append((n, str(e)))
            continue

        if src + w * h > len(data):
            skipped.append(n)
            continue
        px = data[src:src + w * h]
        c["_pixels"] = px

        for y in range(h):
            row = px[y * w:(y + 1) * w]
            edge_row = (y == 0 or y == h - 1)
            for x in range(w):
                is_border = edge_row or x == 0 or x == w - 1
                if is_border:
                    border_total += 1
                    if row[x] == 0:
                        border_zero += 1
                else:
                    interior_total += 1
                    if row[x] == 0:
                        interior_zero += 1

    if effect_count:
        print("   effect-mask cels decoded: %d / %d" % (effect_decoded, effect_count))
        if effect_failed:
            print("   effect-mask cels that raised during decode (%d):" % len(effect_failed))
            for n, err in effect_failed:
                print("      cel %d: %s" % (n, err))
    if skipped:
        print("   WARNING: %d sprite cels skipped (out-of-range SourcePtr or bad dims)"
              % len(skipped))

    b_pct = (100.0 * border_zero / border_total) if border_total else 0.0
    i_pct = (100.0 * interior_zero / interior_total) if interior_total else 0.0
    print("\nindex-0 diagnostic (is palette index 0 transparent?)")
    print("   border pixels   that are index 0: %5.1f%%" % b_pct)
    print("   interior pixels that are index 0: %5.1f%%" % i_pct)
    if b_pct > i_pct * 2 and b_pct > 20:
        print("   -> strongly border-biased: index 0 behaves like transparency")
    elif b_pct < 5 and i_pct < 5:
        print("   -> index 0 barely used: sprites may already be tightly cropped")
    else:
        print("   -> INCONCLUSIVE: inspect the atlas before trusting alpha")

    # ---- shelf-pack into an atlas ----------------------------------------
    order = sorted(
        (n for n in range(count) if cels[n]["_pixels"] is not None),
        key=lambda n: (-cels[n]["Height"], -cels[n]["Width"]),
    )

    placements = {}
    x = y = shelf_h = 0
    for n in order:
        w, h = cels[n]["Width"], cels[n]["Height"]
        if x + w + padding > atlas_width:
            x = 0
            y += shelf_h + padding
            shelf_h = 0
        placements[n] = (x, y)
        x += w + padding
        shelf_h = max(shelf_h, h)
    atlas_h = y + shelf_h

    # round height up to a power of two for GPU friendliness
    pot = 1
    while pot < atlas_h:
        pot *= 2
    atlas_h = pot

    print("\natlas: %d x %d, %d cels packed" % (atlas_width, atlas_h, len(placements)))

    buf = bytearray(atlas_width * atlas_h * 4)
    for n, (px_x, px_y) in placements.items():
        c = cels[n]
        w, h, px = c["Width"], c["Height"], c["_pixels"]
        pal = palettes[c["PLUTPtr"]]
        for row_y in range(h):
            row = px[row_y * w:(row_y + 1) * w]
            dst = ((px_y + row_y) * atlas_width + px_x) * 4
            for col_x in range(w):
                idx = row[col_x]
                r, g, b = pal[idx]
                a = 0 if (idx == 0 and not opaque_zero) else 255
                o = dst + col_x * 4
                buf[o] = r
                buf[o + 1] = g
                buf[o + 2] = b
                buf[o + 3] = a

    atlas_name = "art_atlas.png"
    write_png_rgba(os.path.join(out_dir, atlas_name), atlas_width, atlas_h, buf)

    # ---- shelf-pack effect masks into a second, separate atlas ------------
    # Not sprite art -- see rf_effect_cel.py. Packed white-on-transparent so a
    # Godot shader can tint the covered area at runtime; the true colour
    # requires the runtime-built translation table this converter does not
    # have (see rf_effect_cel.py docstring).
    effect_order = sorted(
        (n for n in range(count) if cels[n]["_effect_mask"] is not None),
        key=lambda n: (-cels[n]["Height"], -cels[n]["Width"]),
    )
    effect_placements = {}
    ex = ey = eshelf_h = 0
    for n in effect_order:
        w, h = cels[n]["Width"], cels[n]["Height"]
        if ex + w + padding > atlas_width:
            ex = 0
            ey += eshelf_h + padding
            eshelf_h = 0
        effect_placements[n] = (ex, ey)
        ex += w + padding
        eshelf_h = max(eshelf_h, h)
    effect_atlas_h = ey + eshelf_h
    pot = 1
    while pot < effect_atlas_h:
        pot *= 2
    effect_atlas_h = max(pot, 1)

    print("effects atlas: %d x %d, %d effect masks packed"
          % (atlas_width, effect_atlas_h, len(effect_placements)))

    effect_buf = bytearray(atlas_width * effect_atlas_h * 4)
    for n, (px_x, px_y) in effect_placements.items():
        c = cels[n]
        w, h, mask = c["Width"], c["Height"], c["_effect_mask"]
        for row_y in range(h):
            row = mask[row_y * w:(row_y + 1) * w]
            dst = ((px_y + row_y) * atlas_width + px_x) * 4
            for col_x in range(w):
                covered = row[col_x]
                o = dst + col_x * 4
                effect_buf[o] = effect_buf[o + 1] = effect_buf[o + 2] = 255
                effect_buf[o + 3] = covered

    effect_atlas_name = "art_effects.png"
    if effect_placements:
        write_png_rgba(os.path.join(out_dir, effect_atlas_name), atlas_width, effect_atlas_h, effect_buf)

    # ---- manifest ---------------------------------------------------------
    manifest = {
        "source": "ART.CAR",
        "cel_count": count,
        "atlas": atlas_name,
        "atlas_width": atlas_width,
        "atlas_height": atlas_h,
        "transparent_index": None if opaque_zero else 0,
        "skipped_cels": skipped,
        "effects_atlas": effect_atlas_name if effect_placements else None,
        "effects_atlas_width": atlas_width if effect_placements else None,
        "effects_atlas_height": effect_atlas_h if effect_placements else None,
        "cels": [],
    }
    for n, c in enumerate(cels):
        entry = {
            "index": n,
            "w": c["Width"],
            "h": c["Height"],
            "flags": c["Flags"],
            "plut": c["PLUTPtr"],
            "source_ptr": c["SourcePtr"],
            "pre0": c["PRE0"],
        }
        if n in placements:
            entry["kind"] = "sprite"
            entry["x"], entry["y"] = placements[n]
        elif n in effect_placements:
            entry["kind"] = "effect_mask"
            entry["blend_table"] = c["_effect_table"]
            entry["x"], entry["y"] = effect_placements[n]
        else:
            entry["kind"] = "skipped"
            entry["x"] = entry["y"] = None
        manifest["cels"].append(entry)

    with open(os.path.join(out_dir, "art_atlas.json"), "w") as f:
        json.dump(manifest, f, indent=1)

    # Flags carried through so the unexplained 0x20 bit can be investigated.
    flag_counts = {}
    for c in cels:
        flag_counts[c["Flags"]] = flag_counts.get(c["Flags"], 0) + 1
    print("\ndistinct Flags values (bit 0x20 meaning still unknown):")
    for fl, cnt in sorted(flag_counts.items(), key=lambda kv: -kv[1]):
        print("   0x%08X  x%d" % (fl, cnt))

    extra = (" and %s" % effect_atlas_name) if effect_placements else ""
    print("\nwrote %s%s and art_atlas.json to %s" % (atlas_name, extra, out_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
