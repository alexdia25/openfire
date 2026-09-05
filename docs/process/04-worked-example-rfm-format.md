# 4. Worked example: the `.RFM` map format

This document runs the [recipe from document 3](03-ghidra-workflow.md) in full, on a real
format, with real commands and real output. The full, current-truth writeup of everything
this investigation found lives in `docs/PORTING_PLAN.md` section 1.5 — this document is the
*story* of getting there, condensed but not sanitized.

**Starting point:** 204 `.RFM` level files under `WORLDS/{1PLAYER,2PLAYER}/LEVEL*/`, in
exactly two sizes — 154 files at 16,756 bytes, 50 at 16,772 bytes. Sixteen bytes apart, no
obvious reason why. That size split is the whole investigation's first real question.

## Step 1 — Find the loader

Anchor string: the loader has to build a path to find level files somehow. `FindRfmStrings.java`
turned up `%sWorlds\%s\%s\*.rfm` in the binary's data segment, referenced from one function.
Decompiling outward from there (`DecompileOne.java`) eventually leads to `FUN_00414130` —
the real level loader, several hundred lines of decompiled C once fully unrolled.

## Step 2 — Read it, and discard the "fixed header" assumption

Before this, the working theory (from pure byte inspection) was that `.RFM` had some kind
of fixed-size header, and the 16-byte size difference between the two file classes meant
two header *versions*. Reading the actual loader threw that out immediately: it doesn't
read a struct, it walks a **named-chunk container** — a sequence of `[4-byte tag][4-byte
length][payload]` records, starting at offset `0x50` and continuing until a length field
(read from offset `0x48` in the file) says to stop:

```
offset 0x00        "WRL\0"     4-byte magic
offset 0x04..0x3F  ...         header fields (width/height/mode byte, mostly still undecoded)
offset 0x40        u8          "enabled" flag -- loader rejects the file if this is zero
offset 0x44        u32 LE      byte length of the tile-grid region
offset 0x48        u32 LE      byte offset where the chunk table ends / tile grid begins
offset 0x50 ..      chunk table: [tag(4)][total_record_len(4)][payload...], repeating
(0x48 value)        tile grid, width*height bytes, row-major, to end of file
```

That reframes the size-class question entirely: the "16 extra bytes" was never a header
version, it's just **however many chunks happen to be present**, which can differ per file.
The loader confirmed four chunk tags: `NAME` (display name), `LEVL` (a small per-level
value), `VHCL` (six vehicle-tuning parameters), `EDTN` (an undecoded 4-byte value present in
every file). One of those — `VHCL` — is optional.

**The hypothesis, stated precisely: the size-class split is exactly whether a file has a
`VHCL` chunk or not.** That's checkable against every real file, not just plausible-sounding
— so it got checked, by writing the converter (`tools/convert_rfm.py`) and running it
against all 204:

```
converted 204 / 204 files
file sizes seen: {16756: 154, 16772: 50}
```

Cross-referencing which files had a `VHCL` chunk against which files were 16,772 bytes:
**exact match, zero exceptions, both directions.** All 50 `VHCL`-bearing files are 16,772
bytes; all 154 without one are 16,756. That's not "consistent with" the hypothesis — with
204 independent data points and zero exceptions, that's about as close to proof as this
kind of reverse engineering gets.

## Step 3 — The spawn point mystery: no dedicated chunk exists

Return Fire levels have player spawn points and destructible-target placements. None of the
four chunk tags obviously encode positions. Where are they?

The answer came from a byte-histogram scan of the tile grid itself across all 204 files —
counting occurrences of each of the 240 possible tile byte values, file by file, and looking
for values with a suspicious, structured occurrence pattern rather than the smooth
distribution you'd expect from ordinary terrain:

| Tile value | Occurrences across 204 files | Only in 2-player levels? |
|---|---|---|
| `0x39` | **exactly 1, every single file** | no |
| `0x4D` | 0 or 1 (1 in exactly the 104 2-player files) | yes |
| `0xB4` | 0-56 | yes |
| `0xDC` | 1-160 | no |

