"""Phase 1c: convert Return Fire ART/ART.CAR to a sprite atlas + JSON manifest.

ART.CAR is a 3DO Cel Control Block array, flattened for the PC port:

    0x000000  char[4]  "CCBA"
    0x000004  u32      total file size
    0x000008  u32      cel count
    0x00000C  u32      end of CCB array (== 16 + count*68)
    0x000010  CCB[count], 68 bytes each (17 x u32 LE)
    <dataoff> u32[count][2]  purpose unknown, values mostly 5
    ...       PLUT palettes, then cel pixel data addressed by SourcePtr

Cels are 8bpp unpacked linear: exactly Width*Height bytes at SourcePtr.
PRE0/PRE1 are zero for every cel and carry no format info.
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

    nonzero_pre = sum(1 for c in cels if c["PRE0"] or c["PRE1"])
    if nonzero_pre:
        print("   WARNING: %d cels have non-zero PRE0/PRE1 -- format assumption "
              "may not hold for them" % nonzero_pre)

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

    for n, c in enumerate(cels):
        w, h, src = c["Width"], c["Height"], c["SourcePtr"]
        if w <= 0 or h <= 0 or src + w * h > len(data):
            skipped.append(n)
            c["_pixels"] = None
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

    if skipped:
        print("   WARNING: %d cels skipped (out-of-range SourcePtr or bad dims)"
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

    # ---- manifest ---------------------------------------------------------
    manifest = {
        "source": "ART.CAR",
        "cel_count": count,
        "atlas": atlas_name,
        "atlas_width": atlas_width,
        "atlas_height": atlas_h,
        "transparent_index": None if opaque_zero else 0,
        "skipped_cels": skipped,
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
        }
        if n in placements:
            entry["x"], entry["y"] = placements[n]
        else:
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

    print("\nwrote %s and art_atlas.json to %s" % (atlas_name, out_dir))
    return 0


if __name__ == "__main__":
    sys.exit(main())
