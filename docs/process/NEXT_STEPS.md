# Next steps

*Deliberately unnumbered, unlike everything else in this folder.* The numbered docs (01-81
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
  way and was reverted. Independent turret aim was not modelled at this point (now done, [document 64](64-worked-example-turret-and-raised-fire.md)). See
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
  **Update (2026-09-09, document 42) -- FIXED, a real 180-degree facing bug, not related to the
  turret's own geometry.** User-reported: "the turret and barrel is facing backwards." The
  box hull's `FACING_OFFSET_DEG` has been 180 degrees wrong since document 37, invisible until
  now because the hull is fully symmetric front-to-back (a 180-degree yaw rotates it into
  itself) -- the turret is the vehicle's first directional feature, and a real RF_DEBUG_DRIVE
  test (confirmed real +X motion via RF_DEBUG_CAMERA_LOG) showed the barrel pointing exactly
  opposite the logged direction of travel. One constant fixed (`90.0` -> `-90.0`), reverified
  the same way. Also answered: yes, the original composes the turret's rotation from the hull's
  heading *plus* a separate aim angle (document 39's own `FUN_00402dc0` finding) -- independent
  turret aim is real in RFIRE.BIN, just not modelled in this project yet (no aim-angle state
  exists), unchanged backlog item. See [document 42](42-worked-example-turret-facing-backwards.md).

- **Camera calibrated to the traced focal length (300 -> 56.6 degree HFOV, height 212), and the Tank scaled to 0.4 (estimated from user's Win95 reference shots, not traced)** — the tank had been built ~2.7x too wide for the road. Also fixed mislabeled pavement cels in the registry (`rooftop_red` -> `pavement`). See [document 43](43-worked-example-camera-and-tank-scale.md).
- **Sizes traced from RFIRE.BIN instead of estimated (2026-09-19):** world unit = 16.16 fixed, tile = 32 units, so the Tank is exactly 24 units wide (scale 0.375), and every decoration part now renders from its real quad corners — including the previously-missed chained sub-object that holds palm trunks and ground shadows, traced shadow strength, the original's per-tile jitter, team-colour variants, and the base buildings (coastal ids 49/50). See [document 44](44-worked-example-traced-world-scale.md).
- **Tank movement traced from RFIRE.BIN (2026-09-20):** speed 65.6 units/s (~2 tiles/s), reverse 25, accel 195/s², friction 97.6/s², turn 87.9°/s, from the Tank record read by `FUN_0040c190`, on a 16 ms (62.5 Hz) tick. Also the pavement 1.2× cap, the Tank shell (3.0 units/tick, 1.28 s, damage 1, 20-tick cooldown) and per-hit tile hit points (a building now takes 6 shots); other vehicles' values are tabulated but not applied. See [document 45](45-worked-example-traced-vehicle-movement.md).
- **Registry terrain names corrected (2026-09-20):** cels 0-72 were mislabelled (water called dune/sand, sand called water/forest, grass called forest_water); renamed by what each cel shows. See [document 44](44-worked-example-traced-world-scale.md), open-items list.
- **Registry audit against code (2026-09-20):** vehicle parts are groups of five cels (tan, green, yellow, two more), structures pair tan/green, projectile art and stats identified, all 84 coastal decorations labelled by look, 200+ cels renamed. Unresolved: heli rotor/missile bars, explosion frame lists, several unowned families. See [document 46](46-worked-example-registry-audit.md).
- **Vehicle hit points and armour traced; enemies can now be killed (2026-09-20):** the vehicle class's hit callback `FUN_0040c460`, explosion objects identified as bytecode scripts, the water state. See [document 47](47-worked-example-vehicle-damage.md).
- **Descriptor scan and wrecks (2026-09-20):** every draw descriptor found by scanning the binary; Heli rotor, flag, wreck art identified (`game/wreck_3d.gd`), the shell now uses its real cel. The object at `0x443740` remains. See [document 48](48-worked-example-descriptor-scan-and-wrecks.md).
- **Explosion/effect frames decoded (2026-09-20):** cels 1084-1739 are 33 animation clips (frame count and timing packed into a second part layout); registry renamed `effect.anim.*`. Nothing plays them in the port yet. See [document 49](49-worked-example-effect-animations.md).
- **Explosion records traced (2026-09-20):** 26 explosion scripts decoded (`tools/data/explosion_records.json`); which coastal id, projectile surface and fire handler plays which clip is now read from the code, and the only area-damage explosion is the mine's (class 10). See [document 50](50-worked-example-explosion-records.md).
- **Explosions play in the port (2026-09-20):** how an explosion is drawn traced (`FUN_0042dd90`: start/end/fade progress bytes, variants, scale); destroyed pool targets and vehicle/target hits now play their traced records, and a collapsing tile changes state at the script's TILE_STATE op, not at the hit. Sounds and the arcing/elevated shots (see document 52) remain. See [document 51](51-worked-example-explosion-playback.md).
- **Muzzle and shell flight traced (2026-09-20):** the Tank's muzzle is 12 units ahead and 7 up, a level shell keeps that height and vanishes silently at its lifetime unless it hits something (so land/water/pavement impacts belong only to arcing types and the elevated shot), and the muzzle flash plays attached to the vehicle. See [document 52](52-worked-example-shell-flight-and-muzzle.md).
- **Collision shapes traced (2026-09-20):** shells are swept points tested against real shapes -- a 15 x 22.5 polygon for the Tank, per-id boxes for 62 coastal ids -- replacing the placeholder hit radii; any tile with a shape can be shot and destroyed (palms burn to debris via the op-21 timer). The pool accounting for non-active candidates remains. See [document 53](53-worked-example-collision-shapes.md).
- **Vehicle collision traced and applied (2026-09-20):** vehicles are blocked by tile shapes and other vehicles (turn undone, then a quarter-speed bounce), bushes and crates are flattened above 0.5 units/tick, rocks and zones are passed; See [document 54](54-worked-example-vehicle-collision.md).
- **Fuel and service zones traced and applied (2026-09-20):** 400 fuel burns one per 32 units driven and destroys the vehicle at 0; standing over a pump's zone refuels 62.5 per second. Rearm zones (ammo 150, refilled ~1 per tick) are traced but not applied (ammo deliberately skipped); the kind-3 zones turned out to be team gates (document 56). See [document 55](55-worked-example-fuel-and-service-zones.md).
- **Team gates traced and applied (2026-09-20):** coastal ids 43/44 are gates that open for an own-team vehicle (bars slide apart at 0.5/tick, the door leaves retract, the light turns blue), stay open while it is within 32 units, close behind it and hand the tile back; enemy-colour gates stay shut and shells damage the tile through them. See [document 56](56-worked-example-team-gates.md).
- **The flag and the match end (2026-09-20):** only a Jeep can take the flag (confirmed in three places); it hangs from the carrier, the action key drops or takes it, and a Jeep carrying the other pool's flag onto its home tile wins the match. The Jeep is now playable (traced stats, shape, fuel; no gun yet); `V` switches Tank/Jeep at the home tile and `F` is the flag action (port conveniences). See [document 57](57-worked-example-flag-and-match-end.md).
- **The MSV is playable (2026-09-20):** shots are generalised (projectile table extracted, `Vehicle.shot` signal, descriptor-drawn projectiles); the MSV fires its traced three-rocket salvo with reload and back-blast. Mines, the Jeep gun/missile and the Heli follow. See [document 58](58-worked-example-msv-rockets.md).
- **Vehicle part animation traced (2026-09-20):** the draw callbacks do all vehicle animation. Applied: the Jeep's wheel strip and the MSV's canister count/slide. The Tank's tracks are not animated by its code (both init callbacks are now read too: variant 2 is the 10-tick hit flash, now applied to all three playable types); the Heli's gear/rotor and the Jeep's water look wait for flight and water mode. See [document 59](59-worked-example-vehicle-part-animation.md).
- **Debug vehicle swap (2026-09-21):** `F1` / `F2` / `F3` turn the player into a Tank / Jeep / MSV anywhere, at once, with fresh hit points, fuel and weapon state (a flag carried by a non-Jeep is dropped). `RF_DEBUG_SWAP="frame:type,..."` swaps at given frames for scripted checks (with `RF_DEBUG_DRIVE=1`, while moving). Port-only, alongside the `V` home-tile switch and `RF_VEHICLE=tank|jeep|msv`.
- **The MSV's mines and the explosion damage box (2026-09-21):** `M` lays a mine (every 140 ticks). It is inert for 158 ticks (blinking and beeping faster: a fuse), then armed, and a moving vehicle touching it sets it off. Its explosion owns a damage box that hurts vehicles and buildings for 2.4 s. The dropper is safe because the mine has no collision shapes until it arms (traced; the earlier placeholder is gone). See [document 60](60-worked-example-mines.md).
- **The Jeep's weapon (2026-09-21):** the Jeep's "machine gun" and its "homing missile" turned out to be one lobbed missile that picks its target (an enemy within 61 units, else the last tile it bumped, else a random point ahead) and lands on it, doing 1.5 damage. The space bar fires it every 30 ticks; the missile's cels were mislabelled decorations. See [document 61](61-worked-example-jeep-missile.md).
- **Water, sinking and the Jeep's swim mode (2026-09-21):** the rule everything called "in water" is traced (land / shallow / deep from the tile under a vehicle, with shore polygons). A vehicle in deep water now sinks and is lost after ~35 ticks unless it is a Jeep in swim mode (`B`; a one-second ramp during which it cannot move; 0.25 speed in water, 0.01 on land); water slows everything to 0.75; mines are refused and missiles splash. The Jeep also creeps forward when a turn key is held without the throttle, and its wheels reshape and a wheel square appears under it as it goes into swim mode. See [document 62](62-worked-example-water-and-swim-mode.md).
- **The helicopter (2026-09-21):** it flies (turns with inertia, strafes with `Q`/`E`, banks, climbs to 50 and stays there, clear of every building), fires guns (`Space` down, `Z` level) and bombs (`X` switches), and draws a blurred spinning rotor, its tilt and a ground shadow. Start-up and landing at the base, ammo, sounds and being shot down (needs the MSV's raised rocket) are open. See [document 63](63-worked-example-helicopter.md).
  **Update (2026-09-22, document 85), user-flagged from real gameplay footage ("different textures used when the helicopter is in full flight"):** document 63 had already traced the fix, just not applied it -- the rotor's corner set is picked by a mode (`whole(speed) - 1` clamped 0-3, or **mode 4** while the start-up value is below 1), and this file only ever drew mode 3 (the full-width blur), from tick 0. Now `game/vehicle_render_3d.gd` picks the real mode from `Vehicle.heli_spinup_stage`/`rotor_speed_steps` (both already ported by document 79, just never read by the renderer). **Corrected same day, after a user report that a spinning-speed state was still missing:** mode 4 is not one static blade -- re-disassembling the draw callback (`0x403420`) byte-for-byte found it draws cel 588 (`vehicle.heli.rotor.c`) *twice*, at two rotations that start overlapped and scissor apart to 180 degrees as the start-up timer runs (`Vehicle.heli_spinup_progress() * 180`, a new public getter for the already-ported field). A freshly spawned or undocked Heli now shows this two-blade scissor through the ~56-tick silent phase, then the widening spinning bar through the ~160-tick ramp, matching document 63's numbers exactly (verified by `tools/tests/heli_rotor_mode_check.gd`, which now also samples the second blade's angle, and screenshots). The dying/wreck sequence (document 63's "Shadows", the *other* branch of the unrelated dispatcher `FUN_0042eae0` this investigation also touched) remained unmodelled at the time -- see document 87's update below.
  **Update (2026-09-23, document 86) -- the landing sequence is now modelled too.** Disassembling
  the descent's own tail found it hands off to the rotor spin-down (`FUN_0040ecd0`) only once the
  fall actually finishes, not during it. That function decrements `rotor_speed_steps` at the same
  rate the start-up ramps it up (`HELI_SPINUP_B_RATE`), down to a floor of 0.5 rather than 0, then
  plays **`Servo`** -- confirming document 77's original guess for that cue was correct all along.
  `FUN_0040ede0` then runs a second timer down from 1.0 at `HELI_SPINUP_A_RATE` (the start-up's own
  silent-phase rate, reversed) before the vehicle is released to dock. `game/match_controller.gd`
  gained `dock_state` 3/4 for these two stages; the existing rotor-mode renderer (document 85) needs
  no changes since it already reads `rotor_speed_steps` directly. Verified by
  `tools/tests/heli_landing_check.gd`. Not reproduced: the original's exact-angle-alignment check
  that picks which tick to stop on (a cosmetic nicety, not traced -- see the document for why).
  **Update (2026-09-23, document 87) -- the vehicle dying/wreck sequence is now modelled too.**
  `FUN_0040c460`'s death branch is the same for all four types after all (`record+0x234`, the
  "dying handler" document 47 flagged as open, reads 0 for every type -- there is no per-type
  branch); document 63's claim that the Heli's own dying handler lived at that address was wrong,
  off by 4 bytes (the real value `0x40eae0` sits at `+0x230`, a Heli-only extra hook, not the
  generic `+0x234` slot). `Vehicle._die()` (replacing three duplicated death sites, including both
  fuel-out paths per document 55) now emits a `wrecked(info)` snapshot immune to `MatchController`'s
  own immediate respawn resetting the same node, and `game/wreck_3d.gd` picks the correct per-type
  decal (Tank/Jeep/MSV share geometry, only the Heli's is a different, off-centre rectangle) and
  falls it from the death height under gravity before settling, so a Heli shot down mid-flight no
  longer drops an instant flat decal in mid-air. The exact fall timing is a flagged guess, not a
  trace: chasing the wreck's own gravity constant hit a contradiction (the class's move-function
  slot reads 0, which would imply the object destroys itself on its first tick) that wasn't
  resolved. Also retracted: the tumbling-intact-body render and the Heli's trailing shadow object
  during the fall (both traced, neither reproduced -- a deliberate scope cut given the fall's own
  correctness is already in doubt). Verified by `tools/tests/wreck_fall_check.gd` and screenshots.
  See [document 87](87-worked-example-the-vehicle-dying-wreck-sequence.md).
  **Update (2026-09-24, document 88) -- the screen after a death: the laughing skull.** User-reported ("a death
  screen with a laughing skull ... after losing any vehicle"). The wreck's init schedules, after the type's delay
  (record `+0x260`: 120 ticks, the Heli 200 -- which also confirms the wreck really lies there that long), the
  player's *loss sequence*: a skull spins in over the live view (30 ticks), the view fades to black (50), the skull
  laughs -- **`Laugh` plays here, the cue's only site** -- through a 201-tick mouth animation, then fades out (~15) and the
  vehicle choice opens (the match is lost instead if no vehicle is left). The skull is cels 2126-2139, which the registry
  had guessed to be "trooper portraits" (corrected: `ui.death_skull.{tan,green}.f1-f7`); a player sees the *other*
  team's helmet. Now in the port (`MatchController._death_tick`, `game/death_skull_view.gd`, verified by
  `tools/tests/death_sequence_check.gd` and screenshots), replacing the instant respawn. Open: the skull's screen position,
  spin direction, the two-player phases and remaining-vehicle icons, the `b5c0` stock gating, and opening the real
  choice grid afterwards instead of the placeholder respawn. See
  [document 88](88-worked-example-the-loss-sequence-and-the-laughing-skull.md).
- **Turret aim and raised fire (2026-09-21):** the Tank's turret turns independently (`Q`/`E`, `R` recentres) and both the Tank and the MSV have a raised gun (`Z`: 25 degrees up, shots 40 degrees up that climb to 55, the Heli's altitude). The Heli can now be shot down. See [document 64](64-worked-example-turret-and-raised-fire.md), which also corrects the MSV rack corners of document 59.
- **The flag object (2026-09-21):** the original's flag drawing (base plate, waving cloth with 13 frames per team, the carried two-quad version), its wave counter, heading easing, attachment offset and water drift are traced and applied; the registry's mislabelled flag cels are fixed; the flag's "flutter child" turned out to be a radar blip. See [document 65](65-worked-example-the-flag-object.md).
- **The ruin grabs the flag (2026-09-21):** contact with any post of the finished building (coastal 63) takes the flag for a Jeep, through the tile callback `FUN_00432d80`, which the port lacked (the Jeep looked stuck on it). Level 1 is also completed by an in-scene autoplay (`RF_DEBUG_AUTOPLAY=1`), and the interface's per-player panel is first-pass traced (frame, vehicle icon, weapon counts). See [document 66](66-worked-example-the-hud-panel.md) and [document 67](67-worked-example-autoplay-placeholder-hud-and-ruin-grab.md).
- **HUD elements (2026-09-21):** each vehicle type adds elements to its player's panel through `FUN_00412cd0` (kinds 1-9 at `0x446930`); kind 5 is the fuel bar (40 x 4 at panel + (88, 12) for the Tank, tweened, colour by fill), kind 6 the radar (a 32 x 32 tile window of a 128 x 128 bitmap at panel + (19, 11), a grid cel, and probably the Jeep direction arrow). Open: kinds 2-4 and 7-9 (health?), the palette at `0x446760`, the radar painter `FUN_00412dc0` and blips `FUN_00413100`, the other types' blocks. See [document 68](68-worked-example-fuel-bar-and-radar-element.md).
- **Radar bitmap and blips (2026-09-21):** one byte per tile (land `0x87`, water `0x91`, flagged tile `0xc9`, per-coastal-id colours for buildings/structures split by team), painted by `FUN_00412dc0`; blips are point lists (`FUN_00413100`): the flag is a 4-pixel pole with a 2 x 2 pennant (`0x45` tan, `0x67` green) that blinks every 15 ticks. The colours come from the shared palette (index - 10); the port now has a radar window (`game/radar_view.gd`). Open: the grid/bracket cels, the Jeep arrow, bit 31 of the tile word, the other element kinds (health), the announcer. See [document 69](69-worked-example-radar-bitmap-and-blips.md).
- **The panel per vehicle (2026-09-21):** each of the four vehicles' panels is traced: base picture (cels 1943-1946), fuel bar, one or two ammo bars (Jeep: 16 pips), a radar (Jeep: a compass dial); **no health readout exists**. The port draws base, fuel bar and radar from the records (`game/hud_panel.gd`). Open: ammo bars (with ammo), the Jeep compass, bar colour format, kinds 3 and 9, the announcer. See [document 70](70-worked-example-hud-panel-per-vehicle.md).
- **Jeep compass and announcer (2026-09-21):** the Jeep's compass value (how well it points at the other flag, else home; -16..16) is traced and drawn as a ring on its panel; the announcer's 18 voice lines and trigger logic are recorded (no audio yet, which audio file each line uses is untraced). See [document 71](71-worked-example-jeep-compass-and-announcer.md). The radar has a ping element (cels 1947-1962), not drawn.
- **Ammunition (2026-09-21):** stocks (150 / 16 / 100 + 10 / 100 + 50), one round per projectile, the empty click's cooldown and the rearm zone's refill (one per tick, slot after slot) are applied, with ammo bars and the Jeep's 16 pips on the panel. Open: the sounds, the pips' animation, the vehicle-stock counts. See [document 72](72-worked-example-ammunition-and-panel-bars.md).
- **Vehicle stock (2026-09-21):** the level's T, J, A, H (default 3, 8, 3, 3; 255 = unlimited) are how many vehicles of each type the player has; creating one spends one, docking returns one, all four at 0 is the lost condition (handler `0x418390`, untraced). The port tracks the stock with placeholder choice logic and a text line. Open: what the original does at its base to choose a vehicle (and shows with the counts panel), the mine reserve, `M`. See [document 73](73-worked-example-vehicle-stock.md).
- **Bar colours and mines (2026-09-21):** the bars are drawn in blit mode 10, whose colour word is 15-bit RGB matched to the nearest palette entry (applied, document 74). Mines: tile bit 31 means a mine lies there (purple on the radar); `M` mines are scattered at the start of one-player levels (road-side tiles first), and the MSV's layer works only with two players (document 75). Open: the mine reserve, `unk4`'s pools, the original's random positions.
- **Vehicle choice at the base (2026-09-21):** the original's choice is a 2 x 2 grid (Heli, MSV / Tank, Jeep) with the counts left, a neighbour table that skips empty types, and a confirm button; the port reproduces the cursor logic and draws it with the traced icons and digits (`V` on the home tile opens it). Open: the docking trigger, the fades and sounds, the lost sequence's end screen, the respawn choice. See [document 76](76-worked-example-vehicle-choice-at-the-base.md).
- **Docking and undocking (2026-09-21):** to dock, stand still on your pad within a small distance of its centre and press any fire button (Tank / MSV at once; Jeep after returning its own flag; Heli lands itself first); the vehicle sinks 70 ticks, the view fades, the choice grid opens, and a confirm puts the new vehicle on the pad at once. The port does this (`V` stays as a port-only quick swap). Open: the sounds and fades, the pad art change / glow, the dock object's drawing, the Heli's rotor and gear stages, the flag delivery in the lift update, the view scripts. See [document 77](77-worked-example-docking-and-undocking.md).
- **The hangar screen (2026-09-21):** the docked choice screen is traced and drawn as the original does: the deterministic sky / cloud / dirt backdrop (the C runtime's `rand`), the hangar with its four bays, the cursor's box, spotlight and pointer, the lift, the panel with the counts, the map window, the fades, and the per-vehicle confirm script (the picture slides onto the lift and rises: about 144 ticks). Document 76's neighbour order and grid are corrected there. Open: the sounds, the panel's slide-in. See [document 78](78-worked-example-the-hangar-screen.md).
- **The Heli's start-up (2026-09-21):** record `+0x14` is a four-stage chain that runs once when a Heli is created (initial spawn, undocking): ~56 ticks silent, then ~160 ticks of the rotor visibly ramping to full speed (the same field that drives its ongoing spin), and only then does the already-modelled climb to 50 units run. Applied (`Vehicle.heli_spinup_stage`, the renderer's rotor now ramps); a pre-existing bug in `tools/tests/ammo_check.gd` (its test position was exactly the home pad centre, so docking silently ate every shot once document 77 landed) was fixed along the way. Open: the bank/pitch bob, the sounds. See [document 79](79-worked-example-the-helis-startup-sequence.md).
- **The hangar hatch and dock readiness (2026-09-21):** the home pad (cel 90/91) is a hazard-striped metal hatch, not a "bullseye" — the registry is corrected — and it had been hidden the whole time under an always-on debug spawn-marker circle, now off by default (`RF_DEBUG_MARKERS=1` to see it). `FUN_0040b400` (trigger: parked in dock position, not pressing fire) rotates a real, precisely-traced 7-word palette region (entries 12-14) at ~9.1 steps a second — but pixel-checking cel 90/91's own art found it uses none of those entries anywhere, so the animation is confirmed *not* to be the hatch flashing; what it does affect on screen is unidentified. The port's coloured ring plus HUD text (`MatchController.can_dock`) is now documented as a full invention (trigger and cadence real, look invented), not an approximation of a known effect. Also found and fixed while screenshotting: the hangar choice screen's own pointer was drawn mirrored for the right-hand bays via a negative-size `Rect2`, which doesn't scale through Godot's `AtlasTexture` — the two right-hand pointers floated off in the dirt; the (untraced, invented) mirroring is removed. See [document 80](80-worked-example-the-hangar-hatch-and-dock-readiness.md).
- **The dock actually sinks (2026-09-22):** re-disassembling `FUN_0042efc0`/`0042f054` in full found the dock object continuously falls at 0x4CCC/65536 (0.3) units a tick, starting a view fade-out past -16 units, and is destroyed only once it has BOTH reached -32 units AND a separate 70-tick timer has run out (the depth is the slower of the two, ~107 ticks) — the port previously just hid the vehicle instantly. Now `Vehicle.z` sinks visibly and is occluded by the ground plane through ordinary depth testing, no renderer changes needed; a screenshot sequence and `tools/tests/dock_sink_check.gd` confirm the exact tick numbers. See [document 81](81-worked-example-the-dock-actually-sinks.md).
- **The sound engine and a full cue table (2026-09-22):** every "sound `0xNNNNNN`" address documents 44-81 recorded turns out to be one row of a single 0x18-byte descriptor table (base `~0x0044b500`), traced end to end from the generic command queue (`FUN_004232d0`) through the actual voice-start function (`FUN_00408170`) to a real filename string and its `build/sound/*.wav`. All ~38 one-shot rows are resolved to a file in `tools/data/sound_cues.json`; two (the empty click, the Heli spin-up chime) are wired to a real trigger in `game/vehicle.gd` and played by the new `game/sound_manager.gd`. Open: the other ~36 traced-but-unwired cues (each has a candidate trigger noted), positional volume/pan, fade envelopes, looping ambience (a separate untraced sub-block), and the announcer's voice lines (document 71 — still no matching audio file found at all). See [document 82](82-worked-example-the-sound-engine-and-cue-table.md).
- **The Heli's weapon-select icons (2026-09-22), user-flagged from real gameplay footage:** the panel's kind-9 element (Heli only, document 70's "Not done" list) draws two icons whose lit/dim pair is picked by `obj+0xc` bit `0x10000000` — the exact same weapon-select flag document 63 already traced (`FUN_0040e600`'s fire dispatch, `FUN_0040e7a0`'s toggle). Cels 1977-1980, misclassified by the original bulk pass as generic UI icons, are the bomb icon (rocket silhouette) and the gun icon (twin-bar silhouette), each lit/dim; the registry is corrected. Applied: `Vehicle.heli_weapon_slot()`, `game/hud_panel.gd` draws both for the Heli only. See [document 83](83-worked-example-the-helis-weapon-select-icons.md).
- **The table at `0x44b9a0` is the engine's whole sound-index array, not a small pool (2026-09-22).** It lists every descriptor document 82 resolved, in order, starting at index 0 (`Button`); every explosion/impact record's already-extracted `SOUND n` opcode (`tools/data/explosion_records.json`) is a plain index into it. Cross-referencing the two resolved all eight hit-surface sounds with no guessing (ground/water/pavement/vehicle/tile hits) and one previously-unresolved address (`0x44b5b0`, index 2 = the new `SmallBoom` cue). Applied via `MatchController.impact_effect` (already existed for visuals) plus the Tank's cannon fire and the MSV's mine-throw (one of three picked at random, a marked port choice). See [document 84](84-worked-example-the-sound-index-table-and-impact-sounds.md).
- **Same technique applied to tile-destroy effects and the mine explosion (2026-09-22, same session as document 84):** `tools/data/explosion_records.json`'s per-record `coastal_destroy_effect_ids` plus the index table gives an exact coastal-id -> sound-cue map (`MatchController.DESTROY_SOUND_CUES`) with no guessing — the large majority just play the newly-resolved `Boom` cue (index 1, the same file as `SmallBoom` at a different pitch), a few ids play `SmallBoom`/`ExplLarge`/`BushCrush`/`SmDirtHit` instead. The mine's own explosion record (`0x445058`) scripts `SOUND 14` (`ExplLarge`) then `SOUND 1` (`Boom`, not reproduced — one sound per event is the port's model). 30 of the 42 traced cues are now wired — the mine's fuse-blink beep (`Button`) was already a real signal (`Mine.beep`, documents 50/60) waiting to be connected, done the same session. Still open: `ExplDebris`/`ExplLow` (no record found that plays them yet), `FuelWarn` (the fuel bar's own blink logic, `FUN_00411f80`, has no sound call at all — the trigger must be elsewhere, not found), `JeepStart`, `Laugh`, `ManCrush`, `PanelUp`, `Reload`, `Servo`, and the debug-only `TestSnd L/R`.
- **`PreRaise` wired (2026-09-22, document 85 addendum):** `tools/data/selector.json` already had the hangar confirm script's exact step lists, including two `["sound", idx, ...]` steps whose index (0 or 1) was never connected to a real cue. Document 78 had already resolved `0x449260`'s two entries to `0x44b7f0` (`PreRaise`) and `0x44b7d8` (`Raise`, already applied to the dock's own sink) — index 0 is `PreRaise`, index 1 `Raise`. `game/selector_anim.gd`'s `step()` now emits the real cue for each `"sound"` step instead of a placeholder no-op; Tank/Heli's script plays `PreRaise` twice (once before `platform_up`, again before `slide`), Jeep/MSV once. Verified by `tools/tests/preraise_sound_check.gd`. **31 of 42 traced cues are now wired.**

## Level 1 (RFMAP001) end to end (2026-09-21)

`tools/tests/playthrough_rfmap001.gd` plays the level through the real game logic with a crude autopilot: **it is completable**. The level is a 766-tile island
with one spawn (tan, tile 67,67), one target building (pool b, tile 75,56; pool a is empty) and no enemy vehicles. The route: a Tank shoots the building
(6 hits, 126 ticks) -> the ruin `62` (6 hits of its own, 120 ticks; the flag appears at once but sits inside the ruin's solid box) -> id `63` (four corner posts, the
flag reachable) -> back to the home tile, `V` for a Jeep (only a Jeep can carry) -> the flag -> home: `match_over(tan)`. Notes from the run: the Jeep cannot crush
bushes or pass rocks, so it must route around them; palms block the Tank too. **Update:** it is also completed inside the real scene by the debug autoplay, and a placeholder panel (vehicle, hit points, fuel, objective, keys, restart with Enter) exists (documents 66, 67). Still port-only: `V` at the home tile switches vehicle.

## Untraced choices (revisit; a standing list, kept short on purpose)

Rule (user, 2026-09-21): never make our own choice silently; if one is unavoidable, mark it in the code and list it here to trace later.

- **Team recolouring is a port feature (2026-09-24, plan 2.7.7).** The original only has tan and green drawings; any other colour is made from the tan art by a rule that is the port's own (hue replaced, saturation and brightness scaled to the colour's mean), checked against the real green (~7 / 255). The six preset colours, the radar drawing a generated colour's mean, and treating every pixel where tan and green differ as team paint are all port choices.
- **A submarine exists in the art, owner untraced (user-identified 2026-09-24).** Cels 630-654 (were `prop.watercraft_distant.*` and `vehicle.jetski.*`, both visual guesses) are one 25-frame sequence of a submarine surfacing or diving: now `vehicle.submarine.01-25`, confidence `visual`. Nothing traced references them yet; the sound-test list has a `Sub` cue (document 31). Open: which object class draws them, whether it is scenery or a real enemy/level object, and which way the frames play.
- **`vehicle.tank.rotation.*` (cels 218-240) is still an unverified label.** Renamed from `hovercraft` with the rest of the Tank block (2026-09-24), but the Tank's traced descriptor never uses these frames (document 37); visually the hull shrinks and turns edge-on, which may be a sink, a flip or a distant view rather than rotation. `vehicle.gd`'s legacy 2D path still draws them. Also renamed to neutral visual names because nothing ties them to the Tank: `prop.fragment_grey.01` (614) and `prop.ring_yellow.01-02` (622-623).
- **The Heli's full-speed rotor may look more solid/opaque than the reference footage, unresolved (2026-09-22).** User-flagged after comparing a clean reference frame (Heli in level flight over open water) against a fresh screenshot at mode 3: the footage's blur reads as a thin, translucent streak; the port's is a solid, opaque painted bar at the traced width (verified correct against raw corner data, not just prose -- see document 85). Chased the render pipeline from the part dispatch (`FUN_0041b2b0`) through the CCB corner-assignment (`FUN_00419820`) to the generic render-queue allocator (`FUN_00413c90`, shared by every sprite in the game): no branch anywhere applies a distinct blend/transparency mode to this part. Its only non-default flag (`0x8`) is the ordinary team-colour bit; the cel itself is classified as a plain opaque sprite (not the "effect_mask"/blend-table kind the game's real soft-shadow cels use), with a binary (not gradient) alpha channel. No code-side evidence of a real transparency mechanic was found. Leading theory, not proven: at 4 steps of 5.625 degrees/tick and ~62.5 ticks/sec, the blade spins at roughly 4 revolutions/second -- plausibly enough for real motion blur plus video compression to read as translucent on its own, with no game-side effect needed. Revisit only with stronger evidence (e.g. a paused/frame-stepped reference) that the original engine itself renders this blended, not just fast.

- **The hatch DOES open, and the pit, lid and rise are now in the port (document 89, 2026-09-24).** The pad is a pit model drawn by the lift objects with a two-leaf lid (cels 822-825, formerly mislabelled `rescue_cross`; art 92 is the pit's hazard-border surround, formerly mislabelled a blank): undock = leaves slide apart over 60 ticks while the vehicle rises -32 -> 0 at 0.3 a tick (~107 ticks); dock = the 70-tick timer counts down so the leaves slide shut over the sinking vehicle (code only: no docking in the reference footage). Implemented in `MatchController` (`pad_open`, `pad_age`, `pad_leaf_offset()`), `game/hangar_pit_3d.gd` and a real hole in the ground texture; checked by `tools/tests/pad_hatch_check.gd` and screenshots. **The camera swoop-in is done too (document 90):** the original snaps the camera to height 250 / pitch 64 and eases to -170 (Heli -100) / 24 with the rig template's rates (~205 ticks); the port uses the traced easing for the timing, with a setting to turn it off (`GameSettings.camera_swoop_in`, `user://settings.cfg`, or `RF_NO_SWOOP=1`); its zoom and tilt at the start (`SWOOP_START_ZOOM`, `SWOOP_START_TILT_DEG`) are port choices read off the footage, not a traced mapping. **The border over the leaves is traced (document 89, Step 5):** the original queues the pad tile again after the mechanism, so the border covers the walls, plate, leaves and strips; the port draws them under the ground plane. **Still open:** the pit's object-space orientation and whether the walls move with the object's height (port choices), the 2-unit ring between walls and tile edge (now known to be the tile's border, so probably settled), and whether the leaves show on neighbouring tiles in the original (the port hides them).
- **`Vehicle._update_water()` plays TireIn/TireOut on the land<->water `water_class` transition — a port CHOICE, not a traced trigger** (document 82): the filenames (`Sound/Tirein.SDT`/`Sound/Tireout.SDT`) and document 62's water-class field make this a plausible mapping, but no code path calling these two descriptor addresses was actually found/read. Revisit if `FUN_0042f280` or its caller is ever traced.
- **The MSV's mine ammo bar reportedly shows as empty at all times in single player (user-flagged 2026-09-22), not yet reproduced.** Checked and ruled out: `ammo_max[1]` is 10 in `tools/data/vehicle_types.json` (not a zero-max bug); `_apply_type()` sets `ammo[1] = ammo_max[1]` on every `set_vehicle_type()` call (spawn or the confirm screen, same code path); `mine_layer_enabled` (gated on player count, document 75) only guards firing in `_drop_mine()`, nothing reads it for display. A screenshot taken right after spawning as the MSV (`RF_VEHICLE=msv`) shows the mines bar full, matching the rockets bar. Needs either a repro screenshot/recording from the user's own session or a description of exactly when it appears empty (right after docking? after some ticks? a specific level?) before chasing further.
- **The Tank likely has its own lit/dim indicator for level vs. raised shot (user-flagged 2026-09-22 from real gameplay footage), still not found — and kind 3 is now RULED OUT as the mechanism (2026-09-22).** Document 83's kind-9 element is confirmed Heli-only (gated by `CMP dword ptr [EBX],0x3` in the panel-setup function), so it isn't the mechanism for the Tank either. Kind 3 (`0x411c90`, document 70's "a second base variant") was fully disassembled byte-for-byte this session (not just decompiled): its steady-state per-frame path does **not** select a cel at all — it compares an eased offset (from the same slide-easing utility `FUN_0042cdd0` that drives kind 2's panel slide-in, document 70) against a cached value and, when they differ, ORs a dirty-region bitmask (`0x1f` or `0xf`) into a per-player array indexed by `[0x480d9c] XOR 1`. That's screen dirty-rectangle invalidation bookkeeping, not an icon. This corrects (not just extends) this list's own previous entry, which had read a partial disassembly as "reads its cel index from slot+8" — that claim did not hold up once the full function was read. What kind 3 *is* confirmed to need: the call site (`0x00418339`, inside the same function document 68 disassembled) only fires when the vehicle record has a linked sub-object at `+0x74` — true for the Tank's own linked turret object (document 39) — so kind 3 is plausibly still turret/elevation-adjacent, just not through a cel selector in this function. Wherever the actual lit/dim image comes from (if kind 3 is even the right element at all) has not been located. **Next step, if picked back up:** decompile (not just disassemble) `FUN_00412cd0`'s own kind dispatch to see whether kind 3's *draw* callback is a separate function from this one (the way kind 2's init `FUN_00411b70` and draw `FUN_00411bb0` are two functions, per document 70) — this session only found and read one function at `0x411c90`, which may be only half the pair.
- **`MatchController._on_mine_dropped()` picks one of the three "Throw Grenade1" sounds uniformly at random — a port CHOICE, not traced** (document 82): the three descriptors (`Sound/Throw1-3.SDT`) share an identical debug label and read as launch-sound variants for the MSV's mine layer, but which one plays when (random? alternating? by mine index?) was not found in the code.
- **`MatchController._on_impact_effect_sound()` picks one of the four MetalHit variants uniformly at random for a vehicle hit, rather than the original's `REPEAT 4` sequence (document 82).** The traced script for record `0x444b68` plays `SOUND 30`, `31`, `32`, `33` in a repeating cycle over the explosion object's multi-tick lifetime; the port's hit sound is a single discrete event, so it can't reproduce a multi-tick sequence without modelling the whole scripted-object timeline (out of scope for a sound cue).
- **`game/sound_manager.gd` plays every cue flat and non-positional, on the Master bus, with no distance falloff or pan** (document 82): the original's `FUN_00408050` almost certainly computes volume/pan from the "source" object's position relative to the player, but that function was not read. Also untraced: the per-cue fade envelope (`+8`/`+9`/`+0xa` bytes) and the looping stepper (`+0xb` bit `0x20`) — every cue in the port is a fire-and-forget one-shot at fixed volume.
- **The dock-ready ring is a full invention** (`game/dock_ready_indicator_3d.gd`: yellow/orange/red/white/near-black, a ring shape): `FUN_0040b400`'s trigger and ~9.1 steps/second cadence are traced, and its exact 7-colour rotate is traced too, but it's confirmed *not* to touch the home pad's own art (document 80) — what it actually animates on screen is unknown, so nothing about this port effect's look is the original's.
- **The hangar pointer no longer mirrors** for the right-hand bays (document 80: the old mirroring was invented and buggy); whether the original mirrors it at all is untraced. Its and the vehicle picture's small pixel nudges were also invented (and wrong) and are removed — both now draw at the raw traced coordinates, which land the pointer's two ticks in two of the rail's seven carved slots and seat each vehicle flush on its tray; which two of the seven slots the original actually lights is untraced.
- **The ground flag's camera tilt** (`(cam+0x24 + 0xffe70000) >> 3`) is not reproduced (document 65).
- **The placeholder panel** (`game/placeholder_hud.gd`: labels, the objective wording, the restart key Enter) and the debug autoplay are the port's own; the original's panel is frame cel 1940 + vehicle icon + weapon counts + radar (document 66), fuel/health displays and announcer still untraced.
- **The panel's scale and position** (3 px per original pixel, bottom-left), the radar's black outside-the-map background, and the **fuel bar colours read as 15-bit RGB** (unverified format, document 70) are the port's; the original's frame, grid, bracket cursor and arrow are not drawn yet (document 69).
- **The compass's home position** (taken as the player's spawn) and its per-value palette (document 71).
- **Enemy placeholder vehicles fire without limit** (`infinite_ammo`; document 72).
- **The scattered mines' positions** use a seeded generator, not the original's (document 75); the MSV keeps a full 10 mines whenever the (two-player only) layer is on.
- **Vehicle choice and loss:** the grid's logic is traced (document 76); the `V` quick swap (an option), the keys, no cancel, respawn taking stock without a choice, the lost banner and the stock text line are placeholders; the MSV keeps a full 10 mines instead of drawing on the reserve (document 73).
- **Port-only input keys** (Space / Z fire, X weapon switch, Q / E strafe, M mines, B swim, F flag, V and F1-F4 vehicle swap): the original reads input bits; the key layout is not its concern.
- **The mine's drop offset** is reproduced as coded (only the y component), which looks odd; confirmed as the code, not as the intent (document 60).
- **The Jeep missile quad** is drawn from the descriptor's half-width corners as read; the draw function `0x41b750` was not shown to mirror it (document 61).
- **The Heli's start-up is now traced and applied** (document 79: blade accel, rotor ramp, then the existing climb); its bank/pitch bob (tables `0x4454a0`/`0x4454d8`) is not. A live Heli casts no shadow (only its dying sequence does, traced 2026-09-21). **Update (2026-09-23, document 87):** the dying sequence's death branch is now modelled, but the shadow object (a Heli-only hook at record `+0x230`, not `+0x234` as first thought -- `0x40eae0`) and the tumbling-body render are not reproduced; the port falls a flat decal instead. See document 87.
- **Respawn and enemy AI** are placeholders written before tracing (`MatchController._on_player_destroyed`, `enemy_vehicle.gd`).
- **Water landing of shots** uses "any water" for shallow as well; the exact sampling of `FUN_0042f5b0` was read but its box argument is a compiler-garbled stack layout (document 61).

## Mechanics needed for the remaining sound cues (2026-09-22)

Of the 42 traced sound cues, 35 are wired (`PreRaise`, `FuelWarn`, `JeepStart` and `Servo` resolved 2026-09-22, `Laugh` 2026-09-24, see above); the other 7 each need either a real mechanic that
doesn't exist in the port yet, or more tracing of code nobody has read closely for this purpose.
Grouped by what's actually missing, not by cue name:

- ~~A vehicle's dying/wreck sequence is not modelled for any type~~ **Resolved (2026-09-23, document
  87):** traced and applied — see below. That trace also retracts the guess that it was the likely
  home for **`ExplDebris`**/**`ExplLow`**: the death branch (`FUN_0040c460`) has no sound call at
  all. Both cues remain unwired, no new candidate trigger found.
- **No on-foot infantry/crushable-person object exists** (already an open item below, found while
  classifying the asset registry) — the only plausible owner of **`ManCrush`**; can't be traced
  further until that object itself is found and read.
- **The HUD panel's own slide-in animation is not implemented** (document 78's "Not done" list) —
  a plausible but *unconfirmed* home for **`PanelUp`**; worth checking this specific function
  before looking elsewhere, since the name and the gap line up.
- **`FuelWarn` wired (2026-09-22).** Not the fuel bar's own draw function after all (`FUN_00411f80`
  really does call no sound) -- the trigger lives in the generic per-tick panel function
  (`FUN_0040b980`, the same one the Tank kind-3 investigation partially disassembled): `if
  (fuel_max << 13 > fuel)`, gated by a 120-tick cooldown. `fuel_max << 13` is exactly `(fuel_max
  << 16) / 8` -- confirmed by `fuel_max` itself living at record `+0x210`, the same field
  `Vehicle.fuel_max` already reads (document 55) -- so this is a plain one-eighth-of-a-tank
  threshold, not a per-type fraction. `game/vehicle.gd`'s new `_process_fuel_warn()` reproduces it
  directly; verified by `tools/tests/fuel_warn_check.gd` (silent above 1/8 tank, three warnings in
  260 ticks at 0/120/240 once below it). **32 of 42 traced cues are now wired.**
- **`JeepStart` and `Servo` both wired (2026-09-22).** Chasing `JeepStart`'s descriptor address
  (no direct call site, only data references) found a fourth vehicle-type record field (`+0x240`,
  `FUN_0040b980`'s panel-activation block: `if (record+0x240 != 0) play it` once, the same block
  that sets up the kind 5-9 panel elements) that holds a one-shot "this vehicle was just created"
  sound per type: Jeep `0x44b910` (`JeepStart`), Heli `0x44b808` (`Servo`), Tank/MSV both
  `0x44b520` (not one of the 42 traced cues, not actionable here). The apparent conflict with the
  already-wired `Heli` chime (document 79) wasn't one: that fires ~56 ticks later, at the stage
  1->2 transition, not at creation -- the two are simply sequential sounds for the same new Heli,
  not competing claims on one moment. `Vehicle.set_vehicle_type()` now emits both directly;
  verified by `tools/tests/jeep_start_check.gd` (each fires only for its own type, every time).
  Document 77's other `Servo` candidate ("rotor spin-down at landing", `FUN_0040ecd0`) is still
  unconfirmed -- if the original also plays this file there, the port only reproduces the
  creation instance so far. **34 of 42 traced cues are now wired.**
- **Needs more tracing, no missing mechanic:**
  - **`Reload`** — resolves to the same file as `Servo` (`Sound/Servo.SDT`) but is a *separate*
    descriptor; its own trigger is independent of the Heli landing work above and has not been
    looked for at all.
  - ~~**`Laugh`**~~ **Resolved (2026-09-24, document 88):** played by the loss sequence's darkening
    phase (`FUN_00418830`) ~200 ticks after any player vehicle dies; wired.
- **Not worth pursuing:** **`TestSnd L/R`** are debug sound-test-menu-only (document 31); the
  shipped game has no player-facing trigger for them at all.

## The reference gameplay video, and a Heli rendering lead (2026-09-22)

The user's real Windows 95 gameplay recording (`Silent Software - Return Fire - 1996 [63fXImW5szI].mkv`, 16:23, 1440x1080 @ 60 fps) was probed and sampled for the first time this session (`ffprobe`/`ffmpeg`, both already on this machine). It is **not** a level 1 recording specifically — most of it is later multi-island matches with enemy vehicles and a helicopter, which RFMAP001 has none of — so it's general HUD/vehicle reference rather than a level-1-specific source. Frames were extracted only into the session scratchpad, never into the repo: they're screen captures of the shipped game, the same category `.gitignore` already excludes for extracted `ART.CAR`/`RFM` data, so they're treated the same way — useful locally, never committed.

What it confirmed: the traced panel layout (documents 66-72) is right in broad strokes — a Tank frame with a rectangular radar and one ammo-style bar plus a pair of two-segment pip icons matches a real captured Tank panel closely enough to recognise on sight. It also surfaced one still-unidentified element: a yellow/black hazard-striped square icon with a red corner mark sits directly beside the fuel bar on **both** the Tank and the Heli panels in the recording — not yet matched to any of documents 66-72's traced kinds or the registry's `ui.hud.*` entries. Worth a proper look (screenshot-vs-registry-cel comparison) before assuming what it is.

**The Heli's "different textures in full flight" report is now RESOLVED — see [document 85](85-worked-example-the-helis-rotor-mode.md).** The lead first written here (that the Heli's real 3D box geometry, document 38, was unrendered) was wrong: it's been live via `game/vehicle_render_3d.gd` (the generic descriptor renderer, `tools/data/vehicle_types.json` key `"3"`) all along, alongside a real spinning rotor (document 63) — this session's own fresh Ghidra pass just hadn't yet found that a previous session had already wired both. The real gap was document 63's own already-traced rotor *mode* (a wholly separate static blade, cel 588 "rotor.c", during the ~56-tick start-up silence, then a widening blur through the ramp) never being read by the renderer, which had only ever drawn the full-width mode unconditionally. Fixed and verified by test + screenshot in document 85.

Direct pixel inspection of the Heli's cel groups this session (`build/car/art_atlas.png` + `art_atlas.json`, cropped by hand) found the registry's blanket "5 colour variants per part" assumption (document 46) is wrong for at least two of the Heli's part groups, and neither substitute trigger is traced yet:
- Part 0's group (cel 524 tan / 525 green / 526 yellow-flash) draws the fuselage top *with* its two side weapon-pod clusters (each a pair of stacked rocket/missile shapes) and a tail marking. Cels 527/528 — catalogued only as generic "alt3/alt4" slots — are the **identical silhouette with the pods missing**, just bare mounting sockets. Candidate triggers: weapon loadout, ammo depleted, or a damage state — no code read this session picks between them.
- Part 1/2's group (cel 529-531) draws clean, lightly-tinted cockpit canopy glass. Cels 532/533 draw the **same canopy shattered**, white cracked glass instead of blue panes. Reads like a damage state, not a colour.

Neither finding should be built on without tracing the selecting code first — same lesson as the Tank's turret saga (documents 38-40), where guessing which corner array/state a part belonged to took several wrong rounds. **Recommended next step, if this is picked up:** find what writes the "which of 5" index for these two part groups (likely a per-vehicle state byte read by the same generic per-descriptor renderer document 38 already decompiled), before attempting a Heli `VehicleBoxRender3D`-style port. Until then this stays a documented lead, not a mechanic.

## Still open

See plan section 4 for the current, precise state of each — this list is just pointers:

- **Level 1 accuracy, in order (agreed 2026-09-24):** (1) trace the flag: pickup, carry, drop, return, and where a win is declared (documents 24, 26; the port's "only a Jeep carries, home tile wins" is a placeholder written before tracing); (2) the building's 62 -> 63 stage (document 45); (3) terrain passability and height (elevation bits, height byte; plan section 4, items 2 and 11); (4) vehicle loss and the life system; (5) the real panel (fuel and health displays, announcer). Also possible: a frame-by-frame comparison of the port against the reference video.
- **Sound is unfinished (user, 2026-09-24):** (a) the continuous sounds are missing: engine, driving and flying loops for each vehicle (rotor, tank and jeep engines, and their changes with speed and throttle), which need the looping stepper and per-cue envelope of the sound engine (`game/sound_manager.gd` only plays one-shot, flat cues; see the untraced-choices entry and document 82); (b) **there is no music at all**: the mechanism is traced ([document 14](14-worked-example-music-mechanism.md), CD audio with a WAV fallback) but nothing plays it. Both are unstarted.
- **Moddability framework (user direction, 2026-09-24)** — one data-driven vehicle framework, per-map vehicle rosters with override files, split-up art; steps 1-2 (layered packs; sprite ids and loose-frame art) done, steps 3-7 open — plan section 2.7; the editor itself is planned in [`EDITOR_PLAN.md`](../EDITOR_PLAN.md).
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
- **Vehicle damage: partly resolved (document 47).** Hit points/armour traced (Tank 22/0.3, Jeep 1/0, MSV 26/0.5, Heli 15/0.2) and applied to the Tank; the wreck (document 48), hit flash (59), water sinking (62), explosion damage (60), the real collision shape (53) and the death/wreck-spawn branch (87, which found record `+0x234` -- the "dying handler" -- is 0 for every type, so there isn't one) are done; the life system remains. The wreck's own fall physics is an unresolved contradiction, not a trace (document 87's "Step 4"); the `0x2000000` "big" flag it sets (hp below -40, or a hard landing) is written but never found to be read anywhere.
- **Smaller traced-but-unfinished gameplay pieces (document 45):** the building 62 -> 63 stage; auto-steer (both throttle-less turn bits set; the Jeep's own creep-while-turning rule is done, document 62); the `+0xec` tilt smoothing (cosmetic). Ammo (Tank 150, Jeep 16 missiles, MSV rockets 100 and mines 10, rearm tiles) was skipped at first (user, 2026-09-20) and is now applied (document 72). The Tank, Jeep, MSV and Heli movement and weapons are applied (documents 45, 58, 60, 61, 62, 63).
- **Jeep leftovers (2026-09-21):** everything else about the Jeep is done. Still open: the empty-click sound; the missile's third target rule (the last enemy-team object it touched, state `+0xa8`), which needs vehicle-vs-vehicle contact; the wading and sinking draw descriptors (`record+0x14c` / `+0x154`) and the wading splash (the port lowers the vehicle instead); sounds throughout (missile launch `0x44b9ec`, swim mode `0x44b958` / `0x44b940`, mine beep); the missile quad's odd half-width corners (drawn as read, unverified against the original); the third button's own-flag return at the base (`FUN_0040e090`, document 57); the base exit and vehicle stock (`FUN_0040b400`).
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
  three-part scattered bush cluster). **Superseded by document 44:** the per-part quad corners of
  84 ids (chained sub-objects and building ids 49/50 included) are now extracted from the
  descriptors, replacing the hand-made palm-trunk composition below; id 76 is empty and unused.
  That catalogue is now wired all the way through: `tools/convert_rfm.py` records every
  tile's coastal id, `tools/build_pack.py` resolves it to real sprite ids, and
  `game/terrain_tile_renderer.gd` draws each tile's decoration parts (baked, like the terrain
  itself, since decorations never move after level load) — both the flat 2D scene and the 3D
  scene get the same real, individually-readable coastline foliage for free. Follow-up: the
  palm-frond cels had no trunk pixels of their own, so the fronds floated with nothing
  visibly holding them up. (This was later found to be an invented composition: the real trunk
  and ground shadow are a chained sub-object of the same descriptor, document 44.) See [document 35](35-worked-example-coastal-decoration-mechanism.md) and
  [document 36](36-worked-example-decorations-in-3d.md); plan section 4 item 14.
  **Update (2026-09-09, document 41) -- user-flagged: baked decorations can't look like they
  stand up.** Document 36's "baking it alongside the terrain is exactly as correct as a live
  Node3D" reasoning held for flat ground tiles but not for anything with real height -- content
  baked flush with the ground texture's own Y never leaves that Y, so it reads as a mark on the
  dirt no matter how correctly the camera projects it. Direct atlas inspection confirmed the
  canopy cels are drawn from above (meant to lie flat) while the trunk cel is drawn side-on
  (meant to stand) -- two different shapes, not one. New `game/decoration_field_3d.gd` gives
  every decoration real Node3D presence (since rebuilt from the traced quad corners, document 44,
  rather than the hand-made trunk-and-canopy composition first used). `game/terrain_tile_renderer.gd` is tile-grid-only again. Confirmed by
  screenshot: trees now show standing trunks and layered canopies, not flat green ground marks.
  See [document 41](41-worked-example-decorations-as-3d-entities.md).

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
