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

## The follow-up: combining real per-heading art with real rotation — tested, and it's worse

The obvious next question: the original's own art has genuine shading/detail differences
across the 9 real frames, not just a rotating silhouette — does cycling through all of them
*while also* applying the same continuous 3D yaw capture that extra detail without giving up
the smooth coherence the single-texture version won?

Tested directly: `RF_DEBUG_VEHICLE_QUAD_MODE=ground_decal_multi` keeps
`Vehicle._frame_for_heading()`'s quadrant-folded texture selection (which of the 9 real
frames is closest to this heading) but discards its flip flags, since the real continuous
yaw already supplies the facing direction — using both would double-count. The result is
worse than either technique on its own, and worse specifically at the headings this whole
investigation started from. The discrete texture selection already bakes in a thinning
silhouette as heading approaches 90 (frames `.07`-`.09` are deliberately near-degenerate
slivers, per document 25/31's own findings) — adding real geometric foreshortening *on top*
of an already-thin sliver compounds the effect instead of complementing it, collapsing the
shape to almost nothing at exactly 90 and 270 degrees. A direct crop comparison at heading 90
shows it plainly: the single-texture version's full, readable turret shape next to the
multi-texture version's near-invisible fragment — worse than the original billboard problem
this was meant to fix.

**Conclusion:** for this specific vehicle's art, one canonical (non-degenerate) texture,
rotated purely by real 3D geometry, is the better technique of the three tried. The 9 real
per-heading frames' extra shading detail isn't free to add on top of real rotation — the two
mechanisms fight each other at exactly the angles where the source art itself changes the
most.

## What this doesn't settle yet

This is still a prototype, not a finished replacement:
- The exact yaw sign/offset was matched empirically against a visual sweep, not derived from
  a traced heading convention.
- A middle ground — cycling only among the *non-degenerate* real frames (roughly `.01`-`.06`,
  skipping the already-thinning `.07`-`.09`) alongside real rotation — was not tried; whether
  it captures useful extra shading without the compounding-thinning failure mode is untested.
- Team-colour switching, projectile/marker parity with this same technique, and the flip
  side (does this now under-use the real per-heading art this project already has, or should
  it) are all open follow-ups, not resolved here.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
