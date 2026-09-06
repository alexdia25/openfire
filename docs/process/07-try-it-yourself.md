# Try it yourself

## If you want to try one of these yourself

The shape is always the same, and the worked-example docs above show what it looks like
whether it lands a clean answer, runs into a dead end, needs no new work at all, doesn't need
Ghidra in the first place, or finds the question's own premise was wrong:

1. Pick one item above (or from the plan's section 4).
2. Find an anchor — a string, an API call, or a data structure already known to be nearby
   (document 3's recipe).
3. `DecompileOne.java` outward from it until you're reading the actual logic that matters.
4. Form a hypothesis, write it down as a guess before you check it.
5. Check it against **every** real file (document 6, rule 3) — write a small Python script,
   don't eyeball a handful of examples.
6. If it's visual, render it and look (document 6, rule 1).
7. Update `docs/PORTING_PLAN.md` with what you found, right away — that's what let this
   whole investigation survive multiple context resets without losing ground.

Nothing here requires deep x86 or compiler-internals knowledge — the actual reverse
engineering in this project has mostly been *reading straightforward decompiled C and
cross-checking it against real files*, not fighting with raw disassembly. That's a
deliberate consequence of using Ghidra's decompiler rather than working from assembly
directly, and it's why this is realistically approachable to keep doing yourself.

**Next:** [Worked example: mapping `.RFM` art ids to `ART.CAR` cels](08-worked-example-art-id-mapping.md),
then [the exact tint colour of `ART.CAR`'s effect masks](09-worked-example-effect-tint-colour.md),
then [what the `>>1` computation actually does](10-worked-example-target-respawn.md),
then [confirming a dead end fast by rereading work already on hand](11-worked-example-edtn-chunk.md),
then [decoding the `.RFM` header body with no Ghidra at all](12-worked-example-header-body.md),
then [catching a wrong guess by finally rendering it](13-worked-example-reticle-not-swatch.md),
then [is the music CD audio or a WAV file? (Both.)](14-worked-example-music-mechanism.md),
then [the native resolution, and a tick rate that resists being found](15-worked-example-resolution-and-tick-rate.md),
then [there's no sprite pivot, because it's not 2D](16-worked-example-3d-projection.md),
then [reference discs arrive, and a stale guess gets corrected for free](17-worked-example-reference-iso.md),
then [finding a COM vtable call with no symbol to search for](18-worked-example-vtable-flip.md),
then [classifying 2165 cels without a disassembler](19-worked-example-asset-registry.md),
then [a wrong palette that never looked wrong enough to notice](20-worked-example-palette-offset.md),
then ["the sprite looks very wrong after moving" was two bugs, not one](21-worked-example-vehicle-mirroring-bug.md),
then [reusing a solved RE finding as running code](22-worked-example-weapons-and-targets.md),
then [an opponent with no reverse-engineering behind it at all](23-worked-example-enemy-ai-first-pass.md),
and finally [a debug string, a dedicated object, and a capture-the-flag lead](24-worked-example-capture-the-flag-lead.md).
