# 29. Worked example: the real terrain art, seen through a real 3D camera, on the first try

[Document 28](28-worked-example-3d-camera-scaffold.md) covered Phase 0 (closing the last RE
unknowns about the camera's tilt) and Phase 1 (a working `Camera3D` scaffold, following a
placeholder box over a flat placeholder colour). This document covers Phase 2 — replacing
that placeholder colour with the level's real terrain art — and, unusually for this project's
own track record, everything worked on the first real screenshot.

## The one non-obvious design decision: extract, don't duplicate

`game/terrain_view.gd`'s `_draw()` already had exactly the code Phase 2 needed: a loop over
every tile, resolving art id -> sprite id -> atlas region, and blitting it. But that loop
lived inline in a function that also draws spawn markers, candidate-pool markers, and (once
Phase 3/4 land) would need to coexist with a moving vehicle and projectiles — none of which
make sense to bake into a single static texture.

Rather than duplicate the tile-loop's body into the new 3D scene (two copies of the same
logic silently drifting apart being exactly the kind of bug this project's registry tooling
already hit once, in `classify_bulk.py`'s auto-numbering drift), the loop moved into its own
node, `game/terrain_tile_renderer.gd` — the loop body is byte-for-byte what `terrain_view.gd`
used to run, just relocated so two different consumers can share it: the flat 2D scene (as a
plain child, `z_index = -1` so it stays under the markers/vehicle it used to be drawn before
in the same function) and the new 3D scene's `SubViewport` (as the only thing in it). Rerunning
the flat 2D scene's own screenshot test after this extraction confirmed pixel-for-pixel
identical output — real terrain, spawn marker, candidate-pool markers all still in the same
positions and the same stacking order, proving the move didn't change what
`terrain_view.gd` renders even by accident.

## Baking it into 3D

`game/terrain_view_3d.gd`'s `_build_terrain_ground()`: a `SubViewport` sized to the level's
real pixel dimensions (`_map_size_px` — 4096x4096 for `RFMAP001`), holding one
`TerrainTileRenderer` set up with the same pack/level Phase 1 already loads;
`render_target_update_mode = UPDATE_ONCE` since no tile in this project's pipeline animates,
so there's no reason to redraw an identical image every frame. The `SubViewport`'s texture
becomes a `MeshInstance3D` ground plane's albedo, sized to those same real dimensions, with
nearest-neighbour filtering (the source art is hard-edged pixel art, section 2.4.2 — linear
filtering would blur tile edges that were never meant to be soft). No UV flipping or
coordinate-fix was needed; the X-right/Z-forward convention Phase 1 already established lined
up with the baked texture correctly on the first attempt.

## What the screenshot shows

A real, recognisable level — the same coastline, road, bushes, and building pad the flat 2D
scene's own screenshot shows, now genuinely perspective-projected: the shoreline recedes
toward a horizon near the top of frame, water in the distance reads as more distant than
water close to the camera, matching the tilted, receding look the user originally pointed out
from real footage (the observation that started this whole migration, section 2.2). A second
screenshot with `RF_DEBUG_DRIVE_TURN=0.3` (a curving path, not a straight line) confirms the
camera smoothly follows a turning target over the real terrain, zooming out visually as the
tracked point nears the shoreline — the same follow/clamp logic Phase 1 verified with a
placeholder box now driving a real, recognisable view.

## What's still honestly a placeholder

The tracked object is still a plain box (billboard `Sprite3D` vehicles are Phase 3). The
ground mesh is sized to the level's exact real bounds, as the plan calls for — which means
Phase 1's finite-mesh horizon artifact (a small corner of background void where a
near-horizontal ray clears the mesh's edge before reaching the mathematical horizon) is still
visible here too, honestly not routed around: there's no real terrain art beyond a level's
actual bounds to extend the mesh with, so covering the gap would mean texturing it with
something other than real art. Worth a skybox or fallback-colour backdrop in a later pass;
not a blocker for verifying the terrain projection itself, which is what this phase was
scoped to prove.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
