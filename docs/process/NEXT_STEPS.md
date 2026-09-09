# Next steps

*Deliberately unnumbered, unlike everything else in this folder.* The numbered docs (01-18
and counting) are a frozen chronological narrative — each one is a snapshot of how a specific
question got answered, and it never changes after the fact. This document is the opposite: it
gets edited in place every time the backlog changes, so giving it a fixed position in that
sequence never made sense — it would have to keep "moving" to stay current, which a step in a
numbered walkthrough can't do. Read the numbered docs in order for the story; read this one
whenever you want the current state.

The backlog itself — full technical detail, current state, always up to date — lives in
`docs/PORTING_PLAN.md` section 4. This document is just the connective tissue between the
worked-example docs: what got resolved, in what order, and where to read the full account.

## Resolved so far

- **`.RFM` art id → `ART.CAR` cel mapping** — [document 8](08-worked-example-art-id-mapping.md); plan section 1.7.
- **`ART.CAR` effect-mask tint colour** (and the `PRE0==17` reclassification) — [document 9](09-worked-example-effect-tint-colour.md); plan section 1.6.
- **The `>>1` candidate-pool computation** — [document 10](10-worked-example-target-respawn.md); plan section 1.5.
- **The `EDTN` chunk** (confirmed game-unused) — [document 11](11-worked-example-edtn-chunk.md); plan section 1.5.
- **The `.RFM` header body** (timestamps + level designer credits) — [document 12](12-worked-example-header-body.md); plan section 1.5.
- **The "team-colour swatch" lead** — ruled out — [document 13](13-worked-example-reticle-not-swatch.md); plan section 1.6.
- **Music playback mechanism** (CD audio + WAV fallback, not `DRUMS.WAV`) — [document 14](14-worked-example-music-mechanism.md); plan section 1.8.
- **Native resolution** (320x240) — [document 15](15-worked-example-resolution-and-tick-rate.md); plan section 1.9.
- **"Implicit sprite pivots"** (there isn't one — real 3D projection) — [document 16](16-worked-example-3d-projection.md); plan section 1.10.
- **The "missing `.avi` cutscenes"** (there weren't any — more streamed audio) — [document 17](17-worked-example-reference-iso.md); plan section 1.11.
- **The fixed sim tick rate** (there isn't one — a blocking `Flip()` paces fullscreen play instead) — [document 18](18-worked-example-vtable-flip.md); plan section 1.9.
- **The asset ID registry** — all 2165 `ART.CAR` cels classified, coarse precision by design for most of them — [document 19](19-worked-example-asset-registry.md); plan section 2.4.1.
- **Team colours are tan and green** (user-confirmed, cross-checked against art across three independent cel families) — plan section 4, item 5.
- **The pack emitter + Phase 4 step 1** — a real level renders in Godot through a real content pack, verified with a screenshot — plan sections 2.4.2 and 3 (Phase 4 step 1).
- **A real palette bug** (raw pixel byte needs a `-10` shift into the shared PLUT) — [document 20](20-worked-example-palette-offset.md); plan section 1.6.
- **Phase 4 steps 2/3** (a player-controlled vehicle, a scrolling camera) — including a real mirror-flip rendering bug and the registry auto-numbering bug it exposed — [document 21](21-worked-example-vehicle-mirroring-bug.md); plan section 3.
- **Phase 4 steps 4/5** (weapons/projectiles, destructible targets) — the latter a direct reimplementation of section 1.5's already-traced candidate-pool mechanism, verified by a unit test and a real-scene integration test — [document 22](22-worked-example-weapons-and-targets.md); plan section 3.
- **Phase 4 step 6** (enemy AI) — a from-scratch seek-and-shoot placeholder with no RE finding behind it, spawned from real per-level spawn data, verified by a deterministic fixed-timestep test — [document 23](23-worked-example-enemy-ai-first-pass.md); plan section 3.
- **The capture-flag art is two team-coloured animations, not one generic marker** (and 4 misclassified frames corrected) — [document 24](24-worked-example-capture-the-flag-lead.md); plan section 4, item 1.
- **One real cause of the "turning sprites" bug** — the tan rotation set was missing a 9th frame (misfiled as debris), found by tracking a user-supplied video frame-by-frame and comparing raw cel pixel counts. Fixed (registry + pack regen, no code change) and verified with a headless heading-to-frame dump — [document 25](25-worked-example-turning-sprite-video.md); plan section 4, item 10.
- **The exact flag-spawn trigger condition, and a first-pass implementation of it** — `DAT_00442b00` has no write site anywhere except a hidden debug menu, so it's always 0 in real play; reading the destruction handler's full branch under that condition pins down the precise rule (a pool's flag object spawns exactly when its targets are fully exhausted), exactly what `TargetPool.destroy_active()` already returns `false` for. Made real with a new `FlagMarker` node, verified by a real-scene integration test — [document 26](26-worked-example-flag-spawn-condition.md); plan section 4 item 1, plan section 3 Phase 4 step 7.
- **Terrain rendering is also real perspective-projected 3D, not a flat top-down map** — confirmed by fully decompiling the terrain blitter (document 16's "shares a table" note turned out to mean a genuine per-scanline perspective floor). Reframes Phase 4 step 1's flat `TileMapLayer` render as an unflagged simplification, not a settled decision — see [document 27](27-worked-example-terrain-perspective.md); plan section 1.10 point 5, section 2.2, section 4 item 13.
- **The rendering-migration plan's Phase 0 and Phase 1** — the camera tilt is exactly 45 degrees (algebraically, from decoding the binary's own angle-to-radians constants), hardcoded once and never rewritten; a real `Camera3D` scaffold (`game/terrain_view_3d.gd`, built alongside the still-fully-working flat 2D scene) proves that tilt translating in X/Z, edge-clamped and smoothed the same way the existing `Camera2D` is, with tilt/zoom left live-adjustable but no rotation control at all (a real bug — `look_at()` quietly introducing rotation whenever edge-clamping kicked in — was caught and fixed along the way) — see [document 28](28-worked-example-3d-camera-scaffold.md); plan section 1.10 point 6, section 2.2, section 4 item 13.
- **Phase 2 of the same plan** — the level's real terrain art, genuinely perspective-projected through that `Camera3D`, not a placeholder colour. `terrain_view.gd`'s tile-drawing loop was extracted into a reusable node (`game/terrain_tile_renderer.gd`) instead of duplicated, so the flat 2D scene and the new 3D scene's baked `SubViewport` texture share the exact same drawing code — verified working correctly on the first real screenshot, including a driven test over a curving path. See [document 29](29-worked-example-baked-terrain-3d.md); plan section 2.2, section 4 item 13.
- **Phase 3 of the same plan** — a real, completely unmodified `Vehicle` rendered as a billboard `Sprite3D` (`game/vehicle_billboard_3d.gd`) instead of Phase 1's placeholder box, calling `Vehicle._frame_for_heading()` — the exact quadrant-mirror logic document 25 fixed a real bug in — directly, rather than duplicating that logic. A 12-heading sweep confirms that fix still holds through this new rendering path; a driven test confirms the vehicle's real movement/camera-follow works together with the real baked terrain for the first time. See [document 30](30-worked-example-billboard-vehicle-3d.md); plan section 2.2, section 4 item 13.
- **The exact turning-sprite failure mode, and the real vehicle roster it led to** — heading 0 and heading 180 render pixel-identical (flipping a symmetric base frame changes nothing), precisely explaining a user-reported "never turns" symptom. Re-attempting the abandoned real-facing-table trace this time fully decompiled the lookup mechanism and, following it back through the binary's own data, surfaced a genuine string table: the game's real vehicle roster is **Tank, Jeep, MSV, and Helicopter**, not the one "hovercraft" this project has built. A real mini-map icon set (registry corrected) visually confirms all four. Real in-game rotation art for Jeep/MSV/Heli is still unlocated. See [document 31](31-worked-example-vehicle-roster.md); plan section 4 item 10.
- **The "little triangles" complaint was a rendering-technique gap, not missing art — fixed, and now the shipped default.** A real, non-billboarded quad lying flat like the terrain plane, rotated in true 3D to match the vehicle's actual heading, produces a smooth, always-coherent silhouette at every heading using just **one** source image — better than the old nine-frame mirror-and-flip billboard approach ever achieved. The obvious follow-up (cycling all 9 real frames alongside the same rotation) was tested and is worse, not better: the discrete frames already bake in a thinning silhouette near 90/270 degrees, and real geometric foreshortening on top compounds that instead of complementing it, collapsing the shape almost to nothing at exactly those headings. `game/vehicle_billboard_3d.gd`'s default is now `GROUND_DECAL` (single texture); `BILLBOARD` and `GROUND_DECAL_MULTI` remain available via `RF_DEBUG_VEHICLE_QUAD_MODE` for comparison. See [document 32](32-worked-example-ground-decal-prototype.md); plan section 2.2, section 4 item 10.
- **Perspective terrain/object rendering — the rendering-migration plan's all six phases are DONE (2026-09-06).** Phase 4 (projectiles, target/pool markers, the flag marker), the last one, first required extracting `terrain_view.gd`'s gameplay logic (vehicle/enemy spawn, projectile spawn-on-fire, target-pool hit-testing, the flag-spawn trigger) into a new shared `game/match_controller.gd`, so the flat 2D and 3D scenes provably run identical rules instead of risking two hand-copied implementations drifting apart. Projectiles and the flag reuse Phase 3's real-node-paired-with-a-3D-presentation pattern (`ProjectileBillboard3D`, `FlagMarker3D`); the debug spawn/pool markers, which had no dedicated gameplay node to pair with, got Phase 2's baked-`SubViewport` treatment instead (`game/debug_marker_renderer.gd` + `game/debug_marker_overlay_3d.gd`). A driven screenshot confirms all three working together in the 3D scene, correctly foreshortened by the same tilted camera as the terrain. With this done, `game/terrain_view.gd`/`.tscn` had nothing left it did that the 3D scene didn't — it has since been retired as a whole (marked-superseded, matching `tools/rfcel.py`'s own precedent; see the superseded-rule note below). See [document 33](33-worked-example-phase4-projectiles-markers-flag.md); plan section 2.2, section 4 item 13.

- **The turning-sprite rendering — RESOLVED for real (2026-09-08): the "flat sprite" premise
  itself was wrong.** The earlier diagnosis (heading 0 and 180 render pixel-identical, since a
  symmetric base frame can't be fixed by mirroring alone) was correct as far as it went, but
  chasing a further user observation — no visible tank tread, ever — found that
  `vehicle.hovercraft.rotation.tan.01-09` was never the game's real Tank art at all. The real
  Tank is a genuine six-face 3D box, traced directly out of RFIRE.BIN's own per-vehicle-type
  data (a real cross-reference chase down to a vehicle-type table whose entry 0 name string
  reads literally `"Tank"`), including the tank-tread graphic (cels 182/183) this project had
  sitting unused the whole time. `game/vehicle_box_3d.gd` now builds this real box and is the
  default vehicle presentation; the old flat-card approach is a debug fallback only
  (`RF_DEBUG_VEHICLE_RENDER=billboard`). A second real bug (the vehicle's rendered front facing
  90 degrees away from its actual movement direction — a previously-unverified assumption, not
  a regression) was found and fixed along the way, with the identical `+90` correction needed
  for both the old flat card and the new box. This also retroactively explains the very first
  observation that started this whole thread: a real 3D box under a tilted camera naturally
  shows more or less tread depending on where it sits in frame. See
  [document 37](37-worked-example-real-tank-geometry.md); plan section 4 item 10. The DOSBox-X
  reference-capture attempt from 2026-09-06 (blocked on a Windows 95 boot failure) is now moot
  for this specific question, though still parked for anything else that might need it.
  **Update (2026-09-08, document 38):** the real descriptor actually has **14 parts, not 8**
  -- document 37's own "8, not 6" addendum was itself still an undercount (it trusted the
  angle-bucket draw-order lists as a full part manifest; they only cover 6 of the 14). The
  remaining 8 went through two full rounds of "looks fixed, ship it" -- each undone once
  compared against the user's own real reference screenshots (the second time, live, mid-fix).
  Round 1's theory (these cels need native-size placement, not stretch-to-fill) is now
  confirmed WRONG by decompiling the actual CCB corner-assignment code (`FUN_00419820`):
  stretch-to-fill is the only mode that exists anywhere in this path. Round 2 fixed a real bug
  (a missing `.transparency` line rendering transparent pixels as opaque black) but exposed a
  different, still-unsolved one: non-uniform stretching distorts detailed/circular content
  (confirmed concretely -- cel 212, a 16x16 ring, spilling visibly past the tread's own wheel
  graphics once stretched ~3.25x more in one axis than the other) even when the destination is
  a genuine rectangle, not just a skewed one. All 8 are back to unrendered, verified data
  (`DETAIL_PARTS`/`WARPED_DETAIL_PARTS` in `game/vehicle_box_3d.gd`) -- the real placement rule
  for these 8 (vs. the 6 primary faces, which really do match their corner span 1:1) is
  genuinely unknown, not just unattempted. Cel 202 is still identified with fair confidence as
  the missing gun barrel itself (its atlas art is unmistakably a barrel with a red band and
  bright tip) -- unconfirmed which of two things is wrong: the original really does look this
  distorted here, or this project's part identification is still subtly off.
  This same session also built a general registry-vs-real-code audit tool
  (`tools/registry/audit_code_referenced_cels.py`) and used it to extract Jeep/MSV/Heli's real
  geometry for the first time (none are rendered in 3D yet) and fix 33 cels that were flatly
  misclassified against what real code proves them to be. See
  [document 38](38-worked-example-classification-audit.md).
  **Update (2026-09-08, document 39) -- the turret/barrel mystery is solved, and the "14
  parts" finding above was itself wrong.** The Tank's hull really only has document 37's
  original 6 real parts. The other 8 were never hull parts at all: decompiling the real
  vehicle draw dispatcher (`FUN_00402dc0`, one level up from the generic per-descriptor
  renderer document 38 had decompiled) found it draws the hull once, then -- when a linked
  turret sub-object exists -- swaps in a **wholly separate descriptor** and draws again with
  an independently composed rotation (hull heading + turret aim). That separate descriptor's
  parts array sits in memory immediately after the hull's own (which is exactly why
  boundary-detection walked into it and misread it as more hull parts, resolved against the
  wrong -- the hull's -- corner array, which is why every attempt at these 8 cels looked
  distorted no matter what got fixed). Read against the turret's own, correct corner array,
  the same 8 cels resolve into a real, coherent turret box with a barrel and muzzle ring,
  matching the user's reference screenshots directly. **Still open:** the muzzle ring (cel
  212) renders at the wrong size/position -- checked three separate ways this session
  (backface-culling flags, the rotation-matrix construction, the angle-bucket draw lists) and
  confirmed none of them explain it; a hand-adjustment attempt made it worse in a different
  way and was reverted. Independent turret aim also isn't modelled (no aim-angle state exists
  in this project yet) -- the turret renders at hull heading, a documented simplification. See
  [document 39](39-worked-example-real-turret-and-barrel.md).
  **Update (2026-09-09, document 40) -- FIXED.** The "unrelated small 7-corner linkage
  computation" document 39 explicitly skipped is real: `FUN_00402dc0` unconditionally
  overwrites, every frame, exactly the 7 corners covering the barrel's far tip *and* all 4
  muzzle-ring corners, from a small local "base" shape plus one constant translation (found by
  noticing `FUN_00409b10`'s offset-pointer argument is never advanced in its loop -- it's one
  offset added to all 7 base corners, not 7 separate ones). The static corner values this
  project had been rendering for that cluster were whatever the compiler left in a scratch slot
  the game always overwrites before the first frame -- not real geometry. Recomputing those 7
  corners as base+offset and rendering the result gives a correctly-sized, correctly-positioned
  ring at the barrel's real tip, confirmed by screenshot at all 8 discrete headings against the
  previous (oversized) rendering. Also confirmed along the way: the ring is a plain painted
  asset (cropped and inspected directly), no fire-triggered visibility/texture change exists.
  Independent gun elevation still isn't modelled (no aim-angle state exists in this project) --
  the identity/level-gun case is what's rendered, a documented simplification, not a bug. See
  [document 40](40-worked-example-turret-tip-linkage.md).

