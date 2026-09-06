# 27. Worked example: a screenshot catches a gap between a finding and what got built

[Document 16](16-worked-example-3d-projection.md) already found, months ago, that vehicles are
rendered through a real 3D perspective camera, not flat rotated sprites — and, in passing,
that the same perspective table is read by the terrain blitter too. That fact sat in the plan,
correctly recorded, for two sessions without anyone asking the obvious follow-up question:
*if terrain reads the same table, does that mean the terrain camera is tilted too?* Phase 4
step 1 shipped a flat, straight-down `TileMapLayer` render regardless, and nothing caught the
mismatch — until the user pointed at real footage and said the camera looks tilted, not
top-down, and moves.

## The lead was already sitting in the plan

This is a different kind of investigation from most of this project's worked examples: there
was no new anchor to find. `docs/PORTING_PLAN.md` section 1.10 point 2 already named the exact
function (`FUN_00408d60`, "the terrain tile blitter") and the exact table
(`PTR_DAT_00449400`). The entire first move was rereading a decompile this project effectively
already had the address for, and actually working through what it does line by line instead of
trusting the one-sentence summary ("terrain and objects share one perspective system") that had
satisfied the earlier investigation. That summary was true and also hid the part that mattered.

## Reading a scanline loop as a scanline loop

`FUN_00408d60` isn't a nested "for each screen row, for each screen column, blit the tile at a
fixed world-space step" loop — one of this project's earlier assumptions, and a reasonable one
for a 1996 tile-based game. It's a loop over screen rows (`local_18`) where **each row looks up
its own horizontal step size and starting offset** from `PTR_DAT_00449400`, indexed by a
depth-like term computed from the row number. That's not an implementation detail; a constant
per-row step is what a flat top-down map produces, and a per-row-varying step (shrinking as
"depth" increases) is what a tilted ground plane produces when projected onto a fixed screen —
the exact technique behind Mode 7-style SNES racers and PC-era raycasters: precompute
`scale(depth) = focal_length / depth` once, then drive every screen row's geometry from that
row's `scale`.

One clue needed chasing past the decompiler's limits: part of the per-row calculation
(`FUN_00410c10`) decompiles as a *parameterless* function that still returns a value derived
from `__ftol` (the MSVC runtime's float-to-int helper). That's not actually parameterless —
it means the real input is a float pushed onto the x87 FPU stack by the caller, a calling
convention Ghidra's decompiler can represent in disassembly but not lift cleanly into
pseudo-C parameters. Recognizing *that* the value is hidden, rather than assuming the function
just conjures a number from nowhere, was the difference between "there's some processing here"
and "there's a genuine floating-point depth calculation here."

## Confirming it's one system, not a coincidence

`FUN_0041ae50` — the same startup function document 16 already named as building the vehicle
heading cosine/sine tables — builds the depth-reciprocal table used by the terrain blitter in
the *same function, right before* the trig tables. One initialization routine, one shared
camera setup. And a second function, `FUN_00413d00` (not previously named in this project),
turned out to be a generic N-point 3D-to-screen projector using the identical table and
formula document 16 already found driving per-object quad corners — the general-purpose
version of the same math the terrain blitter inlines for its own scanline loop. Three
independent code paths, one shared perspective system: not a coincidence of table reuse, a
single unified renderer for the whole scene.

## What this changes, and what it doesn't

This doesn't invalidate anything already built — `terrain_view.gd`'s flat `TileMapLayer`-style
render still works, still shows the right tiles in the right places, still passed every
verification this project has run against it. What it changes is the *honesty* of that
implementation's status. Section 2.2 already flagged the vehicle-rotation question as a real,
informed architecture choice before Phase 4 step 2 was built (document 16's own doing) — the
terrain bullet right next to it never got the same treatment, because the finding that should
have triggered it was recorded a section away and nobody connected the two before now. That's
now fixed in the plan (section 1.10 point 5, section 2.2's terrain bullet, section 4 item 13):
this is a real, scoped architecture decision — replicate the tilted perspective floor, or keep
the flat approximation on purpose — not a bug and not a settled plan either.

## What's still open

Whether the camera's tilt or height ever changes at runtime (matching "the camera can move"
beyond ordinary panning) or is a fixed constant is unconfirmed — `DAT_00443000`, the
focal-length seed for the whole perspective table (raw value 76800), has no write site checked
yet. That matters for scoping a real fix: a fixed tilt is a much smaller job than a genuinely
dynamic camera. No implementation was attempted this session either way — this document records
a decision surfaced, not a decision made or acted on.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
