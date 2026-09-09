# 40. Worked example: the muzzle ring's corners are never static in the first place

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

`FUN_00409b10` is a plain 7-entry vector add (`dst[i] = a[i] + b[i]`, 3 components, 7 times).
`FUN_00410c60` is the same "apply a 3x3 matrix to N corners" routine already confirmed in
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

- `DAT_0043e640`: a 7-corner "base" shape, dumped and confirmed real (not zero/garbage).
- `DAT_0043e40c`: a 7-corner "offset" table -- whose first entry is its own value, but whose
  remaining six entries turn out to occupy the *exact same bytes* as the hull's own corner
  array's first six corners (`corner_ptr = 0x0043e418`, document 37/38's own hull data).
  This isn't a boundary-walk mistake this time -- the read count of 7 is a literal argument
  in the compiled call, not something this project's own tooling inferred -- so it's either a
  deliberate shared-layout choice from the original source (the barrel-tip assembly's anchor
  literally reuses specific hull vertices) or, at minimum, a real fact about how this data
  sits in memory that any static read of indices 15-21 has to account for.

**The corner values this project extracted for indices 15-21 (used for the far barrel edges
*and* the entire muzzle ring) are whatever the compiler happened to initialize that scratch
region to -- not necessarily a value a running game ever actually displays**, since
`FUN_00402dc0` overwrites them before the very first frame that ever draws this vehicle,
unconditionally, every time. Indices 0-14 don't have this problem, which is exactly why the
turret box and the barrel's near half already matched the reference screenshots and only the
tip cluster (parts 5-7's far corners, and specifically the ring) never did.

Summing the two static tables directly (the `iVar1 == 0` branch) does not reproduce a
plausible symmetric shape from the current dump -- either the "at rest" case genuinely goes
through the rotation branch instead (with `iVar1` almost never zero for an active turret,
landing on a nonzero elevation angle even when nominally level), or one of the two operand
tables needs its own correspondence re-checked rather than assumed index-for-index. That part
is not resolved yet -- flagged honestly rather than forced.

## What's confirmed vs. still open

**Confirmed, not guessed:**
- The muzzle ring is a static painted asset with no fire-triggered visibility or texture swap.
- The exact corner cluster this project has been unable to size/place correctly (far barrel
  edges + all 4 ring corners) is precisely the cluster a previously-untraced, always-executing
  block of code recomputes every frame -- it was never meant to be read as fixed data.
- The recomputation mechanism itself (vector add; optionally a single-plane rotation first) is
  fully decompiled and matches known patterns from elsewhere in this project, not a new kind
  of instruction.

**Still open:**
- What `iVar1` (the value read from the linked sub-object at `+0x50`) actually equals during
  real play, including at rest -- this determines which branch fires and can't be recovered
  from a static binary read alone.
- Whether `DAT_0043e40c`'s apparent overlap with the hull's own corners is the correct
  correspondence to use, or a red herring from adjacent static layout (this project has been
  burned by "adjacent-looks-related" before -- document 38/39's own hull/turret mixup).
- A verified, rendering-correct replacement formula for indices 15-21. Not shipped this
  session -- the arithmetic tried so far doesn't yet produce a shape that's obviously more
  correct than what's on screen now, and this project's standing rule is to not trade one
  guess for another.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
