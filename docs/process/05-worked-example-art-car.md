# 5. Worked example: `ART.CAR`, and a wrong turn

`ART.CAR` (1,926,415 bytes) is Return Fire's sprite file — 2165 individually-positioned
images (3DO calls this unit a "cel", short for celluloid, and a "Cel Control Block" or CCB
is the 68-byte struct describing one: where its pixel data lives, its width/height, its
flags). This document is included specifically because, unlike the `.RFM` investigation in
[document 4](04-worked-example-rfm-format.md), the first hypothesis here was **wrong**, it
got shipped in the converter anyway as a "best effort," and the process of catching that and
fixing it is at least as instructive as the format itself.

## What went right immediately

Most of `ART.CAR` was straightforward. Of 2165 cels, 2072 have a CCB field called `PRE0`
equal to zero, and for those, the pixel data is simply `Width * Height` raw bytes at
`SourcePtr`, one byte per pixel, indexing into a palette. That was confirmed two ways:
consecutive cels' byte offsets are separated by exactly `Width * Height` for the vast
majority of measurable cels, and — the real test — decoding all 2072 into an atlas and
**looking at it** produced instantly recognisable sprite art. Palette index 0 being
transparent was settled the same way: a statistical border-vs-interior heuristic came back
"inconclusive" (77.8% of border pixels were index 0, but so were 61.5% of interior pixels —
these sprites are mostly empty space inside power-of-two cells, so the heuristic couldn't
tell), and looking at the rendered atlas settled it in seconds. Sprites sat cleanly isolated
on transparent black. **When a question is visual, render it and look — don't try to answer
it with statistics instead**, a rule this project keeps relearning; see [document 6](06-verification-philosophy.md).

## The 93 exceptions, and the first hypothesis

