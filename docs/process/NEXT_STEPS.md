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

## Still open

See plan section 4 for the current, precise state of each — this list is just pointers:

- **What ends a match — MAJOR NEW LEAD (2026-09-06), not yet closed.** The user described a
  capture-the-flag win condition; a hidden debug string, the confirmed two-team flag art, and
  a direct code link into the already-implemented candidate-pool destruction handler all point
  the same direction, but where the flag gets picked up/carried/returned and where a win
  actually gets declared are still untraced — see [document 24](24-worked-example-capture-the-flag-lead.md)
  and plan section 4 item 1.
- **A life system the user also described — not yet investigated at all.** No "Life"/"Lives"
  text exists anywhere in the binary (a raw byte search came back empty), so this needs a
  non-string anchor — probably tracing what happens when a vehicle's destruction count/health
  reaches zero, from the vehicle side rather than the building side (section 4, item 1).
- Team-colouring *mechanism* (separate cels vs. palette swap) — the colours themselves are settled, see above (section 4, item 5)
- 3DO support: base game + "Maps o' Death" expansion — new goal, **deprioritized** until the core PC-port game runs (section 4, item 6)
- 4-player support — new goal, not yet started (section 4, item 7)
- Custom Godot UI for menus/level-select/etc — new goal, not yet started (section 4, item 8)
- **The turning-sprite mirror rendering — user-flagged (2026-09-06) as needed for parity**,
  not just an accepted gap to revisit later (section 4, item 10; section 3 Phase 4 step 2).
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
section 3. Split-screen itself is not started. Next real blocker: Phase 4 step 7, mission
objectives/scoring/level progression -- blocked in part on section 4 item 1 ("what ends a
match?"), still open but with a real, concrete new lead as of 2026-09-06: a capture-the-
flag mechanic, tied directly to the candidate-pool buildings Phase 4 step 5 already
implements (see document 24). A related, separately-described life system is a distinct,
not-yet-started lead with no string anchor to start from.