## Still open

See plan section 4 for the current, precise state of each — this list is just pointers:

- **What ends a match — the flag-spawn trigger is now precisely known (2026-09-06); the rest
  is still not.** The exact condition that spawns the flag object is solved and implemented
  (see above, document 26) — but where the flag gets picked up/carried/returned and where a
  win actually gets declared are still completely untraced — see
  [document 24](24-worked-example-capture-the-flag-lead.md),
  [document 26](26-worked-example-flag-spawn-condition.md), and plan section 4 item 1.
- **A life system the user also described — not yet investigated at all.** No "Life"/"Lives"
  text exists anywhere in the binary (a raw byte search came back empty), so this needs a
  non-string anchor — probably tracing what happens when a vehicle's destruction count/health
  reaches zero, from the vehicle side rather than the building side (section 4, item 1).
- Team-colouring *mechanism* (separate cels vs. palette swap) — the colours themselves are settled, see above (section 4, item 5)
- 3DO support: base game + "Maps o' Death" expansion — new goal, **deprioritized** until the core PC-port game runs (section 4, item 6)
- 4-player support — new goal, not yet started (section 4, item 7)
- Custom Godot UI for menus/level-select/etc — new goal, not yet started; **visual style should
  be based on the 3DO original, not the PC port** (user direction, 2026-09-06), which also
  makes this depend on the still-deprioritized 3DO disc extraction (section 4, items 6 and 8)
