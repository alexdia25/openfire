# 12. Worked example: decoding the `.RFM` header body with no Ghidra at all

Every worked example so far started with an anchor in the code and worked outward through
decompiled C. This one didn't touch Ghidra once. [Document 7](07-next-steps.md) itself
suggested exactly this approach for this specific item — "pick one unidentified offset, and
try correlating its value against something observable... across all 204 files" — and it
turned out to be enough on its own.

## The starting point

[Document 4](04-worked-example-rfm-format.md) mapped the `.RFM` container format in detail
but left offsets `0x04`-`0x3F` mostly as an unlabeled block — known fields (width, height,
the mode byte) picked out, everything else marked "undecoded." A loose thread from that same
investigation sat unresolved even longer: an early draft had noticed a string sitting around
offset `0x18`, before `NAME` was known to be the real display-name source, and never came
back to check what that other string actually was.

## The method: read the bytes, not the code

With 204 real files sitting on disk, the cheapest possible question to ask is "which bytes
in the header actually change from file to file, and which never do?" That doesn't need a
disassembler:

```python
for off in range(0x50):
    vals = collections.Counter(header[off] for header in all_204_headers)
    if len(vals) > 1:
        print(off, vals.most_common(5))
```

The result sorted the entire unexplored region into three groups instantly: bytes `0x04`-
`0x0D` and `0x26`-`0x3F` never vary at all (constant across every file); bytes `0x0E`-`0x15`
vary *a lot* — 57 to 134 distinct values across 204 files, near-unique per file; and bytes
`0x17`-`0x25` have a much smaller, much more human-looking set of values, and several of
those values print as readable ASCII.

## Two real fields, read straight off that shape

**The ASCII-looking bytes were the level author's name.** Decoding `0x17`-`0x25` as a
null-padded string and printing the distinct values across all 204 files:

```
71  'Unknown'
67  'v'
34  'MichaelAngelo'
 8  'John'
 4  'Van'
 2  'James'
 2  'Reichart'
 2  'Michael Klug'
 1  'Rasputin(tm)'
 1  'William Ware'
 1  'The Baron'
    ...
```

Real names, several capitalization variants of the same person (`MichaelAngelo`, `michael`,
`Michael Angelo`, ` MICHAEL ANGELO`), a common one-letter signature (`v`, not an anomaly —
just a short version of the same kind of credit), and a default placeholder (`"Unknown"`,
71 of 204 files) for whoever didn't fill it in. This is the *actual credited level designers*
from Silent Software's 1996 team, still sitting in the shipped game data thirty years later.
It's also, precisely, the thread document 4 left dangling: this field starts at `0x17`, not
`0x18`, is exactly 15 bytes wide, and has nothing to do with the `NAME` chunk (that's the
level's *displayed* title; this is *who built it*, never shown to the player as far as this
investigation found).

**The near-unique bytes were a timestamp pair.** High per-file variance with no obvious
pattern is exactly what a real, distinct-per-file value looks like — and 1996-era Windows
tools commonly stamp files with the classic MS-DOS packed date/time format (2 bytes date, 2
bytes time, the same encoding `_dos_getftime` and FAT directory entries use). Trying that
decoding on `0x0E`/`0x10` (proposed "created") and `0x12`/`0x14` (proposed "modified") and
checking every single one of the 204 real files for a sane result — valid month, valid day,
year in a plausible range for a game that shipped in 1996 — came back with **zero
failures**. Real decoded examples:

```
RFMAP001.RFM: created 1995-07-21 11:07:00   modified 1995-10-30 17:11:36
RFMAP002.RFM: created 1995-09-14 17:23:34   modified 1996-02-17 11:29:08
```

Every single date falls between mid-1995 and early 1996 — consistent with `RFIRE.BIN`'s own
known link date of 1996-04-08 (section 1.1). That kind of clean, 100%-consistent result
across every real file, with no exceptions to explain away, is exactly the standard
[document 6](06-verification-philosophy.md) asks for before trusting a decode.

## What didn't decode, and why that's fine

Two small regions are confirmed *constant* across all 204 real files — `0x04`-`0x07`
(`"TM\0\x05"`) and `0x0C`-`0x0D` (`01 01`) — but constant isn't the same as understood. A
value that never varies across the available data can't be correlated against anything, so
there's nothing left to empirically test; confirming they're fixed is as far as this method
goes, and going further would need the actual loader code (or another data source, like an
original level-editor binary, that this project doesn't have). Recorded honestly as "known
constant, meaning unconfirmed" rather than guessed at.

## The converter update

Both real fields were added to `tools/convert_rfm.py`'s output — `author`, `created`, and
`modified` now appear in every level's `.json` — and the converter was re-run against all
204 real files afterward to confirm nothing broke (`204 / 204, no failures`, then a spot
check that a real file's decoded fields matched what the standalone analysis found).

## The lesson

Not every question needs Ghidra. When the data itself is available in bulk (204 real files,
not one), asking "what varies, and how" is sometimes enough to identify a field outright —
timestamps and short text fields in particular tend to have a very recognizable *shape*
(a human-name character set, a plausible date range) that gives them away without reading a
single line of the loader that wrote them. Reach for the disassembler when the meaning is
opaque from the bytes alone; reach for a histogram first when it might not be.

**Next:** [Worked example: catching a wrong guess by finally rendering it](13-worked-example-reticle-not-swatch.md) —
back to `ART.CAR`, this time retracting a guess instead of decoding a new field.
