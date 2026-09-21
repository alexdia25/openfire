# Next steps

*Deliberately unnumbered, unlike everything else in this folder.* The numbered docs (01-65
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
- **Turret aim and raised fire (2026-09-21):** the Tank's turret turns independently (`Q`/`E`, `R` recentres) and both the Tank and the MSV have a raised gun (`Z`: 25 degrees up, shots 40 degrees up that climb to 55, the Heli's altitude). The Heli can now be shot down. See [document 64](64-worked-example-turret-and-raised-fire.md), which also corrects the MSV rack corners of document 59.
- **The flag object (2026-09-21):** the original's flag drawing (base plate, waving cloth with 13 frames per team, the carried two-quad version), its wave counter, heading easing, attachment offset and water drift are traced and applied; the registry's mislabelled flag cels are fixed; the flag's "flutter child" turned out to be a radar blip. See [document 65](65-worked-example-the-flag-object.md).

## Level 1 (RFMAP001) end to end (2026-09-21)

`tools/tests/playthrough_rfmap001.gd` plays the level through the real game logic with a crude autopilot: **it is completable**. The level is a 766-tile island
with one spawn (tan, tile 67,67), one target building (pool b, tile 75,56; pool a is empty) and no enemy vehicles. The route: a Tank shoots the building
(6 hits, 126 ticks) -> the ruin `62` (6 hits of its own, 120 ticks; the flag appears at once but sits inside the ruin's solid box) -> id `63` (four corner posts, the
flag reachable) -> back to the home tile, `V` for a Jeep (only a Jeep can carry) -> the flag -> home: `match_over(tan)`. Notes from the run: the Jeep cannot crush
bushes or pass rocks, so it must route around them; palms block the Tank too. **Gaps for a player**: nothing tells them what to do (no objective text, no vehicle or fuel
readout, no control hints), `V` at the home tile is a port convenience, the win banner has no restart, and the whole thing has only been run without the scene (the view
applies the tile states); an end-to-end run inside the real scene is still to do.

## Untraced choices (revisit; a standing list, kept short on purpose)

Rule (user, 2026-09-21): never make our own choice silently; if one is unavoidable, mark it in the code and list it here to trace later.

- **The ground flag's camera tilt** (`(cam+0x24 + 0xffe70000) >> 3`) is not reproduced (document 65).
- **Port-only input keys** (Space / Z fire, X weapon switch, Q / E strafe, M mines, B swim, F flag, V and F1-F4 vehicle swap): the original reads input bits; the key layout is not its concern.
- **The mine's drop offset** is reproduced as coded (only the y component), which looks odd; confirmed as the code, not as the intent (document 60).
- **The Jeep missile quad** is drawn from the descriptor's half-width corners as read; the draw function `0x41b750` was not shown to mirror it (document 61).
- **The Heli's start-up and landing** (gear, rotor spin-up, the folded rotor of mode 4, the base glide) are not modelled: it flies at once (document 63). A live Heli casts no shadow (only its dying sequence does, traced 2026-09-21); the dying sequence itself (record `+0x234`, `0x40eae0`: a shadow, the falling body, the stopped rotor) is not modelled.
- **Respawn and enemy AI** are placeholders written before tracing (`MatchController._on_player_destroyed`, `enemy_vehicle.gd`).
- **Water landing of shots** uses "any water" for shallow as well; the exact sampling of `FUN_0042f5b0` was read but its box argument is a compiler-garbled stack layout (document 61).

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
- **Vehicle damage: partly resolved (document 47).** Hit points/armour traced (Tank 22/0.3, Jeep 1/0, MSV 26/0.5, Heli 15/0.2) and applied to the Tank; the wreck (document 48), hit flash (59), water sinking (62), explosion damage (60) and the real collision shape (53) are done; the dying handler at record `+0x234` and the life system remain.
- **Smaller traced-but-unfinished gameplay pieces (document 45):** the building 62 -> 63 stage; auto-steer (both throttle-less turn bits set; the Jeep's own creep-while-turning rule is done, document 62); the `+0xec` tilt smoothing (cosmetic). Ammo (Tank 150, Jeep 16 missiles, MSV rockets 100 and mines 10, rearm tiles) is deliberately skipped (user, 2026-09-20). The Tank, Jeep, MSV and Heli movement and weapons are applied (documents 45, 58, 60, 61, 62, 63).
- **Jeep leftovers (2026-09-21):** everything else about the Jeep is done. Still open: ammo (16) and the empty-click sound; the missile's third target rule (the last enemy-team object it touched, state `+0xa8`), which needs vehicle-vs-vehicle contact; the wading and sinking draw descriptors (`record+0x14c` / `+0x154`) and the wading splash (the port lowers the vehicle instead); sounds throughout (missile launch `0x44b9ec`, swim mode `0x44b958` / `0x44b940`, mine beep); the missile quad's odd half-width corners (drawn as read, unverified against the original); the third button's own-flag return at the base (`FUN_0040e090`, document 57); the base exit and vehicle stock (`FUN_0040b400`).
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
