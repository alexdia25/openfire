"""Build labelled contact sheets from build/car/art_atlas.(png|json) for visual
asset-ID classification (PORTING_PLAN.md section 2.4.1).

Not a converter -- a classification aid. Reads build/ only, writes only to the
scratchpad (or wherever --out points), never into the repo or /build/.

Usage:
    python tools/registry/contact_sheet.py --indices 0-111 --cols 12 --cell 64 --out sheet.png
    python tools/registry/contact_sheet.py --indices 1969,1970,1971,1972 --cell 128 --out reticles.png
    python tools/registry/contact_sheet.py --kind sprite --unclassified --cols 20 --cell 48 --out batch01.png --limit 400 --start 112
"""
import argparse
import json
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ATLAS_JSON = os.path.join(ROOT, "build", "car", "art_atlas.json")
ATLAS_PNG = os.path.join(ROOT, "build", "car", "art_atlas.png")
EFFECTS_PNG = os.path.join(ROOT, "build", "car", "art_effects.png")
REGISTRY_JSON = os.path.join(ROOT, "packs", "registry", "asset_ids.json")


def parse_indices(spec):
    out = []
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            a, b = part.split("-")
            out.extend(range(int(a), int(b) + 1))
        else:
            out.append(int(part))
    return out


def load_registry_classified():
    if not os.path.exists(REGISTRY_JSON):
        return set()
    with open(REGISTRY_JSON) as f:
        reg = json.load(f)
    return {int(k) for k in reg.get("cels", {}).keys()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--indices", help="e.g. '0-111' or '1969,1970'")
    ap.add_argument("--kind", choices=["sprite", "effect_mask"], help="filter by cel kind")
    ap.add_argument("--pre0", type=int, help="filter by exact pre0 value")
    ap.add_argument("--unclassified", action="store_true", help="exclude indices already in the registry")
    ap.add_argument("--start", type=int, default=0)
    ap.add_argument("--limit", type=int, default=500)
    ap.add_argument("--cols", type=int, default=16)
    ap.add_argument("--cell", type=int, default=48, help="each cel is letterboxed into a cell x cell box")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with open(ATLAS_JSON) as f:
        atlas = json.load(f)
    cels = atlas["cels"]

    if args.indices:
        indices = parse_indices(args.indices)
    else:
        indices = [c["index"] for c in cels]

    if args.kind:
        kind_set = {c["index"] for c in cels if c["kind"] == args.kind}
        indices = [i for i in indices if i in kind_set]
    if args.pre0 is not None:
        pre0_set = {c["index"] for c in cels if c.get("pre0") == args.pre0}
        indices = [i for i in indices if i in pre0_set]
    if args.unclassified:
        done = load_registry_classified()
        indices = [i for i in indices if i not in done]

    indices = indices[args.start:args.start + args.limit]
    if not indices:
        print("no cels matched")
        return

    sprite_atlas = Image.open(ATLAS_PNG).convert("RGBA")
    effects_atlas = Image.open(EFFECTS_PNG).convert("RGBA") if os.path.exists(EFFECTS_PNG) else None

    cel_by_index = {c["index"]: c for c in cels}

    cols = args.cols
    rows = (len(indices) + cols - 1) // cols
    cell = args.cell
    label_h = 14
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + label_h)), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)

    checker = Image.new("RGBA", (cell, cell), (60, 60, 60, 255))
    cpix = checker.load()
    for by in range(0, cell, 8):
        for bx in range(0, cell, 8):
            if ((bx // 8) + (by // 8)) % 2 == 0:
                for yy in range(by, min(by + 8, cell)):
                    for xx in range(bx, min(bx + 8, cell)):
                        cpix[xx, yy] = (80, 80, 80, 255)

    for n, idx in enumerate(indices):
        c = cel_by_index[idx]
        src = effects_atlas if c["kind"] == "effect_mask" else sprite_atlas
        crop = src.crop((c["x"], c["y"], c["x"] + c["w"], c["y"] + c["h"]))
        # scale up small cels, scale down large ones, preserve aspect, letterbox into cell x cell
        scale = min(cell / c["w"], cell / c["h"])
        new_w, new_h = max(1, int(c["w"] * scale)), max(1, int(c["h"] * scale))
        resample = Image.NEAREST
        crop = crop.resize((new_w, new_h), resample)
        col, row = n % cols, n // cols
        ox = col * cell + (cell - new_w) // 2
        oy = row * (cell + label_h) + (cell - new_h) // 2
        sheet.paste(checker, (col * cell, row * (cell + label_h)))
        sheet.paste(crop, (ox, oy), crop)
        draw.text((col * cell + 2, row * (cell + label_h) + cell), str(idx), fill=(255, 255, 0, 255))

    sheet.save(args.out)
    print(f"wrote {args.out}: {len(indices)} cels, {cols}x{rows} grid, indices {indices[0]}..{indices[-1]}")


if __name__ == "__main__":
    main()
