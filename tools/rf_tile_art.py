"""
Raw on-disk .RFM tile byte -> final rendered "art id" lookup.

Reverse-engineered from RFIRE.BIN's level loader (FUN_00414130) and its
coastal-blend helper (FUN_0042e4f0) via Ghidra headless decompilation
(2026-09-04). See docs/PORTING_PLAN.md section 1.5 for the full writeup.

Summary of the pipeline (fully static -- no runtime neighbor scanning; the
level editor bakes the final coastline-edge shape directly into the raw
tile byte when the file is saved):

  raw byte (0-239, values >=240 clamp to 0)
    -> primary_table[raw] = (transform_byte, coastal_id, param4, dispatch_idx)
       - transform_byte == 0xff  and coastal_id == 0  =>  slot is unused/reserved
       - otherwise transform_byte is the tentative "art id" (may be 0 as a
         placeholder for tiles that get overridden below)
    -> if coastal_id != 0: look up coastal_table[coastal_id]
       - if valid != 0 (it's a pointer -- just check nonzero) and
         base_art != 0xff: art id becomes coastal_table[coastal_id].base_art
         (the `mode == 8 -> base_art + param4` alternate path in the
         decompiled function never actually triggers for any real table
         entry -- mode is never exactly 8 in the dumped data -- so it's
         irrelevant for real levels and not implemented here)
    -> dispatch_idx != 0 marks a spawn-point (idx 1) or building/target
       candidate (idx 2) tile -- convert_rfm.py already extracts these
       separately as entities, not terrain. Candidate tiles (raw 0xB4/0xDC)
       DO still carry a real coastal-derived art id (109, "buildable
       ground") since the dispatch call only records the position, it
       does not touch the tile's stored art bits.

Result: 240 raw byte values collapse to 104 distinct final art ids, one of
which (id 0) is an large "unused/blank" catch-all bucket (57 raw values --
mostly reserved slots and coastal variants whose coastal table entry has
base_art == 0xff, meaning "no override, leave blank").

The art id returned here is also, directly, the ART.CAR cel index to render --
RFIRE.BIN's real terrain blitter (FUN_00408d60) indexes ART.CAR's own CCB array
with this exact value, no separate table involved. See docs/PORTING_PLAN.md
section 1.7 for how that was confirmed.
"""

import json
import os

_DATA_PATH = os.path.join(os.path.dirname(__file__), "data", "tile_lookup_tables.json")

with open(_DATA_PATH) as _f:
    _TABLES = json.load(_f)

PRIMARY_TABLE = _TABLES["primary_table"]  # list of 240 dicts, index == raw byte
COASTAL_TABLE = _TABLES["coastal_table"]  # dict of str(coastal_id) -> dict


def raw_tile_to_art_id(raw_byte):
    """Return the final rendered art id (int) for a raw on-disk tile byte,
    or None if the slot is unused/reserved (should not appear in real
    level data, but is possible in theory).
    """
    if raw_byte >= 240:
        raw_byte = 0
    entry = PRIMARY_TABLE[raw_byte]
    transform_byte = entry["transform_byte"]
    coastal_id = entry["coastal_id"]

    if transform_byte == 0xFF and coastal_id == 0:
        return None

    art_id = transform_byte

    if coastal_id != 0:
        coastal = COASTAL_TABLE.get(str(coastal_id))
        if coastal is not None and coastal["valid"] != 0 and coastal["base_art"] != 0xFF:
            art_id = coastal["base_art"]

    return art_id & 0x7F


def is_dispatch_tile(raw_byte):
    """True for the 4 special tile values that mark spawn points / building
    candidates (0x39, 0x4D, 0xB4, 0xDC) -- these are entities, not terrain,
    even though they still resolve to a real art id above (used as the
    ground drawn beneath them)."""
    if raw_byte >= 240:
        raw_byte = 0
    return PRIMARY_TABLE[raw_byte]["dispatch_idx"] != 0


if __name__ == "__main__":
    # Self-test / summary dump.
    from collections import defaultdict

    by_art = defaultdict(list)
    unused = []
    for raw in range(240):
        art = raw_tile_to_art_id(raw)
        if art is None:
            unused.append(raw)
        else:
            by_art[art].append(raw)

    print(f"{len(by_art)} distinct art ids across {240 - len(unused)} mapped raw values")
    print(f"{len(unused)} unused/reserved raw slots: {unused}")
    print()
    for art in sorted(by_art):
        raws = by_art[art]
        print(f"art={art:3d}  <- {len(raws):3d} raw value(s): {raws}")
