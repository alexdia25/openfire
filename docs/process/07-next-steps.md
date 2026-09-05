# 7. Next steps

The authoritative, fully detailed backlog is `docs/PORTING_PLAN.md` section 4 — this
document is a friendlier on-ramp to the same list: what's next, why it's next, and roughly
how you'd go about it yourself using the recipe from [document 3](03-ghidra-workflow.md).
Check the plan doc for the precise, current state before starting any of these — it gets
updated as work lands, and this document might lag it slightly.

## DONE: map the 104 `.RFM` art ids to real `ART.CAR` sprites

This was the highest-priority item — the last thing blocking Phase 4 step 1 (render a level
with real art). It's solved: **the art id *is* the `ART.CAR` cel index**, with no mapping
table anywhere in the game — the renderer loads `ART.CAR`'s CCB array into memory unmodified
and indexes it directly with the tile's art id. Of the two approaches this document used to
suggest, it turned out to need the second one (trace the real rendering code), and that
route reached an exact answer faster than the empirical guess would have. Full writeup:
[document 8](08-worked-example-art-id-mapping.md); ground truth: `docs/PORTING_PLAN.md`
section 1.7.

## DONE: effect-mask tint colour

[Document 5](05-worked-example-art-car.md)'s own open item. Solved: `FUN_00424420`'s
`Art\Trans.tbl` fallback-generation path fully decompiled, revealing exactly what each of
the 4 shared translation tables contains and how the 3 mask-blit routines use them — plus a
refinement (some masks' byte *value*, not just coverage, selects a tint colour or brightness
level) caught only by checking real mask bytes, not just the code. Along the way, found that
one of the 93 "mask" cels (`PRE0==17`, 4 cels) isn't a mask at all — it's an ordinary sprite
with its own embedded palette, now extracted as such. Full writeup:
[document 9](09-worked-example-effect-tint-colour.md); ground truth: `docs/PORTING_PLAN.md`
section 1.6.

## DONE: the `>>1` "half the pool count" computation

