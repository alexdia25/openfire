"""Compare the 3DO .wor maps against the PC's .RFM maps (issue #96, Phase 7).

A .wor file (RFIREData/FinalMaps/) is 16,392 bytes: an 8-byte header (u16 BE width 0x80, u16 BE height 0x80,
4 zero bytes) followed by the raw 128x128 tile grid, one byte per tile, the same vocabulary as the tile grid in
a PC .RFM (tools/convert_rfm.py). This prints, for each .wor, the PC map whose grid is most alike and the share
of identical tiles. On 2026-10-11: base disc 64 of 67 at least 90% alike (4 identical), Maps o' Death
164 of 166 (72 identical).

    python tools/rf3do_compare_maps.py <FinalMaps dir> [--all]
(an extracted disc, see tools/rf3do_opera.py --extract; RF_GAME_DIR is the PC install)
"""
import glob
import os
import struct
import sys

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")


def pc_grids():
    grids = {}
    for p in glob.glob(os.path.join(GAME_DIR, "WORLDS", "*", "*", "*.RFM")):
        d = open(p, "rb").read()
        n, off = struct.unpack_from("<II", d, 0x44)
        grids[os.path.relpath(p, os.path.join(GAME_DIR, "WORLDS")).replace(os.sep, "/")] = d[off:off + n]
    return grids


def wor_grid(path):
    d = open(path, "rb").read()
    w, h = struct.unpack_from(">HH", d, 0)
    return d[8:8 + w * h]


def same_share(a, b):
    # XOR the two grids as big integers; a zero byte is an identical tile.
    x = (int.from_bytes(a, "big") ^ int.from_bytes(b, "big")).to_bytes(len(a), "big")
    return x.count(0) / len(a)


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    pcs = pc_grids()
    rows = []
    for f in sorted(glob.glob(os.path.join(argv[0], "*.wor"))):
        g = wor_grid(f)
        score, best = max((same_share(g, v), k) for k, v in pcs.items() if len(v) == len(g))
        rows.append((os.path.basename(f), score, best))
    for name, score, best in rows if "--all" in argv else [r for r in rows if r[1] < 1.0]:
        print("%-12s %6.2f%%  %s" % (name, score * 100, best))
    print("%d maps: %d identical to a PC map, %d at least 90%% alike" % (
        len(rows), sum(r[1] == 1.0 for r in rows), sum(r[1] >= 0.9 for r in rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
