# 21. Worked example: "the sprite looks very wrong after moving" was two bugs, not one

[Document 20](20-worked-example-palette-offset.md) left off with Phase 4 step 1 rendering a
correctly-coloured level. This document covers what happened turning that into something
playable: Phase 4 step 2 (a player-controlled vehicle) and step 3 (a scrolling camera),
shipped together, both **playable but deliberately not authentic** -- the movement constants
and the flat-rotation rendering technique are flagged placeholders in `PORTING_PLAN.md`, not
things this document claims to have solved. What *is* worth a worked example is two real bugs
the user caught along the way, and how tracing the first one uncovered the second.

## Getting something moving

`game/vehicle.gd` spawns at the level's team-0 point and moves with ordinary accel/brake/
friction/turn-rate constants -- reasonable numbers, not reverse-engineered ones (the `.RFM`
`vehicle_params` fields decode structurally but were never semantically identified, and are
almost always `"default"` anyway). Rendering reuses section 1.10's already-solved finding that
the vehicle is a cannon-armed tracked hovercraft (cels 218-240), but *not* section 1.10's real
mechanism: the original does perspective-projected-quad rendering across 64 discrete headings,
and this instead takes the 8-9 real sprite frames covering one assumed quarter-turn and mirrors
them into the other three quadrants -- section 2.2's own "knowingly accept a simpler visual
target" option. Verified the honest way this project always verifies rendering: not "no
errors," but a debug input-override hook (`RF_DEBUG_DRIVE`) and a screenshot showing real
position and heading change over 90 frames.

## The bug: "the sprite looks very wrong after moving"

That was the user's report after driving the vehicle around for a bit. The four-quadrant
mirror scheme in `_frame_for_heading()` is supposed to pair flips consistently: quadrant 2 is
quadrant 1 flipped left-right, quadrant 4 is quadrant 1 flipped top-bottom, quadrant 3 (both
flips) is quadrant 1 turned around. The actual code flipped the *base* quadrant vertically
when it shouldn't have, and left the 270°-360° quadrant not flipped at all when it needed to
be -- producing a visibly wrong, discontinuous sprite exactly at every quadrant crossing. Fixed
and verified across all 16 test headings via a new `RF_DEBUG_HEADING` hook (pins heading
directly, independent of drive-simulation timing, so specific angles can be screenshotted on
demand): smooth, continuous rotation all the way around.

## Tracing the fix surfaced a second, unrelated bug

Fixing the mirror math meant actually looking closely at what sprite family got picked for
each team, and that's what surfaced something wrong two layers away from rendering entirely:
the registry still said `"cyan"`/`"teal"` for the sprite families section 4 item 5 had already
confirmed, two sessions earlier, were really `"tan"`/`"green"`.

The cause was in `tools/registry/classify_bulk.py`'s auto-numbering, not in anything about
vehicles or rendering. Its ID-numbering helper re-seeded from the *on-disk* registry file on
every run, so each of the script's many re-runs saw its own previous output as "already used"
-- unbounded drift, with one family's sequence numbers climbing to `.81`-`.88` instead of
`.01`-`.08`, and silently undoing the earlier post-hoc "cyan → green" rename every single time
the script ran again. Fixed at the root (seeding now excludes each call's own indices) and at
the source (the id strings themselves say `"green"`, not a patch layered on top of `"cyan"`
after the fact) -- re-running the script is now provably idempotent instead of quietly regressing
one rename at a time.

This also exposed a **latent bug that had never actually triggered**: `vehicle.gd` already
expected a `"green"` sprite family for team 1, which would have found nothing and silently
failed to render, since `RFMAP001` (the level used for every debug screenshot so far) only
has a team-0 spawn. A wrong id string and a level that never asked for the other team had been
quietly cancelling each other out.

**The lesson, in the same spirit as document 6's rules but applied to this project's own
Python tooling instead of decompiled C:** a "fix" to one file's rendering surfaced a bug in a
completely different file (a registry script last touched sessions earlier) only because
fixing the sprite mirroring required actually reading which sprite id got picked, rather than
just eyeballing that a shape looked roughly right. Tracing a symptom all the way to its real
cause, instead of stopping at the first plausible fix, is what caught it.

## Camera: shipped the same day, verified the boring way

Phase 4 step 3's single-viewport half (`TerrainView`'s `Camera2D` following the vehicle with
built-in smoothing and edge-clamped `limit_left/top/right/bottom`) has no comparable bug story
-- it worked as expected. Worth noting for the verification habit anyway: it wasn't accepted on
"no errors" either. A debug hook logged vehicle position against camera position every 30
frames while driving dead straight for thousands of frames; the vehicle travelled to nearly 3x
the map's width while the camera held flat at the clamped edge for hundreds of those frames --
an actual measured clamp, not just an assumption that Godot's built-in `limit_*` properties do
what their names say. Split-screen itself (multiple viewports) is intentionally not started --
it needs a second local player or the 4-player goal to exist first.

## What's still open

- The quarter-turn/mirror assumption itself -- not just the flip-pairing bug, the underlying
  premise that the real game only needs one quarter-turn's worth of art per team -- is still
  **unconfirmed**. An attempt to settle it properly found `FUN_0042dd90` uses a real,
  data-driven "facing table" (linear heading-range-to-cel mapping, plus a mode-based variant
  selector that's a plausible candidate for how team colour gets picked at the table level),
  but a full `.data`-segment scan for the inferred 24-byte record layout found nothing
  conclusive. Accepted as a known gap (user's call) rather than chased further for now --
  revisit once more of the game is running and a wrong frame would actually be visible in
  context.
- Return Fire is popularly known for an attack helicopter; nothing in the (coarsely
  classified) registry has been confirmed as one yet.

**Next:** [Worked example: reusing a solved RE finding as running code](22-worked-example-weapons-and-targets.md)
-- Phase 4 steps 4 and 5, weapons/projectiles and destructible targets.
