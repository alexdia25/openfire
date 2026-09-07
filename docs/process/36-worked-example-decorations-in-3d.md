# 36. Worked example: putting the decoration catalogue on screen

Document 35 confirmed the mechanism and extracted a real, registry-verified decoration
catalogue (82 of 91 coastal ids) from RFIRE.BIN. This document wires that catalogue into the
converter and both rendering scenes, closing the thread the user's original tank-tread
screenshot started -- static scenery, not just vehicles, now gets a real presence.

## Extending the converter, not inventing a new one

`tools/convert_rfm.py` already resolves every tile's coastal id once, to pick a blended ground
texture (`raw_tile_to_art_id`) -- document 35 found that same id, via a separate table entry
field, also names a decoration. `tools/rf_tile_art.py` gained one new function,
`raw_tile_to_coastal_id()`, that exposes the coastal id `raw_tile_to_art_id()` already computes
internally and discards. `convert_rfm.py` records every tile's nonzero coastal id as a
`{x, y, coastal_id}` entry in the level's own JSON -- the same "extract everything, let the
pack decide what's known" choice this project already made for spawn points and candidate
pools. It doesn't check the id against the new decoration catalogue at all; an id with no known
decoration simply won't resolve to anything downstream, the same way an unmapped art id already
draws nothing.

`tools/build_pack.py` is where document 35's `tools/data/coastal_decorations.json` (raw
`ART.CAR` cel indices, Ghidra-extracted) actually becomes usable art: a new `terrain/
decorations.json` resolves each cel index through the same registry the sprite atlas already
uses, so the engine only ever sees sprite ids, never raw cel numbers -- identical in spirit to
how `terrain/tileset.json` already does this for plain ground tiles.

## Rendering: extending the tile renderer, not adding a new node type

The natural instinct might be a new `DecorationBillboard3D`, paired with a live logic node the
way `VehicleBillboard3D` pairs with a real `Vehicle`. That pattern exists because a vehicle
*moves and turns* -- its screen presence has to be recomputed every frame. A decoration does
neither: once a level loads, it never moves again. Baking it into `game/terrain_tile_
renderer.gd`'s existing one-shot draw -- the same node already shared between the flat 2D
scene and the 3D scene's baked `SubViewport` ground plane -- gives it exactly the same real
perspective projection a live Node3D would, at a fraction of the cost of one node per placed
bush or rock. `TerrainTileRenderer` now draws the tile grid first, then walks
`level.decorations`, asking `Pack.get_decoration_parts(coastal_id)` for each tile's real parts
and drawing them centred on the tile.

One placeholder, flagged honestly: document 35 didn't decode the real per-part corner offsets
a multi-part decoration uses (up to 11 parts for some coastal ids), so parts are spread evenly
around a small fixed-radius ring instead of stacked exactly on top of each other. Good enough
to read as "a cluster," not a claim about the original's real per-part layout.

## Result

A real, driven screenshot of `RFMAP001` (179 decorated tiles) shows dense, individually
readable palm fronds and bush clusters lining the coastline, correctly foreshortened by the
same tilted `Camera3D` that projects the terrain -- a dramatic change from the single flat,
mottled "forest coastline" ground texture every earlier screenshot in this session showed. The
flat 2D scene picks up the exact same decorations for free, since both scenes share
`TerrainTileRenderer` unchanged -- no separate implementation to keep in sync.

## What this doesn't settle yet

- 3 of 91 coastal ids (49, 50, 76) still have no known decoration -- document 35's own gap,
  unchanged here. Godot renders nothing for a level tile using one of those ids, the same as
  any other unmapped id.
- The team-colour-offset bit document 35 found in each part's flags (bit 3, `0x8`) is not
  applied -- every part always draws its base cel, never the offset variant. Decorations don't
  have a "team" the way vehicles do, so what that bit actually means for a decoration (a second
  colour variant? something else entirely?) is unconfirmed.
- Real per-part corner/position data remains undecoded (see above) -- the ring-scatter layout
  is a placeholder, not a finding.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
