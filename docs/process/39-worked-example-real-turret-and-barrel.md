# 39. Worked example: the turret and gun barrel are a real, separate object

The user's directive that started this document, after two straight rounds of "looks fixed"
being undone by their own screenshots: "we need to better understand the original code to
understand how to fully build the tank." Going back to the actual rendering dispatch code --
not the generic per-descriptor renderer document 38 had already decompiled, but the function
one level up that actually *calls* it for vehicles -- found the answer in one read.

## The Tank's hull really does have only 6 real parts

Document 38's "14 parts, not 6, not 8" finding was itself wrong. The real cause: the hull
descriptor's parts array (`0x0043e700`) sits in memory immediately before a **different, real
descriptor's** parts array (`0x0043e7c0` -- exactly 6 part-records, 192 bytes, later). The
hull's own corner array (`0x0043e418`, 24 corners) is immediately followed by that same other
descriptor's corner array (`0x0043e538`, 22 corners). Boundary-detection walking forward from
the hull's own arrays -- with no way to know where one descriptor's data ends and an unrelated
one begins -- walked straight through the real end of the hull's 6-part array and into this
adjacent, unrelated, but perfectly well-formed data, misreading it as "8 more hull parts."
Reading each part's corner indices against the hull's own (wrong) corner array, instead of the
other descriptor's own (correct) one, is exactly why every one of those "extra 8 hull parts"
looked distorted or oversized no matter which of two real, separately-confirmed bugs got fixed
along the way (a triangulation winding bug; a missing `.transparency` line) -- neither was ever
the actual problem. Document 37's original 6-part finding was correct the whole time.

## The turret is that other descriptor

Document 38 had already decompiled `FUN_0041b2b0`, the generic function that walks any
descriptor's parts array and draws them -- both the hull and this other, unidentified
descriptor call it. What hadn't been checked was `FUN_00402dc0`, the real vehicle draw
*dispatcher* that decides what to call it with:

```c
void FUN_00402dc0(int param_1, int param_2) {
    FUN_0041b430(param_1, param_2);              // draw the hull, current descriptor
    if (**(int **)(*(int *)(param_1 + 0x2c) + 0x14) == 1) {
        // a linked sub-object exists and is active
        iVar1 = *(int *)(*(int *)(param_1 + 0x2c) + 0x60);
        *(uint *)(param_1 + 0x1c) =               // compose: hull heading + turret aim angle
            *(int *)(iVar1 + 0x58) + *(int *)(param_1 + 0x1c) & 0x3fffff;
        iVar1 = *(int *)(iVar1 + 0x50);
    } else {
        iVar1 = 0;
    }
    ... // an unrelated small 7-corner "linkage" computation, not traced further
    *(undefined ***)(param_1 + 0xc) = &PTR_FUN_0043e9b8;   // SWAP to a wholly different descriptor
    FUN_0041b430(param_1, param_2);              // draw AGAIN, with the new descriptor + angle
}
```

This draws the hull once, then -- if a linked sub-object exists -- swaps in a **completely
different descriptor** (`0x0043e9b8`) and draws a second time with an **independently composed
rotation**: the hull's own heading plus a separate turret-aim angle read from the linked
sub-object. That second descriptor is the turret. It is structurally identical to the hull's
own descriptor (same format: corner count, corner pointer, parts pointer, 8 angle-bucket
pointers) but is a wholly separate record, with its own real 22-corner array and its own real
8 parts -- extracted with a small generalization of the existing tooling
(`tools/ghidra_scripts/DumpDescriptorParts.java <descAddr>`, since the extraction logic itself
needed no changes, just a way to point it at an address that isn't one of the 4 vehicle-type
table entries).

## The 8 turret parts are the exact same 8 cels the hull investigation never placed correctly

177, 192 (x2), 197, 207, 202 (x2), 212 -- the identical set of cels document 38 spent an entire
session trying and failing to place as hull decals. Read against the *correct* corner array
this time, they resolve into a coherent, sensibly-scaled shape:

| Part(s) | Cel | Role |
|---|---|---|
| 0 | 177 | Turret's flat top panel, 24 units above the vehicle's local origin -- clear of the hull's own 13.333-unit roof |
| 1, 2, 3, 4 | 192, 192, 197, 207 | The turret box's 4 sloped sides, tapering from the wider top down to the hull's roofline |
| 5, 6 | 202, 202 | The gun barrel -- two panels meeting at a point, extending forward and rising slightly, ending flush with the hull's own front edge |
| 7 | 212 | A ring mounted at the barrel's tip (the muzzle) |

Rendered, this produces a raised turret box with a barrel sticking out the front, red-banded
with a bright tip -- matching the user's reference screenshots directly, confirmed by a
side-by-side comparison at a matched heading. `game/vehicle_box_3d.gd`'s `TURRET_PARTS` const
replaces its own entire previous (wrong) attempt at these 8 cels.

## What's still open

**The muzzle ring (part 7, cel 212) renders visibly larger and lower than the barrel tip it
caps.** This was checked three separate ways before accepting it as a genuinely open question
rather than a bug to keep guessing at:

- The raw corner table was re-read directly from memory (not re-derived from the part record)
  and matches the original extraction exactly -- not a transcription error.
- `FUN_0041b2b0`'s backface-culling flags (`piVar7[2]`/`[3]`, gated by flags bits `0x1`/`0x2`)
  are unset for every part in this descriptor (flags are uniformly `0x8`, team-colour only) --
  inert, not a hidden scale mechanism.
- `FUN_0041ae10` (the rotation-matrix builder used for the composed hull+turret-aim angle) is a
  pure rotation matrix -- diagonal terms are `1, cos, cos`, not independent scale factors.
- The turret's angle-bucket lists (its per-viewing-angle draw *order*, confirmed a real,
  separate mechanism from a part *manifest* in document 38) include index 7 in all 8 buckets --
  the ring is never hidden at any angle; buckets only reorder draw sequence for depth sorting.

One hand-adjustment was tried: constraining the ring's vertical extent to match the barrel's
own tip band (18.67 to 29.33, instead of the raw 8 to 29.33). It fixed the apparent size but
broke the aspect ratio into a visibly squashed oval -- worse in a different way, and clear
evidence that the raw data's own *proportions* are more likely right than a guessed
constraint, even though something about its size or position still doesn't read correctly.
Reverted to the raw, unmodified data rather than ship a second guess. This needs a real
answer -- something this project hasn't found yet, not a hand-tuned number -- to close cleanly.

Also still open, unchanged from document 38: independent turret aim is not modelled (no
AI/player aim-angle state exists in this project to drive the composed rotation) -- the turret
renders at the same heading as the hull, a documented simplification. Jeep/MSV/Heli's own
equivalent turret-style sub-objects, if they have any, are untraced.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
