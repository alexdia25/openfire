# 19. Worked example: classifying 2165 cels without a disassembler

Every worked example so far ends with an answer traced through `RFIRE.BIN`'s code. This one
is different in kind: the asset ID registry (`docs/PORTING_PLAN.md` section 2.4.1) isn't a
reverse-engineering question with a true answer sitting in the binary — it's an authoring
task, "look at 2165 pieces of art and name them," and the interesting part is how that task
got scoped and tooled rather than any single decompile.

## The starting point

Section 1.6 had already fully solved `ART.CAR`'s *structure* — 2165 cels, which ones are
sprites vs. effect masks, the exact tint mechanism for every mask. What it hadn't done, and
couldn't from structure alone, was say what any given cel *is*: cel 1427 is some `32x32`
sprite with `PRE0==0`, and that's all the converter output can tell you. An artist asked to
redraw it has nothing to go on. That's exactly the gap section 2.4.1 calls "the gating
deliverable" — nothing in Phase 4 can reference art by stable semantic ID until this exists.

## Choosing how to build it

Before writing any code, there were two honest options: bootstrap the registry with
placeholder IDs and fill them in as Phase 4 needs specific art, or classify everything up
front. The user chose the latter explicitly — full semantic classification first, not a
just-in-time placeholder scheme. That decision shaped everything downstream: this had to be
a real, if imperfect, pass over all 2165 cels, not a sampling exercise.

## First tool: a labelled contact sheet

`tools/registry/contact_sheet.py` crops cels out of `build/car/art_atlas.png` /
`art_effects.png` by index, letterboxes each into a fixed-size cell on a checkerboard
background (so transparency is visible), and labels every cell with its cel index. Options
filter by an explicit index list, by `kind`/`pre0`, or by `--unclassified` (skip anything
already in the registry). This is the one piece of infrastructure the entire rest of the
effort sits on — every classification decision below started with generating one of these
and reading it with the `Read` tool, the same way any other image gets inspected in this
project.

## Batch 1: the parts already solved by code

The terrain tileset (cels 0-111, section 1.7) and all 89 effect masks (section 1.6) didn't
need fresh visual judgment — their *function* was already fully traced. Effect masks were
classified by `PRE0` value alone (`effect.shadow.hard`, `.soft`, `effect.tint.colour`,
`effect.glow` — see `tools/registry/classify_batch1.py`), which is why they're tagged
`"confirmed"` rather than `"visual"`: the ID follows directly from code already read, not
from looking at pixels. The terrain block needed actual contact-sheet review (two coastline
autotile families, 20 shapes each, turned up by eye — sand/water and forest/water, matching
counts, clearly the same underlying autotile system reused for two biomes) but every cel in
it got a specific name, because 112 cels is small enough to do carefully.

One thing this batch also did, almost by accident: it noticed that some terrain cels render
as fully transparent (`80`, `92`). That observation became `classify_blank.py` — a
programmatic sweep for any remaining cel whose crop has `alpha extrema == (0, 0)`, checked
against `art_atlas.png` directly rather than eyeballed. It caught 121 cels project-wide in
one pass, which is also why the next contact sheet (154-216) initially looked wrong: gaps
where blank cels used to be shifted every subsequent index by eye. Filtering with
`--unclassified` after running the blank sweep fixed that — a small example of section 6's
standing rule (verify against the data, not a hand count) applying to tooling, not just to
decompiled C.

## The scope reality check

By cel 625, roughly 700 cels in, the pattern was clear: full per-cel precision (naming
`vehicle.hovercraft.hull_front.tan` rather than just `vehicle.hovercraft.hull.07`) was
achievable but slow, and ~1960 cels remained. Rather than assume an answer, this got asked
directly: coarse pass now (object + sequential number, refine once real rendering can verify
against gameplay) or full precision up front. The user chose coarse. That single decision
is why every ID from cel 630 onward looks like `effect.burst_red.114` instead of a fully
disambiguated name — not laziness, a scoped trade-off made explicitly rather than assumed.

## Two techniques that beat eyeballing

Two points in the remaining ~1960 cels were bad fits for "look at the picture, type a name":

