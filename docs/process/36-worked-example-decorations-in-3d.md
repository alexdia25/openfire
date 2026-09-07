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

## Addendum: floating fronds needed a trunk

The user's next observation, looking at the result above: the palm clusters read as loose
leaves, not trees -- nothing visibly holds them up. Checking the actual atlas pixels for the
cels coastal ids 3, 4, and 5 use (`decoration.foliage.frond_blue` and four of the
`decoration.foliage.bush_green.*` cels) confirmed it: every one of them is a bare fan/frond
shape with no trunk pixels at all. Meanwhile `decoration.tree.palm` (cel 138 -- two crossed
palm trunks, standing on sand) sits in the registry completely unused -- not referenced by any
of document 35's 82 extracted coastal ids, including 49 and 50's angle-dependent variant
(decoded specifically to check this; it turned out to reference three unrelated `prop.post`/
`prop.composite` cels, not a tree trunk at all).

Whether the real game draws a trunk under these specific coastal ids is genuinely unconfirmed
-- the real per-part corner/position data behind the canopy cels was never decoded (this
document's main text already flagged that gap), so it's possible the original's true 3D quad
placement makes these fronds read as attached to something without a separate trunk sprite at
all. Rather than leave them looking unsupported, `game/terrain_tile_renderer.gd` now draws
`decoration.tree.palm` once, centred, under any decoration whose parts are drawn entirely from
this specific, visually-confirmed set of frond cels (`CANOPY_SPRITE_IDS`) -- explicitly a
compositional choice, not a new RE finding, and not applied to the round bush-blob cels from
the same cel family (112/113 etc.), which already read correctly as low ground shrubs on their
own. A re-rendered screenshot shows the difference plainly: every palm cluster now has a
visible brown trunk anchoring it to the sand.

## Addendum: decoding ids 49 and 50 along the way

Checking whether 49/50 secretly held the missing trunk (they don't) resolved a smaller loose
end from document 35: those two ids take `FUN_0041b2b0`'s *other* branch (`local_8 < 1`), which
turned out to be a genuine angle-dependent depth-order table, not a different part format.
Reading the byte-string data it points to: 5 fixed parts, cel indices 847/849/851/849/851
(`prop.composite_tan_blue.01`, `prop.post.tan.01` x2, `prop.diamond_pattern.51` x2) — several
short lists of part indices terminated by `0xFF`, one list per discrete viewing-angle bucket,
each listing the *same* 5 parts in a different order. The mechanism: rather than depth-sorting
every part every frame, the original pre-computes, per angle bucket, the correct back-to-front
draw order once. Every bucket draws all 5 parts -- angle only changes the order, never which
parts are visible. This is a real, useful structural finding (extending `DumpCoastalDecorations
.java` to walk this branch too is the natural way to close ids 49/50 for good), but unrelated to
tree trunks -- their parts are dock-post/prop shapes, nothing tree-like.

## What this doesn't settle yet

- Id 76 still has no known decoration -- document 35's own gap, unchanged here. Ids 49 and 50
  are now understood (see the addendum above) but not yet wired into the extraction script's
  output, so they still render nothing today.
- The team-colour-offset bit document 35 found in each part's flags (bit 3, `0x8`) is not
  applied -- every part always draws its base cel, never the offset variant. Decorations don't
  have a "team" the way vehicles do, so what that bit actually means for a decoration (a second
  colour variant? something else entirely?) is unconfirmed.
- Real per-part corner/position data remains undecoded (see above) -- the ring-scatter layout
  is a placeholder, not a finding.
- The `CANOPY_SPRITE_IDS` trunk fix is a hardcoded, hand-verified list of exactly the cels this
  session looked at -- it won't automatically extend to any other trunk-less canopy cel that
  might turn up elsewhere in the catalogue later.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