- Real in-game rotation art for Jeep/MSV/Heli — the old flat-rotation-sprite question is still
  unlocated, but document 38 (2026-09-08) found and extracted all 3 vehicles' real 3D box
  geometry (the same kind of per-vehicle-type descriptor document 37 decoded for the Tank),
  now sitting in `tools/data/vehicle_type_parts.json`. None of the 3 have a 3D presentation
  implemented yet (only the Tank does, `game/vehicle_box_3d.gd`) — this is real, ready-to-use
  data for whoever implements them next, not a rendering.
- **Terrain-based vehicle passability — new, user-flagged (2026-09-06) as needed for
  parity.** Not started; likely connects to the still-unchased elevation bits/height_seed
  byte (section 4, items 2 and 11).
- Possible on-foot infantry / rescue mechanic — new, unconfirmed, found while classifying the asset registry (section 4, item 12)
- **Decorations (trees, at minimum) are never placed via the flat terrain tile grid — RESOLVED
  and IMPLEMENTED (2026-09-07): mechanism found, a real decoration catalogue extracted, and
  now rendered in both scenes.** No level actually places any tree art via the ordinary tile
  grid; the one registry entry that claimed to be a tree (`decoration.tree`, cel 101) was a
  misclassification, corrected. Real tree art exists in `ART.CAR` but sits above the terrain
  blitter's confirmed 7-bit art-id ceiling (`& 0x7F`, section 1.5/1.7) — see
  [document 34](34-worked-example-decoration-not-tile-art.md). Continuing the same thread (user
  direction: authentic asset placement matters here) found how decorations actually get placed
  and rendered: the coastal-blend id every coastline tile already carries (used since section
  1.5 to pick a blended ground texture) *also* queues a real per-object decoration through the
  same depth-sorted render path vehicles use, via a pointer field
  (`COASTAL_TABLE[id]["valid"]`) this project had dumped since section 1.5 but only ever read
  as a boolean flag — traced all the way to the literal `ART.CAR` CCB-array indexing and the
  same corner-projection function vehicles use (document 35). A Ghidra script then extracted
  the real catalogue: **82 of 91 coastal ids resolved to real, registry-verified decoration
  definitions** (`tools/data/coastal_decorations.json`; coastal id 1, for example, is a
  three-part scattered bush cluster; 3 ids remain unresolved, a small well-scoped follow-up).
  That catalogue is now wired all the way through: `tools/convert_rfm.py` records every
  tile's coastal id, `tools/build_pack.py` resolves it to real sprite ids, and
  `game/terrain_tile_renderer.gd` draws each tile's decoration parts (baked, like the terrain
  itself, since decorations never move after level load) — both the flat 2D scene and the 3D
  scene get the same real, individually-readable coastline foliage for free. Follow-up: the
  palm-frond cels had no trunk pixels of their own, so the fronds floated with nothing
  visibly holding them up. A real, matching trunk cel (`decoration.tree.palm`) sat completely
  unused in the registry — now drawn under any decoration built entirely from a small,
  hand-verified set of frond cels, an explicit compositional choice rather than a new RE
  finding. See [document 35](35-worked-example-coastal-decoration-mechanism.md) and
  [document 36](36-worked-example-decorations-in-3d.md); plan section 4 item 14.

