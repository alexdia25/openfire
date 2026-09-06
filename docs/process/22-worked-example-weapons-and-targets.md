# 22. Worked example: reusing a solved RE finding as running code

Phase 4 steps 4 (weapons and projectiles) and 5 (destructible targets and buildings) are
different in kind from each other, and the difference is worth a worked example. Step 4 is a
fresh placeholder, flagged honestly the same way vehicle movement is. Step 5 is not a
placeholder at all in its logic -- it's [section 1.5](../PORTING_PLAN.md)'s candidate-pool
mechanism, fully traced from `RFIRE.BIN` two sessions earlier, turned directly into running
Godot code. The interesting part of step 5 isn't a Ghidra trace (that work was already done);
it's how you verify a reimplementation of a *known* algorithm is actually correct, which turns
out to look a lot like document 6's rules but pointed at your own code instead of the
decompiler's output.

## Step 4: fire input, honestly flagged as a placeholder

`game/vehicle.gd` gained a `fired` signal: holding `ui_accept` (or `RF_DEBUG_FIRE=1` for
headless testing, off by default) fires from a fixed muzzle offset ahead of the nose, gated by
a cooldown timer. `game/terrain_view.gd` spawns `game/projectile.gd`'s `Projectile` as the
vehicle's *sibling*, not its child -- so the projectile's transform doesn't inherit the
vehicle's own position/rotation the instant it's fired. `Projectile` itself is a straight-line
mover that self-frees after a fixed lifetime.

Every number here is a guess, and the code says so: `FIRE_COOLDOWN_SEC`, `MUZZLE_OFFSET_PX`,
`Projectile.SPEED`, `Projectile.LIFETIME_SEC` are placeholders, because weapon damage, rate of
fire, ammo capacity and projectile speed are still Phase 3's untouched backlog item -- nobody
has anchored on `DirectDrawCreate` or the input-mapping imports yet, so there's no decompiled
firing code to check these against. The rendering is a placeholder too, for a more specific
reason: the asset registry has mounted, static `prop.missile_pod.*`/`prop.missile_rack.*`
decoration cels, but nothing confirmed as an in-flight shot. Rather than guess a sprite id
that's never been verified, `Projectile._draw()` reuses the same flat-colour-marker convention
`terrain_view.gd` already uses for spawn points.

Verified two ways: `RF_DEBUG_DRIVE=1 RF_DEBUG_FIRE=1` plus a screenshot showed multiple
projectiles visibly in flight along the vehicle's curved path, and a debug print (the same
pattern as the camera's `RF_DEBUG_CAMERA_LOG`) logged real fire events -- heading and muzzle
position at each shot -- confirming the cooldown gates firing by elapsed time, not by rendered
frame (naive per-frame gating would have fired 60 times a second the instant the key was held).

## Step 5: this one already has a known-correct answer to check against

Section 1.5 had already answered, in full, how Return Fire's destructible target/base
placement works: a level file defines a *pool* of candidate positions (the `0xB4`/`0xDC` tile
values), the engine commits to exactly one active target per pool at random when the level
loads, gives that pool a replacement budget of half its candidate count (`count >> 1`), and
when the active target is destroyed, decrements the budget and activates a new random intact
candidate if any budget and candidates remain -- otherwise the pool goes silent for the rest of
the match. That's not a hypothesis to test against decompiled code here; it's a spec to
implement against.

`game/target_pool.gd`'s `TargetPool` is a direct translation of that spec: one instance per
pool id, built from `level.candidate_pools`, with `destroy_active()` doing exactly the
decrement-then-maybe-reactivate logic above. `terrain_view.gd` builds one per pool at level
load and wires it to step 4's projectiles -- anything within a placeholder hit radius of a
pool's active target destroys it. The debug markers changed to match: the pool's one live
target draws as a bright filled square, remaining intact candidates as a hollow outline (as
before), and spent candidates as a dim X -- a real gameplay-state read now, not a static rect
that never changes.

### Verifying a reimplementation of a known algorithm is a different problem than verifying a guess

Everywhere else in this project, verification means checking a *hypothesis* against real data
(document 6's rules) because the real answer was still unknown going in. Here the real answer
was already known -- the risk isn't "is the mechanism wrong," it's "did the GDScript actually
implement the mechanism correctly." That called for the software-engineering equivalent: a
unit test.

A standalone script (`SceneTree`-based, run via `godot --headless --script`, no game scene
needed) built `TargetPool` instances for every candidate count from 0 to 19 and ran 2000 random
trials at each, repeatedly calling `destroy_active()` until the pool went silent, checking on
every step that: the budget decrements by exactly 1 per destruction, no more; a reactivation
never lands on a non-intact or just-destroyed candidate; the pool never goes silent while
budget and an intact candidate both remain (that would mean giving up too early); and the whole
pool never takes more than `budget + 1` destructions to go silent (more would mean a phantom
extra life somewhere). Zero failures across all 40,000 trials.

That confirms `TargetPool` in isolation, but not that `terrain_view.gd` actually calls it
correctly from a real, running scene. A second script loaded the real `terrain_view.tscn`
scene against a real level (`RFMAP110`, 11 candidates in each pool -- most of the levels this
project has tested against so far have only 0 or 1 candidate in pool A, which never exercises
the replacement path at all), read the real active target's real pixel position, spawned a
`Projectile` directly on top of it, let two real `_process()` frames run, and confirmed the
pool's own state changed exactly as expected: budget 5 → 4, and a different real candidate
from the same level file now active. Not a mock, not a synthetic pool -- the actual scene tree,
the actual level data, the actual hit-detection code path.

**The lesson:** document 19 already established that not every question this project answers
is a Ghidra question. This is a companion lesson -- not every *verification* is a "render it
and look" or "check it against every real file" either. Once the underlying mechanism is
already known, the thing worth checking is whether the new code faithfully reproduces it, and
a targeted unit test plus one real-scene integration test does that far more thoroughly than a
screenshot could (a screenshot can show one random outcome; it can't show that the bookkeeping
holds across candidate counts of 0, 1, and 19, or across thousands of random seeds).

## What's still open

- **Hit detection and hitpoints are placeholders.** `TARGET_HIT_RADIUS_PX` is a guess, and
  targets die in exactly one hit. RFIRE.BIN's real building/target hitpoints and destruction
  rules are still Phase 3's untouched backlog.
- **Real target/building art is still unplaced.** Phase 4 step 1 already flagged this gap
  ("building-candidate resolution happens at match-start... so there's no fixed art to place
  from the file alone yet") -- now that match-start resolution is real, the art question is
  still open. The asset registry has plausible, unconfirmed leads worth tracing next:
  `structure.bunker.tan.*`/`structure.bunker.teal.*`, and a 20-frame
  `structure.building_wall_damaged.*` sequence that's a strong hint the "intact" bit-field
  state section 1.5 already decoded (`tile & 0x3f80 == 0xb00`) is one of several progressive-
  damage frames rather than a binary intact/gone flag. Which cel(s) the renderer actually
  picks for these tiles hasn't been traced.
- **No win/lose condition.** Section 4 item 1 is still open -- nothing declares a
  match-won/lost state when a pool's budget is fully spent. This step makes the pools
  themselves behave correctly; it doesn't answer what, if anything, happens when both go
  silent.

**Next:** [Worked example: an opponent with no reverse-engineering behind it at all](23-worked-example-enemy-ai-first-pass.md)
-- Phase 4 step 6, enemy AI.
