# 7. Next steps

The backlog itself — full technical detail, current state, always up to date — lives in
`docs/PORTING_PLAN.md` section 4. This document is just the connective tissue between the
worked-example docs: what got resolved, in what order, and where to read the full account.

## Resolved so far

- **`.RFM` art id → `ART.CAR` cel mapping** — [document 8](08-worked-example-art-id-mapping.md); plan section 1.7.
- **`ART.CAR` effect-mask tint colour** (and the `PRE0==17` reclassification) — [document 9](09-worked-example-effect-tint-colour.md); plan section 1.6.
- **The `>>1` candidate-pool computation** — [document 10](10-worked-example-target-respawn.md); plan section 1.5.
- **The `EDTN` chunk** (confirmed game-unused) — [document 11](11-worked-example-edtn-chunk.md); plan section 1.5.
- **The `.RFM` header body** (timestamps + level designer credits) — [document 12](12-worked-example-header-body.md); plan section 1.5.
- **The "team-colour swatch" lead** — ruled out — [document 13](13-worked-example-reticle-not-swatch.md); plan section 1.6.
- **Music playback mechanism** (CD audio + WAV fallback, not `DRUMS.WAV`) — [document 14](14-worked-example-music-mechanism.md); plan section 1.8.
- **Native resolution** (320x240) — [document 15](15-worked-example-resolution-and-tick-rate.md); plan section 1.9.
- **"Implicit sprite pivots"** (there isn't one — real 3D projection) — [document 16](16-worked-example-3d-projection.md); plan section 1.10.
- **The "missing `.avi` cutscenes"** (there weren't any — more streamed audio) — [document 17](17-worked-example-reference-iso.md); plan section 1.11.

## Still open

See plan section 4 for the current, precise state of each — this list is just pointers:

- What ends a match (section 4, item 1)
- Team colouring mechanism (section 4, item 3)
- The fixed sim tick rate (section 4, item 6)
- 3DO "Maps o' Death" expansion extraction — new goal, not yet started (section 4, item 7)

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
and finally [reference discs arrive, and a stale guess gets corrected for free](17-worked-example-reference-iso.md).