- **Cels 655-754** are a ~100-frame running/walking human animation that alternates between
  two team colours in blocks of ~5. Transcribing which frame is tan vs. blue by eye across
  100 cels is exactly the kind of place a miscount creeps in unnoticed. Instead,
  `dominant_team_colour()` crops each cel, averages the RGB of its non-transparent pixels,
  and picks blue vs. tan by which channel dominates — checked against real output before
  trusting it (a good habit reinforced by document 6's rule 3, even though this isn't a
  reverse-engineering claim about the binary).
- **Cels 1077-1563 and beyond** are overwhelmingly explosion/smoke/dust/blood burst
  animation frames — on the order of 300 near-identical cels. Naming each one individually
  would have been slower than the colour-average approach *and* no more reliable, since
  "red burst frame #47 vs #52" isn't a distinction a human eye reliably tracks either. A
  `_colour_bucket()` helper sorts each into `effect.burst_red` / `_brown` / `_green` by mean
  channel dominance, with a few visually distinct exceptions (a checkered flag, expanding
  shockwave rings in four colours, blue splash puffs) carved out first by hand because they
  were genuinely different shapes, not just different colours of the same blob.

Both are recorded as functions in `tools/registry/classify_bulk.py`, not one-off scripts —
the point isn't just "these 280 cels got an ID," it's "here is a reusable, auditable reason
they got the ID they did," which matters more here than in most of this project's findings
because there's no ground truth in the binary to check the answer against.

## A bug worth recording

The bulk script accumulates classification calls across many contact-sheet sessions in one
file, and each call needs a sequence number that doesn't collide with numbers already used
by that same ID family elsewhere in the file. The first attempt at auto-numbering
(`_next_seq()`) had a subtle bug: the helper that was supposed to just *check* whether a
family's counter was seeded also *consumed* a number as a side effect every time it was
called "to be safe" — so every batch silently burned one extra ID per family before handing
out numbers, and once two batches shared a family name closely enough, the burned numbers
collided for real (`classify_bulk.py`'s own duplicate-ID check caught it immediately, which
is the entire reason that check exists). The fix split seeding and consuming into two
separate functions. Small, but a good illustration of section 6's general lesson showing up
in ordinary Python rather than decompiled C: a helper that's supposed to be side-effect-free
for "just checking" is a common place for this exact class of bug to hide.

## What came out of just looking

Classifying art at this volume surfaces things a targeted Ghidra search never would, because
nobody was looking for them — they were just *there* once every cel got looked at:

- **A possible team-colour mechanism.** The hovercraft's hull/cab pieces recur as matching
  tan/cyan pairs at the same pose (cels 167-209). Section 4 item 5 had no lead at all on
  this before; now there's a specific, checkable hypothesis (duplicate art per team, not a
  palette swap) instead of an open shrug.
- **A full on-foot infantry unit.** Cels 655-754 are a real, human-scale running animation,
  not a portrait — something section 0's feature list never mentioned. Surrounding cels
  (red-cross-like markers, barred cage panels, a doorway, a chaotic multi-figure clash
  animation) read as rescue/POW-camp dressing. None of this is confirmed against `.RFM`
  entity data or the renderer yet — it's a pixel-level read, recorded as a new open question
  (section 4 item 9) rather than asserted as fact.
- **A handheld weapon and the HUD font**, sitting in `ART.CAR` alongside everything else
  (cel 1940; cels 2146-2155, a clean literal `0`-`9` digit set).

## The lesson

Not every question this project answers is "what does this byte mean." Building the asset
registry was closer to an editorial task — deciding how much confidence to claim, when to
trust a human eye vs. a pixel average, and when to stop refining and move on — than to the
anchor-xref-decompile recipe every other document here follows. The same standing rules
still applied (verify against real data, render and look, record what you don't know rather
than guessing past it), they just applied to a spreadsheet-shaped problem instead of a
disassembly-shaped one. Worth remembering that "reverse engineering this game" is not
exclusively a Ghidra activity.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog — Phase 4 (the
actual terrain/sprite renderer) is next up, unblocked by this document's work; team
colouring (section 4 item 5) and the possible rescue mechanic (item 9) are open follow-ups
this document's classification work surfaced.
