# 23. Worked example: an opponent with no reverse-engineering behind it at all

Every worked example so far, even the software-engineering ones like [document 22](22-worked-example-weapons-and-targets.md)'s
destructible-target step, has had *something* from `RFIRE.BIN` underneath it -- a traced
mechanism, a decoded field, a confirmed cel. Phase 4 step 6 (enemy AI) doesn't. Phase 3's
"AI state machines and target selection" backlog item is completely untouched -- nobody has
even picked an anchor yet. This document is worth having precisely because it's the cleanest
example yet of the other kind of step this project does: ship something playable and *say
plainly* that none of it comes from the original game.

## Why a code seam, not a copy-paste

The obvious way to add an enemy vehicle is to copy `vehicle.gd`, rip out the player-input
code, and paste in some AI logic instead. That duplicates the movement integration, the
rotation-frame rendering, and the firing/cooldown code across two files that then have to be
kept in sync by hand. Instead, `vehicle.gd`'s single `_process()` was split into the parts
that never change (integrate turn/thrust into heading and speed, move, handle the fire
cooldown) and exactly two decision points that do: "what turn/thrust do I want this frame"
and "do I want to fire this frame." Those became `_get_controls()` and `_wants_to_fire()`,
virtual by GDScript convention (no `virtual` keyword exists; a subclass overriding a same-
named method is simply how GDScript does this). The base class's versions are *unchanged
behaviour* -- still real input or the existing `RF_DEBUG_DRIVE`/`RF_DEBUG_FIRE` hooks -- so
nothing about player movement changed at all in this step.

`game/enemy_vehicle.gd`'s `EnemyVehicle extends Vehicle` overrides just those two methods.
Everything else -- the quarter-turn mirror rendering from [document 21](21-worked-example-vehicle-mirroring-bug.md),
the fire cooldown, the `fired` signal `terrain_view.gd` already listens to for spawning
projectiles -- is inherited unchanged. An enemy vehicle is a real `Vehicle` with a different
brain, not a parallel implementation that happens to look similar.

## The behaviour itself, stated as plainly as the code

- Beyond `DETECT_RANGE_PX` of its target: do nothing. Zero turn, zero thrust.
- Within range: turn toward the target proportionally to how far off-heading it is (a small
  proportional controller, not a real steering algorithm), and close in unless already
  close and roughly aimed.
- Fire once aimed within `AIM_TOLERANCE_DEG` and inside `FIRE_RANGE_PX`, subject to the same
  cooldown every vehicle already has.

No pathfinding (it drives straight at the target regardless of what's in the way), no cover,
no squad coordination, no difficulty levels, no state machine beyond "is the target in range
and am I aimed." This is deliberately the smallest thing that can be called "an opponent."

## Spawning from real data, for free

`terrain_view.gd` already loaded `level.spawn_points` for the player and the debug team-
colour markers back in Phase 4 step 1. Enemy spawning reuses that exact same data: spawn an
`EnemyVehicle` at every spawn point whose team differs from the player's, targeting the
player directly. Nothing new had to be added to the converter or the pack format for this --
the "0x4D" spawn tile [section 1.5](../PORTING_PLAN.md) already confirmed only appears in
`2PLAYER\` files, so 1-player levels correctly spawn zero
enemies (there's no second spawn point in the file to spawn one from), and 2-player levels
get exactly one opponent. The AI behaviour is invented; *where it starts* is real level data,
and that distinction is worth keeping straight.

## Verifying a rate-dependent behaviour without a stable frame rate

Section 22 already covered why `TargetPool` needed a unit test instead of a screenshot: the
correct behaviour was already known, so the question was whether the code matched it. This
is a related but different problem: `EnemyVehicle`'s behaviour is a *dynamical system* --
"does it converge to facing the target over time" -- not a one-shot state check. That rules
out `await get_tree().process_frame` as a testing tool: Godot's `--headless` mode has no
display to sync to, so it runs frames as fast as the CPU allows, meaning the real elapsed
`delta` per frame can be tiny and unpredictable. A test that awaits 120 such frames might
simulate 2 seconds of game time or 20 milliseconds of it, depending on how fast the headless
process happens to run that day -- not a reliable way to test "does this converge in about
2 seconds."

The fix was to stop trying to make headless mode behave like a real clock and instead drive
the exact same code path directly: call `enemy._process(1.0 / 60.0)` in a loop, supplying a
fixed timestep by hand instead of waiting on the engine's own frame timing. That's not a
mock or a simplification -- it's the identical method Godot calls every frame, just invoked
with a delta the test controls. Against a real level's real spawn data (`RFMAP110`), 120
calls (2 simulated seconds) took the enemy from a deliberately-wrong 90-degree starting
heading to within tolerance of a repositioned target and fired 6 times once aimed, matching
the 0.25-second cooldown almost exactly (2 seconds / 0.25 ≈ 8, minus the roughly half-second
spent turning before it could fire at all). A second check confirmed the opposite case: push
the same target just past `DETECT_RANGE_PX` and the very next `_get_controls()` call returns
exactly zero, not a decaying residual turn.

One test bug worth recording plainly, in the spirit of [document 6](06-verification-philosophy.md)'s
rules but pointed at test code instead of decompiled C: the first version of this test
connected to the `fired` signal with `enemy.fired.connect(func(_a, _b, _c): fired_count +=
1)`, capturing a local `int`. It ran, produced no errors, and reported zero fires the entire
run -- even though a separate debug print showed firing clearly happening on schedule. GDScript
lambdas capture outer local variables *by value* at the point the lambda is created, not by
reference; incrementing the captured copy inside the closure never touches the outer
variable. The fix was the same trick this bug always needs: box the counter in a one-element
`Array` (a reference type) instead of a bare `int`. A test that runs clean and reports a
plausible-looking wrong number is exactly [document 6](06-verification-philosophy.md)'s
oldest warning, showing up in test-harness GDScript instead of a converter or decompiled C.

## What's still open

- **Every constant is invented.** `DETECT_RANGE_PX`, `FIRE_RANGE_PX`, `AIM_TOLERANCE_DEG` --
  none of these come from `RFIRE.BIN`. Phase 3's AI backlog item hasn't been started; there
  is no anchor yet, not even a wrong guess to correct.
- **No vehicle-vs-vehicle damage.** An enemy's projectile can destroy a destructible target's
  active position exactly like the player's can (step 5's hit-test doesn't care who fired
  the shot), but nothing yet lets a projectile hit a *vehicle*. "Opposes the player" is
  currently limited to "drives at you and shoots in your direction," not "can hurt you."
- **No pathfinding.** The enemy drives in a straight line toward its target regardless of
  terrain, and Return Fire's levels have plenty of obstacles this ignores entirely.

**Next:** [Worked example: a debug string, a dedicated object, and a capture-the-flag lead](24-worked-example-capture-the-flag-lead.md)
-- section 4 item 1 ("what ends a match?"), picked back up from user-supplied domain
knowledge rather than left as the open question this document leaves it.