A tile value that occurs *exactly once in every file with no exceptions* is not ordinary
terrain — terrain doesn't self-regulate its own count like that. `0x39` occurring exactly
once per file screamed "the player 1 spawn point," and the pattern for the other three
followed the same logic (a second spawn point that only exists when there's a second
player; two "candidate" pools of varying size that don't look like fixed terrain at all).

Confirming *how* these get consumed meant going back to the loader and following the tile
lookup table (`0x00448450` in `RFIRE.BIN`) for exactly those four values, which pointed at a
2-entry function-pointer dispatch table. The two target functions were only reachable
through an indirect call, so static analysis hadn't recognized them as functions at all —
`ForceDecompile.java` handles exactly this case (disassemble, force-create the function,
then decompile):

```powershell
-postScript ForceDecompile.java 00413e00
-postScript ForceDecompile.java 00413db0
```

`FUN_00413e00(tile_ptr, team_index, pixel_x, pixel_y)` writes into a small per-team
spawn-position table. `FUN_00413db0(tile_ptr, pool_index)` appends to one of two growable
candidate-position pools, and later, once the whole grid has loaded, the main loader picks
**exactly one entry per pool at random** via the C runtime's `rand()`. That's the real
mechanism behind a genuine Return Fire gameplay feature: the target/base location differs
between plays of the same level, because the level file defines a *pool* of valid positions
and the engine commits to one at random each match — not because of anything random in the
file itself.

## Step 4 — The coastline mystery, and a wrong assumption caught before it shipped

240 possible tile byte values, most of which are plain terrain, get resolved through the
`0x00448450` lookup table into a runtime rendering value. One field in that table,
nonzero for the raw byte range `0xC8`-`0xEF`, called a function (`FUN_0042e4f0`) that the
working assumption — reasonably, by analogy with how coastline autotiling usually works —
labeled "probably neighbor-aware autotiling" and left undecompiled for a later pass.

Decompiling it fully turned out to contradict that assumption directly. The function is
called from the main loader with its "neighbor" argument **hardcoded to a literal `0`**:

```c
FUN_0042e4f0((uint)(byte)(&DAT_00448451)[iVar7], puVar16, 0,
             (uint)(byte)(&DAT_00448452)[iVar7]);
//                                       ^ always 0 -- there is no neighbor being read here
```

**There is no runtime autotiling at all.** The function is a *second* static lookup table
(56-byte stride, 91 entries, at `0x00447038`), dumped the same way:

```powershell
-postScript DumpStringAt.java 00447038 5152
```

and parsed in Python to pull out the fields that matter (a validity pointer, a "mode" flag,
and the byte that becomes the tile's real rendered art id):

```python
for i in range(1, 92):
    off = i * 0x38
    rec = coastal_bytes[off:off + 0x38]
    valid, mode = struct.unpack_from("<ii", rec, 0)
    base_art = rec[8]
```

**The level editor bakes the correct coastline-edge shape directly into the raw tile byte
when the file is saved.** There's no per-match, per-neighbor computation to reverse
engineer at all — the whole raw-byte-to-rendered-art-id mapping is a pure function of the
byte itself, implemented in full as `tools/rf_tile_art.py`.

That function was verified the way every hypothesis in this project gets verified — against
every real file, not a sample:

```
104 distinct art ids across 182 mapped raw values
58 unused/reserved raw slots: [51, 56, 58, 59, ...]

supposedly-unused raw values that DO appear in real data: []
distinct art ids actually used in real data: 104  (unmapped/None cell count: 0)
```

Zero of the "unused" raw values ever appear in any of the 204 real files, zero grid cells
across every file fail to resolve to an art id, and the number of distinct art ids the
lookup *predicts* (104) exactly matches the number *actually used*. That triple match —
not just "the converter didn't crash," but three independent numbers agreeing exactly — is
what makes this a verified finding rather than a plausible-looking one. (Compare this to
what happens when that standard isn't held, in [document 5](05-worked-example-art-car.md).)

## Step 5 — Ship the converter, and look at the output, not just the numbers

`tools/convert_rfm.py` parses the chunk table, resolves every tile byte through both lookup
tables, and emits per level: `<name>.json` (metadata + spawn points + candidate pools),
`<name>.tiles.bin` (raw grid), `<name>.art.bin` (the resolved art-id grid), and a debug PNG
— a false-colour render of the art-id grid with spawn points marked in red/yellow and
candidate positions in magenta/cyan.

Run it yourself against your own copy of the game and look at the renders:

```
python tools/convert_rfm.py "C:\Users\Alex\Documents\returnfire" build/rfm

converted 204 / 204 files
spawn points found: team0=204 team1=104
candidate positions found: pool_a=641 pool_b=1560
file sizes seen: {16756: 154, 16772: 50}
```

Two of those renders are worth specifically looking for once you generate them:
`RFMAP001.debug.png` ("The Cakewalk") shows a single coherent landmass silhouette with one
red spawn dot correctly sitting on land — confirming the art-id grouping lines up with real
terrain structure, not noise. `RFMAP046.debug.png` ("Campgrounds Of America") shows 160
cyan candidate markers arranged in a **perfectly uniform grid** — which is exactly what a
campground's numbered camping spots should look like, and was the single most convincing
piece of evidence in this whole investigation that the extraction was reading real level
design, not an artifact of the decoder. A uniform, structured shape appearing in a
statistics-only investigation is a strong positive signal; noise is what a wrong decoder
tends to produce instead (again — see document 5).

**Next:** [Worked example: `ART.CAR` and a wrong turn](05-worked-example-art-car.md), where
that same standard — verify by rendering, not by statistics — is the thing that caught a
mistake instead of confirming a success.
