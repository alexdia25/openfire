# 9. Worked example: the exact tint colour of `ART.CAR`'s effect masks

[Document 5](05-worked-example-art-car.md) solved the *shape* of `ART.CAR`'s 93
`PRE0 != 0` cels — coverage masks for a background-recolour blend effect — but left one
thing open: the actual on-screen colour, since the 4 shared translation tables the real
renderer uses live in runtime memory, not in any file this project has direct access to.
This is that investigation, and it ended up finding more than the tint colour alone: one of
those 93 cels turned out not to be a mask at all.

## Where document 5 left off

The known facts, from `tools/rf_effect_cel.py`'s docstring at the time: the renderer does
`dest[x,y] = TransTable[dest[x,y]]`, `TransTable` is one of 4 pointers
(`DAT_0046a8f0`/`aa08`/`aa0c`/`aa14`), and those 4 globals are all-zero in the static binary
— they're filled in at startup by `FUN_00424420`, which tries to load `Art\Trans.tbl` and
falls back to generating one if it's missing. Neither path had been read. The fallback path
is the more interesting one to start with: it has to compute real colours from *something*,
and that something is available for inspection.

## Reading the fallback-generation code

`DecompileOne.java 00424420` (re-decompiling a function already named from document 5's
trace) turned up the whole algorithm in one pass — no further searching needed, since the
anchor (the function address) already existed. The interesting part:

```c
DAT_0046aa0c = DAT_00458d1c + 4;
DAT_0046aa20 = DAT_00458d1c + 0x10004;
DAT_0046aa14 = DAT_00458d1c + 0x12004;
DAT_0046a8f0 = DAT_00458d1c + 0x10404;
DAT_0046aa08 = DAT_00458d1c + 0x10204;
```

Four pointer assignments into one `0x14004`-byte buffer (exactly the size of
`Art\Trans.tbl`) at four different offsets. Computing the *gaps* between these offsets
before reading anything else already suggests structure: `0x10204 - 0x10004 = 0x200` (512
bytes) and `0x10404 - 0x10204 = 0x200` again — both far smaller than a standalone table
would need, and both exact multiples of 256. That's the shape of "these two aren't separate
tables, they're rows 2 and 4 of *something* 256 bytes wide" — a hypothesis to confirm by
reading the generation loops, not to trust on arithmetic alone.

Three generation loops follow, each calling the Win32 GDI function
`GetNearestPaletteIndex(masterPalette, rgbColor)` — "which palette entry is closest to this
colour" — over every one of 256 palette entries, for 32 iterations in two of the three
loops. Reading the exact colour formula in each loop confirms what the offsets suggested:

- One loop fills a 256×256 = 65536-byte block (`DAT_0046aa0c`): for every pair of palette
  indices `(i, j)`, `table[i*256+j] = GetNearestPaletteIndex(master, average(colour_i,
  colour_j))`. A general "blend toward colour `i`" table, usable for *any* target tint.
- Two more loops fill 32×256 = 8192-byte blocks: one darkening every colour by 32
  progressively stronger amounts (`DAT_0046aa20`), one brightening by 32 amounts
  (`DAT_0046aa14`).
- `DAT_0046a8f0` and `DAT_0046aa08` never get their own generation loop — they're just
  pointer arithmetic landing on rows 4 and 2 of the darken table, confirming the gap
  hypothesis above exactly.

That's the whole mechanism: **2 of the 4 "shared tables" are actually the same darken table
at two fixed strengths, kept as separate names because those are the two shadow strengths
the game happens to use.**

## The mask *value* matters — caught by checking real data, not just the code

Reading the three mask-blit routines (`FUN_00419920`, `FUN_00419af0`, `FUN_004109a0`) shows
two different per-pixel formulas: some do `dest = table[dest]` (a flat lookup, mask only
gates whether it applies), others do `dest = table[mask_value*256 + dest]` — the mask's raw
*byte value*, not just whether it's zero, selects which row of a 2D table to use.

