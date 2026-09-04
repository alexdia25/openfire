"""Phase 1b: convert Return Fire .RFA art files to .png.

The .RFA files are plain uncompressed Windows BMPs with a renamed extension
(4bpp or 8bpp). The only trap is the palette size: it is NOT always 256 entries,
so the pixel offset must be read from bfOffBits rather than assumed. See
read_bmp() in rfpng.py.

Usage:
    python convert_rfa.py <returnfire_dir> <out_dir> [--transparent-index N]
"""

import os
import sys

from rfpng import BmpError, indices_to_rgba, read_bmp, write_png_rgba


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 2:
        print(__doc__)
        return 2

    transparent = None
    if "--transparent-index" in sys.argv:
        transparent = int(sys.argv[sys.argv.index("--transparent-index") + 1])

    src_root, out_dir = args
    art_dir = os.path.join(src_root, "ART")
    if not os.path.isdir(art_dir):
        print("error: no ART directory under %s" % src_root)
        return 1

    os.makedirs(out_dir, exist_ok=True)

    ok = 0
    flagged = []

    for name in sorted(os.listdir(art_dir)):
        if not name.upper().endswith(".RFA"):
            continue
        with open(os.path.join(art_dir, name), "rb") as f:
            data = f.read()

        try:
            w, h, indices, palette = read_bmp(data)
        except BmpError as e:
            flagged.append("%s: %s" % (name, e))
            continue

        rgba = indices_to_rgba(indices, palette, transparent_index=transparent)
        out_name = os.path.splitext(name)[0] + ".png"
        write_png_rgba(os.path.join(out_dir, out_name), w, h, rgba)
        print("   %-16s %4d x %-4d  %3d palette entries" % (name, w, h, len(palette)))
        ok += 1

    print("\nconverted %d .RFA -> .png in %s" % (ok, out_dir))
    if flagged:
        print("FLAGGED (%d):" % len(flagged))
        for line in flagged:
            print("   " + line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
