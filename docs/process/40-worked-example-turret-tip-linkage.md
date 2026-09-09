# 40. Worked example: the muzzle ring's corners are never static in the first place

**Resolved the same session, after the user pushed to keep going: "So we do need to find how
to display this ring properly."** The "still open" section below was the state after the first
pass -- the mechanism was found but not yet turned into a rendering fix. It was: recomputing
the 7 affected corners as `base + offset` (the identity/no-turret-aim case; `offset` was the
missing piece -- `FUN_00409b10`'s third argument is never advanced, so it's one constant
translation added to all 7 base corners, not 7 different offsets as first assumed) produces a
small, correctly-tapered ring that sits right at the barrel's actual tip. Rendered and compared
by screenshot at all 8 discrete headings against the previous (oversized/misplaced) version --
consistently better at every angle, not just the one first checked. See "What's confirmed vs.
still open" at the bottom for what's now closed vs. what's still a documented simplification.

The user's question that started this document, picking back up after "we stop for today":
*"is there a runtime model change when the weapon is fired -- should the yellow ring always be
visible?"* Two separate questions were buried in that, and both got real answers by finally
reading the six lines of `FUN_00402dc0` that document 39 had glossed over as "an unrelated
small 7-corner 'linkage' computation, not traced further."

## Is the ring a fire-effect asset? No -- it's a plain painted part

Cropped cel 212 (and its pair, 213) directly out of the atlas rather than reasoning about it
secondhand:

```
....########....
...##########...
..############..
.##############.
################
################          <- solid yellow bezel ring, dark bore hole in the
################             centre, symmetric, fills its whole 16x16 cel
################             with only corner transparency (a plain circle,
################             not a starburst/flash shape)
################
################
.##############.
..############..
...##########...
....########....
```

This is an ordinary static ring/cap graphic, not a muzzle-flash sprite -- no evidence of a
separate "resting" vs. "firing" texture, no burst/glow content. There's also no code-level
gate found anywhere that swaps this cel or hides this specific part on a fire event; the
descriptor-swap in `FUN_00402dc0` is gated on whether a linked turret sub-object exists at
all (`[sub_obj+0x14]==1`), which governs the *whole turret*, not this one part. So: yes, the
ring should always be visible whenever the turret is -- that part of the premise holds.

## But the question about "changes to the model" pointed at something real

Rereading `FUN_00402dc0` line by line instead of skipping the middle section:

```c
void FUN_00402dc0(int param_1, int param_2) {
    FUN_0041b430(param_1, param_2);              // draw the hull
    if (**(int **)(*(int *)(param_1 + 0x2c) + 0x14) == 1) {
        iVar1 = *(int *)(*(int *)(param_1 + 0x2c) + 0x60);
        *(uint *)(param_1 + 0x1c) = *(int *)(iVar1 + 0x58) + *(int *)(param_1 + 0x1c) & 0x3fffff;
        iVar1 = *(int *)(iVar1 + 0x50);           // a SECOND, separate value -- not the heading
    } else {
        iVar1 = 0;
    }
    if (iVar1 == 0) {
        FUN_00409b10(&DAT_0043e5ec, &DAT_0043e640, (int *)&DAT_0043e40c, 7);
    } else {
        FUN_0041ae10((undefined4 *)&DAT_00488850, iVar1 << 2);
        FUN_00410c60(&DAT_0043e5ec, &DAT_0043e640, (int *)&DAT_00488850, 7);
        FUN_00409b10(&DAT_0043e5ec, &DAT_0043e5ec, (int *)&DAT_0043e40c, 7);
    }
    *(undefined ***)(param_1 + 0xc) = &PTR_FUN_0043e9b8;   // swap to the turret descriptor
    FUN_0041b430(param_1, param_2);              // draw it
}
```

