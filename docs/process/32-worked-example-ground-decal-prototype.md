# 32. Worked example: one image, rotated correctly, beats nine images flipped

[Document 31](31-worked-example-vehicle-roster.md) diagnosed exactly why the vehicle "looks
like it's always facing the same way": heading 0 and heading 180 render pixel-identical,
because flipping a left-right-symmetric base frame changes nothing. Following up on the
user's observation that the 90/270-degree frames "should be more than little triangles," this
document tests a specific hypothesis — that the real problem isn't missing art, it's that
Phase 3's billboard rendering never lets the camera's own tilt foreshorten the vehicle the way
it foreshortens everything else in the scene — by building a cheap prototype rather than
arguing about it.

## Ruling out "the art is just corrupted"

Before touching rendering code, the fragments themselves needed a second look. Both team
colours' rotation sets show the *identical* pattern at the *identical* relative position: a
coherent, gradually-turning turret for the first 6-7 frames, then a hook, a thinner squiggle,
and a tiny sliver for the last 2-3. Two independent bulk-classification passes landing on the
same shape by coincidence is implausible; checking the raw CCB metadata (flags, palette,
size) for all nine tan frames found them identical too — structurally one coherent object,
not a mix of unrelated pieces accidentally swept together. The art is real and intentional.
That still left two live possibilities: the sliver frames are a correct (if genuinely small)
edge-on silhouette of a low, flat "hovercraft"-style body, or the *rendering technique* is
what's failing to present them convincingly.

## The prototype

`VehicleBillboard3D` gained a second mode alongside the verified Phase 3 billboard, toggled
by `RF_DEBUG_VEHICLE_QUAD_MODE=ground_decal` (default stays `BILLBOARD`, so nothing about the
committed Phase 3 behaviour changed). Instead of a `Sprite3D` that always faces the camera:

- `billboard = BILLBOARD_DISABLED`, and the sprite's own local rotation tips it flat
  (`rotation_degrees.x = -90`), lying in the ground plane the same way the terrain mesh does.
- The parent node's `rotation_degrees.y` is set to the vehicle's *real, continuous*
  `heading_deg` every frame — an actual 3D yaw, not a 2D screen-space flip.
- Deliberately uses **one single canonical texture** (`vehicle.hovercraft.rotation.tan.01`,
  the fullest real frame), not `_frame_for_heading()`'s discrete quadrant-and-flip selection.
  Combining both would double-count the rotation: the flip logic already re-orients its own
  content for whatever quadrant it's approximating, so adding a full continuous yaw on top of
  that would rotate the same content twice.

No hand-ported projection formula, no per-object 3D corner data (still unknown — section 1.10
never pinned down the vehicle's real box dimensions). Godot's own camera does the actual
foreshortening on a real, tilted, rotating flat plane, exactly the way it already does for
terrain — the same rationale section 2.2 recorded for choosing this rendering architecture in
the first place, just applied to the vehicle instead of the ground.

## The result

A full 10-heading sweep (0-315 degrees) shows a smooth, continuously-changing, always-
coherent silhouette — no degenerate frames anywhere, including exactly the headings
(90/270) where the billboard-plus-flip approach produced disconnected slivers. Direct
side-by-side at heading 90: the old approach shows a small reddish nub in an otherwise-empty
tile; the new approach shows the full, readable turret shape, correctly foreshortened. A
driven test (real turning motion, not fixed test headings) confirms it holds up during actual
gameplay-shaped movement, not just static screenshots.

The notable part: this uses **one** source image where the old approach used nine per team.
Real geometric rotation under a real perspective camera did more for visual quality than nine
hand-picked, mirrored, flipped frames — direct evidence that Phase 3's billboard choice, not
a lack of source art, was the actual limiting factor.

## What this doesn't settle yet

This is a prototype, not a finished replacement:
- Only one canonical texture was tried. The original's own art shows genuine shading/detail
  differences across headings (not just silhouette rotation) — whether cycling through
  several real textures *combined* with continuous rotation looks better than either
  technique alone is untested.
- The exact yaw sign/offset was matched empirically against a visual sweep, not derived from
  a traced heading convention.
- Team-colour switching, projectile/marker parity with this same technique, and the flip
  side (does this now under-use the real per-heading art this project already has, or should
  it) are all open follow-ups, not resolved here.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
