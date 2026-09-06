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
- **The turning-sprite mirror rendering — one real bug fixed (2026-09-06, see above), the
  deeper architecture question still open.** The flat-sprite-quadrant-mirror approach itself
  is still just an approximation of a technique section 1.10 already found isn't how the
  original renders vehicles (real perspective-projected 3D quads). A DOSBox-X reference
  capture was attempted (2026-09-06) but **blocked**: Windows 95 boot hangs at a
  `C:\WINDOWS\SYSTEM\VMM32\IOS.VXD` load failure in the pre-built `hdd.img`, not a
  dismissible warning. Parked, not resolved — see section 4 item 10 for what a real fix
  attempt should start from (section 3 Phase 4 step 2).
- **Perspective terrain/object rendering — DECIDED (2026-09-06), Phase 0 and Phase 1 DONE
  (2026-09-06), Phase 2 (real baked terrain art) not yet started.** The biggest single
  authenticity gap found so far, bigger than the vehicle-rotation question — it's the game's
  whole ground-plane look, not one sprite family. Decision: `Camera3D` + textured
  `MeshInstance3D` ground plane + billboard `Sprite3D`s, reusing all existing gameplay logic
  and per-heading sprite-selection code unchanged — Godot's own camera does the perspective
  math instead of hand-porting the original's fixed-point scanline formula. Phase 0 closed the
  remaining RE unknowns: the camera's tilt is a fixed, algebraically-exact 45°, hardcoded once
  at construction and never rewritten anywhere in the binary, and the terrain blitter has no
  rotation/yaw term at all. Phase 1 (`game/terrain_view_3d.gd`, built alongside the still-fully-
  working flat 2D scene) proves a real `Camera3D` at that fixed tilt, translating in X/Z to
  follow a placeholder tracked object, smoothed and edge-clamped the same way the existing
  `Camera2D` is, verified with real position numbers over a 1500-frame driven test and several
  real screenshots. Tilt and height (zoom) are exposed as live-adjustable properties per user
  direction (2026-09-06); rotation/yaw is not exposed at all — a real bug (`look_at()` quietly
  introducing rotation whenever edge-clamping put the camera off-axis from the tracked object)
  was caught by that same driven test and fixed. See
  [document 28](28-worked-example-3d-camera-scaffold.md),
  [document 27](27-worked-example-terrain-perspective.md), plan section 1.10 point 6, section
  2.2, and section 4 item 13, and the 6-phase implementation plan at
  `C:\Users\Alex\.claude\plans\tingly-booping-wall.md` (outside this repo — section 2.2 has the
  durable summary).
- **Terrain-based vehicle passability — new, user-flagged (2026-09-06) as needed for
  parity.** Not started; likely connects to the still-unchased elevation bits/height_seed
  byte (section 4, items 2 and 11).
- Possible on-foot infantry / rescue mechanic — new, unconfirmed, found while classifying the asset registry (section 4, item 12)

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