`FUN_00409b10` is a 7-entry vector add loop -- but its *third* argument pointer is never
advanced inside the loop (only the first two are). So it's `dst[i] = base[i] + offset`, one
constant `offset` vec3 added to each of 7 different `base` corners, not three independent
7-entry arrays summed index-for-index (an easy misread of the decompile's `param_1[1] =
param_2[1] + param_3[1]`-style lines, which look positionally symmetric but aren't once you
check which pointer the loop actually increments). Getting this detail right is what turned
the fix from "doesn't reproduce anything sensible" into "matches the reference art." That
constant `offset`, read once from `DAT_0043e40c`, is `(0, -5.25, 7.0)` in the same raw
16.16-fixed local units as every other corner in this file. `FUN_00410c60` is the same "apply a
3x3 matrix to N corners" routine already confirmed in
document 39. `FUN_0041ae10` builds a single-plane rotation matrix from one angle (confirmed:
`param_1[0] = 1.0`, the rest built from `cos`/`sin` of the angle -- the same "pure rotation,
no embedded scale" shape already found for the whole-turret case).

**`DAT_0043e5ec` is 7 corner-slots (indices 15-21) inside the turret's own 22-corner array
(`corner_ptr = 0x0043e538`)** -- and those 7 indices are *exactly* the far barrel-tip corners
(15, 16, 17 -- the shared tip ridge used by both barrel panels) plus **all four muzzle-ring
corners (18, 19, 20, 21)**. This is not a generic utility touching the whole array; it is a
dedicated block of code that recomputes precisely the corner cluster this project has spent
two sessions unable to explain, and it runs **unconditionally, every single call** (both
branches write into it -- there's no third branch that leaves it alone).

## What this means for the data this project has been using

Every other corner in the turret's array (indices 0-14 -- the top panel, all four sloped
sides, and the barrel's *near* edge) is read once from static data and never touched again.
Indices 15-21 are different: they're a **write target**, refreshed from two other static
blocks --

- `DAT_0043e640`: a 7-corner "base" shape, dumped and confirmed real (not zero/garbage) -- a
  small local polygon (radius roughly 1.1 to 2.2 raw units from its own origin, not a perfect
  circle) representing the barrel-tip-plus-ring cross-section *before* it's placed.
- `DAT_0043e40c`: the one constant `offset` vec3 the loop actually reads (see above). Its
  address does sit one vec3 before the hull's own corner array (`corner_ptr = 0x0043e418`,
  document 37/38's own hull data) -- a real fact about the static layout -- but since the loop
  never advances this pointer, that adjacency is exactly the kind of "adjacent-looks-related"
  coincidence this project has been burned by twice before (document 38/39's own hull/turret
  parts-array mixup) and turned out to be irrelevant here: only the one vec3 at the base address
  is ever read.

**The corner values this project extracted for indices 15-21 (used for the far barrel edges
*and* the entire muzzle ring) were whatever the compiler happened to initialize that scratch
region to -- not a value a running game ever actually displays**, since `FUN_00402dc0`
overwrites them before the very first frame that ever draws this vehicle, unconditionally,
every time. Indices 0-14 don't have this problem, which is exactly why the turret box and the
barrel's near half already matched the reference screenshots and only the tip cluster (parts
5-7's far corners, and specifically the ring) never did.

**Recomputing dest = base + offset (the `iVar1 == 0`, no-turret-aim branch) and rendering it
fixes the bug.** The resulting ring shrinks to roughly a third of its previous footprint and
recentres on the barrel's actual (tapered, not flush) tip cross-section -- confirmed by
screenshot at all 8 discrete headings, not just the one angle first checked, each one compared
directly against the previous (oversized) rendering. See `game/vehicle_box_3d.gd`'s
`TURRET_PARTS` (parts 5, 6, and 7) for the applied values.

## What's confirmed vs. still open

**Confirmed, not guessed:**
- The muzzle ring is a static painted asset with no fire-triggered visibility or texture swap.
- The exact corner cluster this project had been unable to size/place correctly (far barrel
  edges + all 4 ring corners) was precisely the cluster a previously-untraced, always-executing
  block of code recomputes every frame -- it was never meant to be read as fixed data.
- The recomputation mechanism itself (a vector add against one constant offset; optionally a
  single-plane rotation first) is fully decompiled and matches known patterns from elsewhere in
  this project, not a new kind of instruction.
- **The fix**: recomputing those 7 corners as `base + offset` (the identity/no-turret-aim case)
  and rendering the result produces a correctly-proportioned ring at the barrel's real tip --
  confirmed by screenshot across all 8 discrete headings against the previous rendering, not
  assumed from the arithmetic alone. Applied in `game/vehicle_box_3d.gd`'s `TURRET_PARTS`.
- `DAT_0043e40c`'s apparent overlap with the hull's own corner data is a coincidence of static
  layout, not a real correspondence -- `FUN_00409b10` never advances that pointer, so only its
  first vec3 is ever read; the hull-corner bytes after it are never touched by this code.

**Still open (documented simplifications, not bugs):**
- What `iVar1` (the value read from the linked sub-object at `+0x50`) actually equals during
  real play is still unknown -- this project renders the identity/no-rotation case
  unconditionally, which is confirmed to look right for a level, non-elevated gun (matching
  every reference screenshot on hand) but doesn't model actual gun elevation if the original
  ever visibly pitches the barrel. No aim-angle state exists in this project to drive that
  yet, consistent with the turret-aim simplification already documented in document 39.
- The rotation branch (`FUN_0041ae10`/`FUN_00410c60`, for whenever elevation *is* eventually
  modelled) is decompiled and understood but not exercised by any current code path.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
