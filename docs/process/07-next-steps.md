# 7. Next steps

The authoritative, fully detailed backlog is `docs/PORTING_PLAN.md` section 4 — this
document is a friendlier on-ramp to the same list: what's next, why it's next, and roughly
how you'd go about it yourself using the recipe from [document 3](03-ghidra-workflow.md).
Check the plan doc for the precise, current state before starting any of these — it gets
updated as work lands, and this document might lag it slightly.

## Highest priority: map the 104 `.RFM` art ids to real `ART.CAR` sprites

Both halves of this are now individually solved and verified — [document 4](04-worked-example-rfm-format.md)
gives every level tile a resolved numeric "art id" (0-127ish), and
[document 5](05-worked-example-art-car.md) correctly classifies all 2165 `ART.CAR` cels
into sprites vs. effect masks. Neither half tells you **which of the 2072 real sprites is
art id 42.** That link is what's needed before a level can render with real art in Godot at
all (Phase 4 step 1 in the plan).

Two ways to attack this, worth trying in this order:

1. **Empirical, no more Ghidra needed:** generate the `.RFM` debug-render for every level
   (already implemented, see document 4), and look at *where* each art id appears and how
   often. `art_id=0`'s huge 57-raw-value bucket is almost certainly "generic buildable
   land," just from being overwhelmingly the most common tile everywhere. Coastline-range
   art ids only ever appear adjacent to that bucket, which tells you they're edge variants
   of it. This gets you most of the way with zero new RE — terrain art in this era is
   usually a small, guessable set (water, land, a handful of coastline edges) once you can
   see the *shape* each id traces out across real levels.
2. **Definitive, more RE:** find where the game's own rendering code converts a *runtime
   tile value* into a specific cel index for drawing. That code has to exist somewhere —
   the game itself renders these levels correctly — and finding it would give you the exact
   mapping instead of an educated guess. Start from `FUN_00414130` (the level loader,
   already fully decompiled) and look for what happens to its runtime tile buffer once
   gameplay actually starts rendering, using `FindDataXrefs.java` on the buffer's address
   the same way the `ART.CAR` render queue was traced in document 5.

## The rest, roughly in priority order (see the plan for full detail)

- **Effect-mask tint colour** ([document 5](05-worked-example-art-car.md)'s open item):
  decompile `FUN_00424420`'s `Art\Trans.tbl` load-or-generate path. Cosmetic — a placeholder
  tint works fine until this is done.
- **`.RFM` header body, offsets `0x04`-`0x3F`:** most fields here are still unidentified
  besides width/height/mode-byte. Likely more per-level gameplay metadata. Good first
  independent exercise: pick one unidentified offset, and try correlating its value against
  something observable (level name, mode, filename) across all 204 files the way the VHCL
  chunk correlation was found in document 4.
- **The `>>1` "half the pool count" computation** right after the random building/target
  pick in the level loader — likely a win-condition threshold ("destroy half the spawned
  targets"). Worth chasing by decompiling a little further from where document 4 left off.
- **Team colouring mechanism:** how are the two teams visually distinguished? Plausibly the
  *same* masked-palette-translation mechanism document 5 found for effect masks — worth
  checking that hypothesis first, since the machinery to test it already exists.
- **`EDTN` chunk meaning** — a 4-byte value present in every `.RFM` file, not yet decoded.
  Low priority; the converter already round-trips it without understanding it.
- Framebuffer dimensions, the fixed simulation tick rate, implicit sprite pivots, whether
  music is Redbook CD audio or a local `.wav` fallback — all listed with more context in
  plan section 4.

## If you want to try one of these yourself

The shape is always the same, and it's the same shape as documents 4 and 5:

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
