# 41. Worked example: decorations are real 3D entities, not paint on the ground

The user's direction, right after choosing to set the turret aside for later: *"make sure the
trees are also rendered as 3D entities, as they should be."* A one-sentence request, but it
named a real architectural gap document 36 had reasoned its way into accepting rather than
actually checked by looking.

## What document 36 actually did, and why it looked fine on paper

Document 35 found decorations go through the exact same per-object rendering pipeline vehicles
use. Document 36 wired the catalogue in, but chose to draw every decoration part with a plain
`draw_texture_rect_region()` call baked into `game/terrain_tile_renderer.gd`'s one-shot ground
texture -- the same texture the tile grid itself bakes into. Its own reasoning at the time:
*"unlike the vehicle, a decoration never moves or turns after level load, so baking it into
this same one-shot texture is exactly as visually correct as giving it its own live Node3D
(both go through the same real Camera3D projection in the 3D scene either way)."*

That's true for the *terrain itself* -- ground tiles are genuinely flat, so painting them into
a texture and letting a real tilted `Camera3D` view that flat plane is a completely faithful
3D presentation of flat content. It does not hold for anything with real height. A decoration
baked flush with the dirt sits at the *exact same Y* as the ground underneath it, forever. No
matter how correct the projection math is, a flat mark at ground level can never show parallax
against the ground as the camera moves, and can never occlude or be occluded based on real
depth -- it reads as a shadow or a footprint, not as something standing on the ground. Screenshot
evidence agreed immediately once actually looked for: the palm clusters in every prior 3D-scene
screenshot are flat green blobs painted on the sand, with no visible trunk, no sense of height.

## Two cel families, two different intended shapes -- confirmed, not assumed

Cropping the actual art directly out of the atlas (not reasoning about it secondhand) settles
which axis each decoration part actually belongs on:

- `decoration.foliage.frond_blue` (cel 135, one of `CANOPY_SPRITE_IDS`) is a radially symmetric
  starburst of fronds -- drawn as if seen from directly above. This is meant to lie flat, the
  same orientation the ground plane itself uses.
- `decoration.tree.palm` (cel 138, the trunk document 36 already pairs with canopy-only
  decorations) is two crossed trunks converging at a base, drawn side-on -- a real profile
  view. This is meant to stand up as a vertical card, not lie flat.

Document 36 had already found the right *composition* (pair a floating canopy with this trunk)
purely by eye, without ever noticing the two cels are drawn from different implied camera
angles -- because both were being flattened onto the same ground plane anyway, so the
distinction never mattered until decorations needed real height.

## The fix: a real Node3D layer, reusing document 36's own composition rule

New `game/decoration_field_3d.gd` replaces `TerrainTileRenderer._draw_decorations()` (deleted;
that file is tile-grid-only again). Per decoration tile, using the identical canopy-detection
and ring-spread logic document 36 already established (not re-derived):

- **Canopy-only decorations** get `decoration.tree.palm` as a plain vertical `Sprite3D` (no
  rotation needed -- Godot's default un-rotated Sprite3D plane already stands vertical), from
  ground level up to a placeholder height, then their real canopy part(s) as horizontal
  `Sprite3D`s (the same "tip -90 degrees on X to lie flat" technique `vehicle_billboard_3d.gd`'s
  GROUND_DECAL mode already uses) sitting at the top of that height.
- **Everything else** (rocks, bushes, coral, debris, dock posts, ...) becomes a real,
  ground-level horizontal `Sprite3D` quad -- a genuine Node3D now, just with no invented height,
  since their art keeps the same top-down framing document 36 already gave it.

No billboarding anywhere: this game's camera never yaws (document 27/28, confirmed by
decompiling the terrain blitter -- it translates in X/Z only, no rotation term exists to read),
so a plain fixed-orientation card is exactly as correct as a camera-facing billboard and
cheaper, the same reasoning `vehicle_billboard_3d.gd`'s GROUND_DECAL mode already relies on.

## What's honestly still a placeholder

Real per-part 3D corner data for decorations was never decoded (document 35's own gap,
unchanged) -- only which cels compose a given coastal id, not their real relative offsets or
heights. The trunk height used here (`TRUNK_HEIGHT_PX`) is a reasonable placeholder, not a
traced value, and the multi-part ring-scatter layout is still document 36's original
placeholder too. What this document fixes is the axis that was flatly wrong -- decorations now
have real elevation at all -- not a claim that the exact height or per-part layout is
authentic. Decoding the real corner data (the same kind of investigation today's earlier
turret-tip session did for the Tank) would be the natural next step if higher fidelity is
wanted later.

## Result

A real, driven screenshot of `RFMAP001` shows standing palm trunks with layered canopies at
real height, visible depth between rows of trees, and ordinary ground-level decorations
(bushes, rocks, debris) unchanged in footprint but now genuine 3D geometry rather than baked
paint -- a clear, immediate difference from every prior screenshot in this project showing
flat, ground-level foliage marks.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