**Current priority (2026-09-06):** the asset ID registry, the pack emitter, Phase 4 step 1
(terrain + markers), a real palette-bug fix, Phase 4 step 2 (a player-controlled vehicle,
playable but not yet authentic), Phase 4 step 3's single-viewport scrolling camera
(smoothed + edge-clamped, verified with real position numbers), Phase 4 step 4's first
pass (fire input -> a moving, visible, self-expiring projectile, same "playable, not yet
authentic" flag as step 2), Phase 4 step 5's first pass (section 1.5's traced
candidate-pool mechanism now runs as real gameplay logic -- one active target per pool,
replaced from its own candidates on destruction until its budget runs out, verified by a
2000-trial unit test and a full-integration test against a real level), and Phase 4 step
6's first pass (a from-scratch seek-and-shoot enemy vehicle, spawned from real per-level
spawn data, verified by a deterministic fixed-timestep test) are all done -- see plan
section 3. Split-screen itself is not started. Phase 4 step 7 (mission objectives/scoring/
level progression) has a first pass too as of 2026-09-06: the flag-object spawn trigger from
section 4 item 1 is now precisely known (a pool's targets fully exhausted) and implemented
(`game/flag_marker.gd`, see document 26) -- but nothing carries the flag, checks a home base,
or declares a match won or lost, so this is still the real blocker for a complete match. A
related, separately-described life system is a distinct, not-yet-started lead with no string
anchor to start from.

**Note on `run/main_scene` (2026-09-06):** `project.godot` boots into
`game/terrain_view_3d.tscn` by default (a bare F5/no-argument run) — the project's one real
rendering front-end now that the rendering-migration plan is fully complete.

**Superseded rule (2026-09-06, user direction) — actioned the same day:** the flat 2D scene no
longer needs to stay fully working piece-by-piece as things get ported to 3D — that standing
rule from Phases 1-3 is retired. With Phase 4 finishing (document 33) leaving
`game/terrain_view.gd`/`.tscn` with nothing left it did that the 3D scene didn't, it has since
been retired as a whole, per direct user request: marked-superseded, not deleted (matching
`tools/rfcel.py`'s own precedent) — its header docstring now says SUPERSEDED and points at
`game/terrain_view_3d.gd`, the code is otherwise untouched and still runs if loaded directly
(`res://game/terrain_view.tscn`), and it will not be maintained or re-verified against future
gameplay/rendering changes. See plan section 2.2.