Turned out to be small — 2 `FindDataXrefs.java` calls, no dead ends. It's not a win
condition by itself: each candidate pool is a rotating single-target spawner (destroy the
active target, a replacement immediately activates from the pool's remaining candidates),
with the halved count as a total replacement budget. Also corrected a stale guess: runtime
tile bits 14-15 are the pool-membership tag, not "orientation." What still isn't found: any
code that reads both pools' budgets to declare a match won or lost — see below. Full
writeup: [document 10](10-worked-example-target-respawn.md); ground truth:
`docs/PORTING_PLAN.md` section 1.5.

## DONE (with a caveat): the `EDTN` chunk meaning

The fastest resolution in the series — no new Ghidra calls at all, just rereading a
decompile log already produced for a different investigation. Confirmed the level loader
checks for exactly 3 chunk tags (`VHCL`, `NAME`, `LEVL`) and no others; `EDTN` is walked past
generically and never read by the game itself. Not decoded, but confirmed *irrelevant* to a
faithful port — a stronger result than decoding it would have been. Full writeup:
[document 11](11-worked-example-edtn-chunk.md); ground truth: `docs/PORTING_PLAN.md`
section 1.5.

## RULED OUT (not solved): what ends a match

Document 10's obvious next hop, `FUN_0042c4d0`, turned out to be a dead end — a generic
"mark this object dead" utility called from 35+ unrelated sites, nothing to do with match
state. The trail from there runs into a large, general AI-targeting/combat subsystem with no
clear "declare victory" anchor, so this is left open rather than chased further on a hunch.
See document 10's postscript for the full account of checking and rejecting this lead.

## DONE: the `.RFM` header body

This one used the exact approach this document used to suggest — pure empirical byte-variance
correlation across all 204 real files, no Ghidra at all — and it worked. Found a DOS-format
created/modified timestamp pair and a 15-byte author/designer-name field (real names:
`MichaelAngelo`, `John L. Saleigh`, `Van`, and others — the actual credited level designers,
still in the shipped data), and resolved the long-dangling "offset 0x18 string" loose end
from document 4 (the real field starts at `0x17`). Both fields are now in
`tools/convert_rfm.py`'s JSON output (`author`, `created`, `modified`). Full writeup:
[document 12](12-worked-example-header-body.md); ground truth: `docs/PORTING_PLAN.md`
section 1.5.

## DONE: how music playback actually works

Traced every caller of `mciSendCommandA` and found the whole mechanism in one pass: an MCI
`cdaudio` device plays Redbook track frame-ranges when a real audio CD is present, and falls
back to streaming `SOUND\Score.WAV` (via the AVIFile streaming API, reusing the same
per-track boundary table as byte offsets) when it isn't. The backlog's own guess about which
WAV file is the fallback was wrong — it's not `DRUMS.WAV`, which `FindBytes.java` confirmed
is never referenced by the binary at all. Full writeup:
[document 14](14-worked-example-music-mechanism.md); ground truth: `docs/PORTING_PLAN.md`
section 1.8.

## DONE (half of it): native resolution is 320x240; sim tick rate still open

Traced the window-creation call back to its size globals and found one hardcoded default,
set once in the command-line parser before any override flag: 320x240. The paired question
— is there a fixed simulation tick rate? — traced through the real main-loop idle call chain
down to a state-machine table (`PTR_PTR_0044e27c`), and a follow-up pass dumping that table's
actual contents ruled it out: all of it resolves to the boot-time publisher/title-logo
slideshow (bitmap names + fade-timing triples), not gameplay — a different flavour of dead
end than document 10's, since the function was faithfully traced, it's just the wrong system.
`SetTimer` also has zero references anywhere in the binary, ruling out a `WM_TIMER`-based
tick too. Still open, narrower now: the next candidate is a blocking
`IDirectDrawSurface::Flip` call pacing the loop on vsync. Full account (including the
postscript that ran the "next hop" and found the dead end):
[document 15](15-worked-example-resolution-and-tick-rate.md); ground truth:
`docs/PORTING_PLAN.md` section 1.9.

## RULED OUT (not solved): the "team-colour swatch" lead

Document 9's guess about the 4 `PRE0==17` cels — that their odd, saturated own-palette look
might be an unused team-colour swatch — turned out to be wrong once actually rendered: they're
a 16x16 concentric-ring target-lock reticle (purple/black/yellow rings, one inner ring
recoloured per cel), not a swatch. `FindConstant.java` also found no literal code reference to
any of their 4 cel indices, so there's no easy follow-up trail from this lead specifically.
Full account: [document 13](13-worked-example-reticle-not-swatch.md); ground truth:
`docs/PORTING_PLAN.md` section 1.6.

## DONE (and the question's premise was wrong): "implicit sprite pivots"

Rereading `FUN_0042dd90` (already decompiled for the team-colouring lead above) for a
different question found that vehicles aren't rotated 2D sprites at all — the engine
projects real local-space 3D corner geometry through 64 precomputed rotation matrices and a
shared `1/z` perspective-scale table (also used by the terrain blitter, section 1.7), then
quad-maps the result onto the CCB's own arbitrary-parallelogram texture mode. There's no
pivot to extract because placement was never pivot-based. This is now a real, informed
rendering-architecture decision in plan section 2.2, not an open data question. Full
writeup: [document 16](16-worked-example-3d-projection.md); ground truth:
`docs/PORTING_PLAN.md` section 1.10.

## What's next, roughly in priority order (see the plan for full detail)

- **What ends a match?** (see above) — still open. A better next anchor is needed; possibly
  a separate score/objective variable rather than anything touching the target pools.
- **Team colouring mechanism:** how are the two teams visually distinguished? Back to fully
  open with no lead (see above) — the old `PRE0==17` lead is retracted. The
  `GetNearestPaletteIndex`-built translation-table infrastructure (document 9) is still a
  plausible mechanism in the abstract, but nothing ties it to team colouring specifically
  anymore. The next hop is to find wherever a vehicle's CCB gets queued for drawing and check
  what, if anything, varies it by team/owner — `FUN_0042dd90` (a heading-angle-based
  directional-sprite-frame selector found while chasing this) is a plausible place to start
  reading outward from, since it already indexes the same `ART.CAR` CCB array per-object.
- **The fixed sim tick rate** (see above) — `PTR_PTR_0044e27c` is ruled out (it's the title
  slideshow); next step is finding the real `IDirectDrawSurface::Flip` vtable call site and
  checking whether it blocks for vsync during actual gameplay.

## If you want to try one of these yourself

The shape is always the same, and it's the same shape as documents 4, 5, and 8 through 12 —
including document 10's postscript, document 11, and document 12, which show what it looks
like when the recipe runs into a dead end, needs no new work at all, or doesn't need Ghidra
in the first place — not just when it lands a clean answer the expected way:

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
and finally [there's no sprite pivot, because it's not 2D](16-worked-example-3d-projection.md) —
nine more items off this backlog, covering everything from a big investigation down to one
that cost nothing but a `grep`, one that never touched a disassembler by design, two that
retracted an earlier guess instead of confirming it, one that stopped honestly short of a
full answer instead of forcing one, and one that found the question itself was built on a
wrong assumption.
