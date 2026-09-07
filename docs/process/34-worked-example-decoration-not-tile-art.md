# 34. Worked example: trees can't be tile art, and neither can vehicles — the same 7-bit mask proves it

The user pointed at real Windows-port footage and made two connected observations: the tank's
visible tread changes with camera positioning (consistent with genuine per-object 3D
projection, not a flat sprite), and "same with trees" — the reference screenshots' palm trees
read as real, standing, camera-aware objects, not flat paint. Chasing the tree half of that
claim surfaced a concrete, previously-unnoticed fact about this project's own tile pipeline
that answers both at once.

## First: we had never actually rendered a tree

Before touching any theory, the obvious check: does our own build show a real tree anywhere?
No. `RFMAP001` — the level every screenshot this session used — turns out to have **zero**
tree-family art anywhere in its tile grid. The "big green blob cluster" visible in every
earlier 3D screenshot is `terrain.coast.forest_water.*`, a forest-meets-water coastline blend
texture, not vegetation. Scanning all 204 converted levels for any of the registry's
tree/bush/palm-tagged cel indices found exactly one candidate actually placed anywhere:
`terrain.tile art id 101`, which the registry has labeled `decoration.tree` since document 19,
used in 168 of 204 levels. Rendering one of those levels (`RFMAP091`, 42 instances within 15
tiles of its spawn) showed... nothing. Just a plain sand tile.

## The registry entry was wrong

Cropping the actual atlas pixels for cel 101 settled it: no canopy, no trunk, nothing green at
all. It's a small gray structure — two flanking wall segments around a raised boxy shape with
a dark vent/opening, sitting on a yellow/black hazard-striped pad, on a circular sand
clearing. The registry's note ("dark green canopy on a post/trunk") describes art that isn't
there — a real misclassification, not a rendering bug. Corrected to
`terrain.structure.small_bunker` (a descriptive name; its exact gameplay role, if any beyond
scenery, is unconfirmed) via the established hand-patch pattern
(`packs/registry/asset_ids.json` directly, plus a matching `put()` correction block in
`tools/registry/classify_bulk.py` for the documentation trail). Registry and pack both
re-validated clean afterward.

So: as far as the flat tile grid is concerned, **no level in this game places a tree.** But
real, unmistakable tree art does exist in `ART.CAR` — cel 138 is a pair of crossed coconut-palm
trunks, cels 135/139/140 are frond clusters, clearly hand-drawn tree parts, not a
misclassification. It's just never referenced by any `.RFM` tile grid.

## Why: a 7-bit ceiling nobody had connected to this before

Section 1.5/1.7 already fully decompiled the terrain tile-resolution path and documented that
every raw on-disk tile byte resolves to a **0-127** art id — confirmed directly from
RFIRE.BIN's own code, `*puVar4 & 0x7f`, reproduced in this project's own converter as
`tools/rf_tile_art.py`'s `return art_id & 0x7F`. That fact was recorded as part of understanding
the terrain format; nobody had checked it against where the *real* tree art actually lives in
`ART.CAR`'s cel numbering. It doesn't: cels 135-140 are all well above 127. **The terrain tile
mechanism is structurally incapable of ever referencing them, in the original binary, not just
in this project's converter.** Masking with `& 0x7F` isn't a bug to route around — it's the
real engine's own hard ceiling on what a flat tile can show.

That means trees were never going to be tile art, in RFIRE.BIN or in this port. Whatever places
them, it isn't the mechanism `game/terrain_tile_renderer.gd` implements today.

## This is the same fact behind the tank-tread observation

Section 1.10 already established, separately, that vehicles render through a completely
different path: per-object local-space 3D corner geometry, individually projected to screen
space and quad-mapped onto the CCB's arbitrary-parallelogram texture-mapping mode — not the
flat terrain blitter at all. Vehicle rotation cels are numbered well above 127 too, for the
same structural reason trees are: **anything the flat terrain blitter can't address has to go
through the per-object path instead.** The tank's tread visibly changing with camera position
and the trees looking "real" instead of painted are the same underlying fact observed twice:
real per-object 3D projection is not vehicle-specific — it's this engine's *only* way to place
anything that isn't one of the 128 terrain tiles. Trees, whatever renders them, almost
certainly go through the exact same mechanism vehicles do.

## What's still open

Nothing currently found explains *where* a tree's position/type is actually recorded. The
`.RFM` format has no unexplained chunk to point to — the only chunk this project doesn't decode
(`EDTN`) was already confirmed unused in document 11, and no other unrecognized chunk tag
appears in any of the 204 real level files. So a real per-object decoration placement list, if
one exists, is either encoded somewhere inside a chunk this project already parses for a
different purpose, generated procedurally at load time from terrain data (e.g., a scatter rule
keyed off certain ground tile types) rather than stored explicitly at all, or something this
project hasn't looked at in RFIRE.BIN's object-spawning code yet (the shared object
constructor/vtable system document 31 traced for vehicles covers more than one object family
already). None of these is confirmed. This is a genuinely new, unstarted lead — not a
continuation of anything already in the backlog — and chasing it means real Ghidra work, not
another converter check.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