Reading the code makes this plausible; it doesn't make it true for the *real* data. Per
[document 6](06-verification-philosophy.md), the fix was to check real mask bytes directly:

```python
raw = data[source_ptr:source_ptr + width*height]
print(sorted(set(raw)))
```

Run against real cels, `PRE0` 1 and 2 (the flat-lookup family) come back genuinely binary —
`{0, 11}` and `{0, 243}` respectively, exactly one nonzero value per cel, confirming the
mask really is just a coverage flag there. `PRE0` 3 comes back `{0, 36, 37, 38, 39, 47, 49,
51}` — eight distinct nonzero values in one cel. `PRE0` 5 comes back with 16–25 distinct
values spanning a continuous 0–24-ish range. Both are exactly what "the byte value is a real
row selector" predicts and "the byte value is just a coverage flag" rules out. This is
the same lesson as documents 4 and 5 in a new shape: the code told the truth, but only
checking the real bytes turned "plausible" into "confirmed."

## The one surprise: `PRE0==17` isn't a mask

Every other `PRE0` value's blit routine reads *from the mask* and writes *through a shared
table* into the background. `FUN_00419ea0`, the routine for `PRE0==17`, does something
different: `dest = OwnPLUT[mask_value]` — a direct colour lookup through the **cel's own**
embedded palette, no background involved at all. That's not a background-recolour blend;
that's how an ordinary sprite gets drawn.

This explained a loose end sitting in the plan since document 5: `ART.CAR` has 3 distinct
`PLUTPtr` values, and 2 of them (`0x28AD0`, `0x28AE0`) only ever appeared on 2 cels each,
with no explanation for why. Checking directly: those exact 4 cels are the 4 `PRE0==17`
cels. Rendering them through their own palette (the same way any ordinary sprite is
rendered) produces fully-opaque 16×16 blocks of a handful of unrelated, highly saturated
colours — not a coherent picture, but a real, valid decode; nothing about it looks like a
broken read. What these 4 specific images are *for* is still an open question (a colour
swatch for team or UI accents is a plausible guess, given the saturated, distinct hues, but
no code referencing these 4 cels specifically has been traced — see
[document 7](07-next-steps.md) for that as a still-open lead, not a finding).

## Fixing the converter to match

Two real changes came out of this, both applied to `tools/convert_car.py` and
`tools/rf_effect_cel.py`:

1. **`PRE0==17` is no longer classified as an effect mask.** It goes through the same code
   path as an ordinary `PRE0==0` sprite (`Width*Height` raw bytes, its own PLUT, index-0
   transparency) and lands in `art_atlas.png`, not `art_effects.png`. `ART.CAR` now has 2076
   real sprites and 89 genuine masks, not 2072 and 93.
2. **`PRE0` 3/4/5 masks keep their real byte value** instead of being collapsed to a plain
   0/255 coverage flag, since the real renderer uses that value as a row selector. `PRE0`
   1/2/13 still collapse to 0/255, since those really are just coverage flags in the real
   data.

Both were re-run against the real file afterward (`python convert_car.py ...`) rather than
trusted from the diff alone — the count line in its own output (`89 cels are blend-effect
masks... 4 cels have PRE0 == 17... 3 distinct PLUT(s)`) is the same kind of "check it
actually ran against everything" step as every other converter change in this project.

## What's still open

The *shape* and *mechanism* of every effect mask are now fully understood, including which
table each one uses and why. What's still missing for a pixel-perfect Godot reproduction:
the exact realized palette (`GetNearestPaletteIndex` matches against the specific colours
Windows' GDI happened to allocate at runtime, which this project hasn't reproduced), and the
unconfirmed guess about what the 4 `PRE0==17` swatches are actually used for — see
[document 7](07-next-steps.md) for both as next steps, not blockers: a placeholder tint is
a perfectly reasonable stand-in until/unless exact colour fidelity matters.

**Next:** [Worked example: what the `>>1` computation actually does](10-worked-example-target-respawn.md) —
a much smaller investigation, worth reading for that reason alone.
