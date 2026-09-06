# 28. Worked example: the fix that made the camera work was lighting, not rotation

[Document 27](27-worked-example-terrain-perspective.md) found that RFIRE.BIN's terrain
renderer is a genuine tilted-perspective camera, not a flat top-down map, and the plan
decided (`PORTING_PLAN.md` section 2.2) to reproduce that with a real Godot `Camera3D` rather
than hand-porting the original's fixed-point scanline math. This document covers Phase 0
(closing the remaining RE unknowns) and Phase 1 (the first working 3D scaffold) of that
6-phase plan — and a debugging story where the obvious hypothesis for a broken screenshot was
wrong twice in a row, in two different directions, before the real fix.

## Phase 0: the tilt turns out to be exactly 45 degrees, not a guess

Section 1.10 already knew *which* function built the camera-setup constants
(`FUN_0041ae50`) and *which* table it fed (the depth-reciprocal table read by both the
terrain blitter and the per-object projector). What hadn't been chased down was whether the
tilt angle itself was a fixed constant or something that could change at runtime — the user's
own phrasing, "the camera can move," left that genuinely open.

Rereading `FUN_0041ae50`'s caller and the shared object constructor everything in this
rendering system funnels through (`FUN_00416cb0`) closed it: that constructor hardcodes
`param_1[9] = 0x200000` as a literal, and the sin/cos helpers it calls
(`FUN_00410be0`/`FUN_00410dc0`) decode their scale constants to exactly `2π / 0x1000000` —
so `0x200000` is exactly 45.0 degrees, not an estimate. The object it's building (confirmed
via `FindCallers.java` on the terrain blitter itself, which resolves back to this same
constructor's output) is constructed exactly once, at game init, and nothing else in the
binary writes to that field afterward. Combined with the already-established "no write site
to the focal-length constant either," this closes Phase 0's central question: the original's
tilt is fixed, full stop — the panning the user saw is camera *translation*, not a changing
pitch. A small arithmetic slip from an earlier session (misreading the focal-length constant
as "76800") got corrected along the way too, to exactly 300.0 in 16.16 fixed point.

## Phase 1: two wrong guesses before the real bug

With Phase 0's numbers in hand, Phase 1 built `game/terrain_view_3d.gd` — a `Camera3D` at a
45-degree tilt, translating in X/Z to follow a placeholder tracked box, smoothed and
edge-clamped the same way `terrain_view.gd`'s `Camera2D` already is. First headless run:
a completely black screenshot.

The instinctive read was "the rotation sign is backwards" — `rotation_degrees.x = -45`
looked like a plausible guess but nothing had confirmed which direction Godot's X-axis
rotation tilts a camera. Rather than guess again, the fix reached for `camera.look_at()`
instead, aimed at the tracked object's ground position — sidestepping the sign question
entirely, since `look_at()` derives orientation from two points instead of a hand-picked
angle.

That produced a real, correctly tilted, receding view — but the black screenshot's actual
cause turned out to be neither rotation guess: there was no `DirectionalLight3D` in the scene
at all, and an unlit `StandardMaterial3D` surface renders pure black regardless of what the
camera is pointed at. Adding one light fixed the black screenshot completely independent of
the orientation question.

## The bug `look_at()` quietly introduced

Verifying the edge-clamp (drive straight at the map boundary for 1500 frames, matching
[document 21](21-worked-example-vehicle-mirroring-bug.md)'s style of screenshotting a
deliberately extreme case) caught a second, more interesting problem: once the camera's
position clamped at the map edge, the tracked box kept moving — and stayed dead-centre on
screen anyway. The camera was quietly panning to keep looking at it. `look_at()` was doing
exactly what it's supposed to do (aim at a point), but "aim at a point that has drifted
off-axis from the camera" *is* a rotation — precisely the kind of camera motion the user had
just said the original doesn't do ("the camera should be able to tilt and zoom, but not
rotate, I believe").

The actual fix was to go back to the first instinct — a fixed `rotation_degrees.x =
-camera_tilt_deg`, set once and never re-aimed at anything — and this time verify the sign
empirically instead of guessing: with the light bug already fixed, `-45` turned out to be
exactly correct all along. The black screenshot and the wrong-rotation hypothesis were two
unrelated things that happened to arrive in the same test.

## What Phase 1 proves, with real numbers

- A static screenshot at the default 45-degree tilt, height 260px: a correctly tilted,
  receding ground plane with the tracked box centred.
- A driven test (1500 frames, straight line, `RF_DEBUG_CAMERA_LOG=1`): camera X converges to
  exactly `3835.997` against a clamp computed as `map_width(4096) - pull_back(260)`, matching
  `terrain_view.gd`'s existing `Camera2D` clamp convention, while the tracked box visibly
  drifts off-centre once clamped — proof the camera translates only, never rotates to
  compensate.
- `RF_DEBUG_CAMERA_TILT_DEG=25 RF_DEBUG_CAMERA_HEIGHT_PX=500`: a visibly shallower, more
  zoomed-out view with a real horizon line now in frame — confirming tilt and height (zoom)
  are genuinely live-adjustable, per the user's direction that those two (not rotation)
  should be degrees of freedom in the Godot implementation even though RFIRE.BIN itself never
  varies either one.

## What's still a placeholder, on purpose

The ground is a flat colour, not baked terrain art (Phase 2). The tracked object is a plain
box, not a billboard sprite (Phase 3). The exact effective height/FOV that would
pixel-match the original is still not derived — Phase 0 deliberately left that for
screenshot-matching once Phase 2 has real terrain art to match against, rather than tracing
several more layers of fixed-point constants for a number this project's own standards would
rather verify visually anyway.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