93 of 2165 cels have `PRE0 != 0`. Two pieces of evidence made "compressed pixel data"
the obvious first guess: `PRE0`'s low 3 bits happened to match the real 3DO bit-depth
convention (1/2/3/5 = 1/2/4/8 bits per pixel), and direct byte inspection of one such cel
(a 16x16 = 256-pixel sprite with only 119 bytes of data) found a genuinely real structure —
a table of per-row offsets, one `u16` per row, some entries `0` (meaning "this row is
blank") and others pointing past the table to that row's data. That's exactly the shape a
real 3DO packed-cel format uses.

So a decoder got built (`tools/rfcel.py`) implementing the standard 3DO opcode scheme on
top of that row table: 2 bits of run-type, 6 bits of run-length, per byte — literal pixels,
transparent skip, or repeat-last-pixel. It ran without crashing on 92 of the 93 cels, and
consumed a number of bytes broadly consistent with the cel's declared size.

**It was wrong.** Rendered, the output was colour noise for the 8bpp cels and near-total
transparency for the lower-bit-depth ones. Not a subtle bug — visibly, obviously not
sprites.

## Catching it: the byte-budget checked out, and it didn't matter

This is the moment worth sitting with, because "the decoder ran to completion and used a
plausible number of bytes" is exactly the kind of signal that's tempting to treat as
success — it's cheap to check automatically, and it *feels* like evidence. Here, it was
almost worthless: 92 of 93 cels decoded "successfully" by that measure, and every one of
them was garbage. **A plausible byte count is not a correctness proof for a codec** —
finding that out the hard way here is where that rule (repeated again in
[document 6](06-verification-philosophy.md)) actually comes from.

The earlier draft of the project plan recorded the honest state at the time: this hypothesis
was demonstrably wrong, the row-table structure was real and worth keeping, and the actual
opcode semantics needed settling from the binary, not more guessing. `tools/rfcel.py` was
kept in the repo — not deleted — explicitly marked as a superseded hypothesis, because the
structural finding inside it (the row-offset table) turned out to still be correct, just
wrongly interpreted. That distinction — keep what was actually confirmed, discard only the
part that was wrong — mattered a lot once the real answer showed up.

## Going to Ghidra to find out what these actually are

The real per-frame cel-rendering dispatcher, `FUN_00418ef0`, was found by tracing forward
from the sprite-submission queue (`FUN_00413c90`, which copies a CCB into a ring buffer
every time something is drawn) through its drain path (`FUN_0041d510` → `FUN_00436fd0` → an
indirect call through a function-pointer global) rather than from a string or magic number —
there's no anchor string for "the renderer," so the anchor here was a *data structure*
(the queue) traced with `FindDataXrefs.java` instead.

Reading that dispatcher immediately overturned the starting assumption: it switches on
`PRE0`'s **raw 32-bit value**, not `PRE0 & 7` as the bit-depth-code guess had assumed. The
actual `PRE0` values present in the file are `{1, 2, 3, 5, 13, 17}` — not a clean bit-depth
code at all, but six distinct dispatch cases.

**What they actually are: not sprites, at all.** They're coverage masks for a masked
background-recolour blend effect — shadows, scorch marks, radar/sonar rings, explosion
starbursts, targeting reticles. The mask says *where* to draw; the colour comes from
remapping whatever pixel is already on screen underneath, through a small translation
table: `dest[x,y] = TransTable[dest[x,y]]`. There is no colour data in these cels at all —
which is exactly why the earlier decoder, hunting for colour data, could never have found
anything but noise, no matter how correct its bit-unpacking had been. It was solving the
wrong problem.

Two mask encodings exist, split by which `PRE0` value a cel has, straight from
`tools/rf_effect_cel.py`'s module docstring:

```
MASK_FAMILY_LINEAR = {1, 2, 3, 4, 5, 17}
    Plain Width*Height byte array, 0 = not covered, nonzero = covered.

MASK_FAMILY_SPAN = {13}     (46 of the 93 cels -- the majority)
    SourcePtr points to a table of Height row offsets -- THE SAME ROW-OFFSET TABLE
    the original (wrong) investigation had already found. Each row's data is a list
    of (x0, x1) span pairs -- "cover columns x0..x1 on this row" -- proportionally
    scaled from a stored 0-255 range, terminated by a pair whose first byte is 0.
```

That's the detail worth pulling out explicitly: **the structural finding from the wrong
hypothesis was correct all along.** The row-offset table is real, and it's exactly the
mechanism the span-mask family uses — the only thing that was wrong was what came *after*
finding it: not a bit-packed literal/skip/repeat opcode stream over pixel colours, but a
list of coverage spans over a mask. Keeping the disproven decoder around, with its findings
clearly labeled rather than discarded wholesale, meant that correct piece didn't have to be
rediscovered from scratch.

## Verifying the correction

Same standard as everywhere else in this project: decode all 93 real cels, and look at the
output. A `PRE0=13` cel (16x16, span-mask family) decodes to a clean, roughly circular
blob/splat silhouette. A `PRE0=1` cel (64x64, linear-mask family) decodes to a clean
rectangular notched-block shape. Both are obviously intentional shapes — a splat, a block —
not noise, and this time "not noise" is doing real evidential work, because noise is
specifically what the wrong hypothesis had produced from the same input bytes moments
earlier.

`tools/convert_car.py` now extracts all 2165 cels correctly: 2072 real sprites into
`art_atlas.png` (unchanged from the start), and the 93 masks into a separate
`art_effects.png`, tagged with which of four shared runtime translation tables (or the
cel's own palette, for `PRE0=17`) each one nominally uses. **There is no more missing or
unrecovered art in `ART.CAR`** — every one of the 2165 cels is now correctly classified as
either sprite or effect-mask, cross-checked with zero exceptions.

## What's still open

*(Update: the tint colour question below was solved after this document was first written —
see [document 9](09-worked-example-effect-tint-colour.md). Left as originally written here,
since the gap between "shape solved" and "colour solved" is itself part of the story.)*

The mask *shape* is fully solved; the exact on-screen *tint colour* isn't. The four shared
translation tables live in the running program's zeroed memory (BSS) — they don't exist as
static file data — and get filled in at startup by `FUN_00424420`, which tries to load
`Art\Trans.tbl` and falls back to generating one if it's missing. Neither the file-load path
nor the fallback-generation path has been traced yet. Until then, a placeholder tint (plain
white or a team-colour alpha blend) is a reasonable stand-in for the effect masks in Godot —
see [the next-steps doc](NEXT_STEPS.md).

**Next:** [Verification philosophy — the rules this document and the last one both learned the expensive way](06-verification-philosophy.md).
