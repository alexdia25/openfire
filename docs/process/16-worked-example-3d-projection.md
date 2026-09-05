# 16. Worked example: there's no sprite pivot, because it's not 2D

This is the biggest architectural finding in the series so far, and it came from a question
that turned out to be built on a wrong premise: "what's the implicit pivot point in each
vehicle sprite?" assumes vehicles are flat 2D art rotated around an anchor. They aren't.
Return Fire's object renderer does real (if simplified) 3D projection, and finding that out
changes a real decision in `docs/PORTING_PLAN.md` section 2.2, not just a data field.

## Starting from a function already on hand

This didn't need a fresh anchor. [Document 15](15-worked-example-resolution-and-tick-rate.md)
and the team-colouring investigation before it had already decompiled `FUN_0042dd90` — a
function that selects a directional sprite frame for an object based on its heading, indexing
the shared `ART.CAR` CCB array. At the time, it was read only far enough to confirm it didn't
touch a team/owner field. Coming back to the same decompile with a different question —
"how does this position the sprite on screen?" — meant no new Ghidra call was needed to get
started, just re-reading two calls in it more carefully:

```c
local_14 = (uint *)FUN_00413c90((uint *)(local_8 * 0x44 + DAT_0044964c));
FUN_00436fb0(local_14, piVar7 + 2, 0x47c510);
```

`FUN_00413c90` was already known (from section 1.7's terrain-blitter work) to be "grab a
fresh CCB instance from the per-frame draw-list ring buffer." `FUN_00436fb0` was new territory.

## Following two calls deeper than expected

`FUN_00436fb0` is a one-line wrapper around `FUN_00419820`. That function was the first real
surprise:

```c
void FUN_00419820(uint *ccb, int *indices, int vertex_table)
{
  *ccb |= 0x1000;
  for (i = 0; i < 4; i++) {
    vertex = vertex_table + indices[i] * 0xc;
    ccb[4 + i*2]     = vertex[0];
    ccb[4 + i*2 + 1] = vertex[1];
  }
}
```

Setting a CCB flag bit and writing all four corner-coordinate pairs directly is not what a
flat rotated sprite needs — a flat sprite needs a position, a rotation, maybe a scale. Four
independently-set corners is the signature of the 3DO CEL engine's **arbitrary parallelogram
mapping** mode, inherited wholesale into this Win95 port (Return Fire shipped on the 3DO
console first). The four corners come from `indices` (small integers, stored right next to
each heading's angle range in the per-object facing table) selecting into a shared vertex
buffer (`0x47c510`) — meaning the vertex buffer is filled once and many objects' facing
records just pick 4 of its entries.

## Finding where that buffer gets filled

`0x47c510` is filled by `FUN_00413d00`, called from the same `FUN_0042dd90`:

```c
scale = perspective_lut[(local_z + camera_z) >> 16];
screen_x = (((local_x + camera_x) >> 0xe) * scale) >> 2 + screen_center_x;
screen_y = (((local_y + camera_y) >> 0xe) * scale) >> 2 + screen_center_y;
```

That's a perspective-divide-via-lookup-table — the standard software-3D-renderer trick of
replacing a division with a table read, keyed by depth. `perspective_lut` (`PTR_DAT_00449400`)
is genuinely a `1/z`-style table: its construction function computes
`focal_length / depth` for each of its ~1536 entries with a real integer division, no
approximation. Tracing every reader of that same table (`FindDataXrefs.java`) turned up a
detail that ties this whole investigation back to earlier work: **the terrain tile blitter
(`FUN_00408d60`, section 1.7) reads the exact same table.** Terrain and objects are not two
separate rendering systems with two different depth models — they share one.

## The rotation side: 64 headings, not "however many sprites exist"

The table-construction function (`FUN_0041ae50`) also builds a rotation-matrix table, looping
a fixed-point angle from 0 through a full circle in exactly 64 steps, calling sin/cos
equivalents and a 3x3-matrix builder for each step. That number — 64 — is a real, load-bearing
constant: it's how many discrete facing directions the whole object-rendering system is built
around, independent of how many rotation-frame sprites `ART.CAR` actually ships per vehicle
(fewer sprites than 64 headings is expected — mirroring and interpolation are the classic ways
to cover the gap, though this investigation didn't chase which one Return Fire uses).

## Why this isn't just trivia

A vehicle in Return Fire is drawn by: picking the nearest of 64 rotation matrices for its
current heading, transforming a handful of local-space 3D corner points through that matrix
plus camera-relative translation, running each through the shared perspective-divide table,
and texture-mapping the resulting screen-space quadrilateral with whichever pre-rendered
directional sprite matches that heading. None of that is "rotate a 2D image around a point."

That matters for the port because [section 2.2](../PORTING_PLAN.md#22-rendering) had
tentatively assumed `Sprite2D` nodes for vehicles — a reasonable assumption for a 2D top-down
game, and wrong for this one if visual fidelity to the original matters. A flat `Sprite2D`
rotated in place will look recognizably different from the original's subtle
depth-skew-as-you-turn look, because the original was never doing a flat rotation to begin
with. This is now a real, informed decision recorded in the plan doc rather than a risk nobody
had noticed yet: reproduce the projected-quad technique (a vertex-mapped `Polygon2D` or
shader-driven mesh per object, fed ported versions of the same per-heading geometry and
perspective table), or knowingly accept a simpler flat-rotation approximation as a scoped-down
visual target. Either is fine — the point is that it's now a choice, not an accident.

## The lesson

The backlog question ("what's the pivot?") had a hidden assumption baked into its own
phrasing, and the RE process didn't need to argue with that phrasing directly — it just
followed the actual code, and the code turned out not to have an answer to the question as
asked, because the premise didn't hold. This is a variant of
[document 13](13-worked-example-reticle-not-swatch.md)'s lesson (an assumption survives right
up until something concrete contradicts it) applied one level up: not "this specific guess
about a specific cel was wrong," but "the mental model the whole backlog item was framed
around doesn't match what the binary actually does." Worth remembering when a question keeps
resisting a clean answer — sometimes that's a sign to check whether the question's own
assumption is the thing that's actually wrong, not the search technique.

**Next:** back to [document 7](07-next-steps.md) for the current backlog.
