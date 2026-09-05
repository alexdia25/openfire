# 8. Worked example: mapping `.RFM` art ids to `ART.CAR` cels

This is the backlog item [document 7](07-next-steps.md) called "highest priority": both
halves of level rendering were separately solved (every level tile has a 0-127 "art id",
[document 4](04-worked-example-rfm-format.md); every `ART.CAR` cel is classified as sprite
or effect mask, [document 5](05-worked-example-art-car.md)) but nothing tied one side to
the other. Document 7 suggested two ways to attack it: an empirical guess from level-render
shapes, or tracing the real rendering code with Ghidra. This is a record of doing the
second one — and finding the answer is far simpler than expected.

## Picking up the recipe again

[Document 3](03-ghidra-workflow.md)'s recipe needs an anchor. This time there's no magic
string or Win32 API to start from — the thing to trace is a *data structure*: the runtime
128x128 tile buffer, `DAT_0046aa30`. Its address didn't need a fresh search; it fell out of
work already done — decompiling the level loader (`FUN_00414130`) for document 4 shows it
being filled in with resolved tile values as the loader runs. Re-running
`DecompileOne.java 00414130` re-produces it without redoing that search:

```powershell
$env:JAVA_HOME = "C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
& "...\analyzeHeadless.bat" "...\ghidra_projects" returnfire -process RFIRE.BIN -noanalysis `
  -scriptPath "...\tools\ghidra_scripts" -postScript DecompileOne.java 00414130
```

## Step 2: who else touches this buffer?

`FindDataXrefs.java 0046aa30` is exactly the tool for "trace this global forward" (see
document 3's script table) — it found 21 functions. Most are the loader itself and its
helpers, already understood. One stood out on sight: `FUN_00408d60` computes camera-relative
screen offsets and walks a window of the tile grid every iteration — the shape of a
per-frame renderer, not a one-time loader. Inside it:

```c
puVar7 = (uint *)((*puVar4 & 0x7f) * 0x44 + DAT_0044964c);
puVar5 = (uint *)FUN_00413c90(local_a0);   /* the same render-submission queue from document 5 */
*puVar5 = *puVar7 & 0xbfffffff | 0x1000;
puVar5[2] = puVar7[2];                     /* SourcePtr, copied straight across */
puVar5[3] = puVar7[3];                     /* PLUTPtr, copied straight across */
```

`*puVar4 & 0x7f` is the tile's art id (document 4 already established the low 7 bits are the
art id). `0x44` is 68 in decimal — the exact size of a 3DO CCB struct (document 5). So this
line reads as: **take the art id, multiply by `sizeof(CCB)`, and use that as a byte offset
into an array of CCBs starting at `DAT_0044964c`.** Then it copies that CCB's `SourcePtr` and
`PLUTPtr` into a queue entry and submits it through the exact same rendering path used for
every ordinary sprite. No decoding, no special terrain-drawing code at all — a terrain tile
is drawn by treating its art id as an index into some CCB array and reusing the sprite
renderer verbatim.

That immediately raises the real question: **what is `DAT_0044964c`?**

## Step 3: tracing the array itself

Same tool again, new address: `FindDataXrefs.java 0044964c`. Among the hits was
`FUN_00424950`, and reading it settled everything at once:

```c
lpFileName = s_Art_art_CAR_00449688;         /* the string "Art\ART.CAR" */
hFile = (HANDLE)OpenFile(lpFileName, &local_94, 0);
...
DAT_00449648 = GlobalAlloc(0, dwBytes);
BVar1 = ReadFile(hFile, DAT_00449648, nNumberOfBytesToRead, &local_c, 0);
...
DAT_0044964c = (int)DAT_00449648 + 0x10;
```

This function opens `Art\ART.CAR`, reads the **entire file** into one allocated buffer with
a single `ReadFile` call, and sets `DAT_0044964c` to that buffer plus `0x10`. `0x10` is
exactly the 16-byte `ART.CAR` header (`"CCBA"` magic + file size + cel count + CCB-array-end
offset — document 5's format table). **`DAT_0044964c` is not a copy, a rebuild, or a
filtered table. It is the file's own CCB array, sitting in memory exactly as it was written
to disk**, and the renderer indexes straight into it with the tile's art id.

Putting steps 2 and 3 together: **the art id *is* the `ART.CAR` cel index. There is no
mapping table anywhere in the game.** The level editor and the sprite artist were working
against the same cel numbering from the start; there was never a translation step for this
investigation to reverse-engineer, only to discover wasn't there.

## Verifying it, the usual way — against every real file, not the logic alone

Reading the decompiled C convincingly explains *why* this should work, but per
[document 6](06-verification-philosophy.md) rule 3, a hypothesis about "every real file"
gets checked against every real file, not trusted from the code reading alone:

```python
used_art_ids = {raw_tile_to_art_id(r) for r in range(240)} - {None}   # from tools/rf_tile_art.py
cels = {c["index"]: c for c in art_atlas_json["cels"]}
for art_id in used_art_ids:
    cel = cels[art_id]
    assert cel["kind"] == "sprite" and cel["w"] == 32 and cel["h"] == 32 and cel["pre0"] == 0
```

All 104 art ids the 204 real `.rfm` files actually use land on a real `ART.CAR` sprite cel
at that exact index — zero exceptions, none of them accidentally landing on an effect-mask
cel. Going further: cel indices 0-111 (112 cels) turn out to be one uniform, contiguous
block — every one `32x32`, `PRE0 == 0`, sharing a single `PLUTPtr`, with `SourcePtr` packed
back-to-back at an exact 1024-byte (`32*32`) stride and not one gap. Cel index 112 is the
first break in that pattern (`16x16`, evidently a different sprite category starting). Every
art id any real level uses — the highest observed is 109 — falls safely inside that uniform
block. That block is obviously a deliberately laid-out terrain tileset, not a coincidence,
even though nothing in the code *enforces* a boundary at 112 — the 7-bit art id field could
in principle address up to 127; it simply never does in any of the 204 real files available.

## What this means for the converter

Nothing needed to change. `build/car/art_atlas.json`'s `cels[n]` entry for `n == art_id`
already *is* the mapping, because the function being reverse-engineered turned out to be
the identity function. The Godot terrain renderer (Phase 4, not yet started) can draw
`art_atlas.json.cels[art_grid[i]]` directly for every cell of a level's `.art.bin` — no
lookup table to build, generate, or maintain. This is written up as its own finding,
section 1.7 of `docs/PORTING_PLAN.md`, rather than folded into an existing section, since it
genuinely bridges the `.RFM` (section 1.5) and `ART.CAR` (section 1.6) investigations.

## The lesson worth pulling out

This didn't need the empirical fallback document 7 offered ("look at where each art id
appears and guess from shape") — going straight to the rendering code found an *exact*
answer instead of a plausible one, and turned out to cost less effort than the empirical
route would have, because the two `FindDataXrefs.java` hops chained directly into the
answer with no dead end along the way. **When "trace the real code" and "guess from
statistics" are both on the table, and an anchor for the real code already exists (here, a
data structure inherited from a previous investigation rather than a fresh string search),
try the real code first** — it's not always slower than guessing, and when it works, there's
nothing left to double-check afterward the way a statistical guess would need.

**Next:** [Worked example: the exact tint colour of `ART.CAR`'s effect masks](09-worked-example-effect-tint-colour.md) —
another item off the same backlog, solved the same way.
