# 2. Easy formats first: `.SDT` and `.RFA`

Before reaching for a disassembler, it's worth just looking at the bytes. A lot of
proprietary-looking extensions from 90s games are standard formats with the name changed —
sometimes deliberately (to stop curious players poking at them with the tools they already
have), sometimes just because a build script slapped a project-specific extension on
whatever the export tool produced. Both of Return Fire's simplest formats turned out to be
exactly this, and neither needed Ghidra at all.

## `.SDT` sound files: renamed `.wav`

Opening one of the 40 `SOUND/*.SDT` files in a hex viewer, the first four bytes are
`52 49 46 46` — `RIFF`. That's the standard Windows multimedia container header. Bytes 8-11
say `WAVE`. **These are just `.wav` files with a renamed extension.**

The only thing worth *verifying* rather than assuming is the format tag inside the `fmt `
sub-chunk — RIFF/WAVE can carry all sorts of codecs (ADPCM, MP3, µ-law...), and a 3DO game
being ported to PC could plausibly have carried its original 3DO audio codec (SDX2 ADPCM)
straight through rather than transcoding. So the converter (`tools/convert_sdt.py`) doesn't
just copy bytes — it actually parses the RIFF chunk structure and checks:

```python
def parse_riff(data):
    """Return (fmt_dict, has_data_chunk) for a RIFF/WAVE buffer, or raise."""
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a RIFF/WAVE file")
    ...
    if tag == b"fmt ":
        (tag_fmt, channels, rate, byte_rate, align, bits) = struct.unpack_from(
            "<HHIIHH", data, body
        )
        fmt = {"format_tag": tag_fmt, "channels": channels, "sample_rate": rate, ...}
```

Then in `main()`, every file that *isn't* format tag `0x0001` (uncompressed PCM) gets
flagged instead of silently copied:

```python
if fmt["format_tag"] != 1:
    flagged.append(
        "%s: format tag 0x%04X is not PCM -- needs a decoder" % (name, fmt["format_tag"])
    )
    continue
```

Running it against the real 40 files:

```
python tools/convert_sdt.py "C:\Users\Alex\Documents\returnfire" build/sound

converted 40 .SDT -> .wav in build/sound
formats seen (rate, channels, bits) -> count:
     5563 Hz  1ch   8-bit  x1
    11025 Hz  1ch   8-bit  x37
    11127 Hz  1ch   8-bit  x1
    44100 Hz  2ch  16-bit  x1

no anomalies -- every file was plain PCM
```

Three things worth noticing here, because they generalize:

- **The initial guess (3DO SDX2 ADPCM) was wrong**, and checking caught it in seconds
  instead of shipping a silent-but-corrupt converter. Always check the actual format tag,
  never assume from the platform's history.
- **Not every file is the same.** 37 of 40 are the boring common case (11025 Hz mono
  8-bit), but `AR1.SDT` is 44100 Hz stereo 16-bit, and two files sit at odd non-round sample
  rates (5563 Hz, 11127 Hz — almost certainly a rounding artifact of some original 3DO clock
  divider, not an error). A converter that only ever tested against one "representative"
  file would never have found these. **Always run against every real file, not a sample.**
  (This comes up again, more expensively, in [document 5](05-worked-example-art-car.md).)
- The converter reports what it found rather than just succeeding silently, so an anomaly
  is something you *see*, not something you have to go looking for later.

## `.RFA` art files: renamed `.bmp`, with one real trap

Same story: `ART/*.RFA` files start with `42 4D` — `BM`, the standard Windows BMP magic.
These are plain uncompressed BMPs.

The trap here is subtler than "check the format tag" — it's a trap in how naive BMP readers
get written. A very common (and very wrong) shortcut is to hardcode the pixel data offset
as `1078` bytes, because that's `14` (file header) `+ 40` (info header) `+ 256*4` (a full
256-entry palette) — correct for the *majority* of 8bpp BMPs, and wrong for anything else.
The actual offset is a field in the file, `bfOffBits` at byte 10, and it has to be read, not
assumed:

```python
w, h, indices, palette = read_bmp(data)   # tools/rfpng.py reads bfOffBits, doesn't guess it
```

Running the real converter against all 16 files surfaces exactly why that check matters —
this is not a hypothetical:

| File | W x H | bpp | Palette |
|---|---|---|---|
| `PS480.RFA` | 640 x 480 | 8 | 256 |
| `NEWREQLG.RFA` | 640 x 480 | 8 | **224** |
| `PAUSE16.RFA` | 320 x 240 | **4** | **16** |

Two of the sixteen files break the "always 256, always 8bpp" assumption: `NEWREQLG.RFA` /
`NEWREQSM.RFA` have a trimmed 224-entry palette, and `PAUSE16.RFA` is 4bpp with a 16-entry
palette entirely. A hardcoded `1078` offset would silently corrupt both — not crash, just
quietly read the wrong bytes as pixels and produce a garbled image that might not even look
obviously wrong at a glance.

```
python tools/convert_rfa.py "C:\Users\Alex\Documents\returnfire" build/art

   1PBSCRH.RFA       640 x 176   256 palette entries
   2PBSCRH.RFA       640 x 183   256 palette entries
   ...
   NEWREQLG.RFA      640 x 480   224 palette entries
   PAUSE16.RFA       320 x 240    16 palette entries

converted 16 .RFA -> .png in build/art
```

## The takeaway before moving on to Ghidra

Both of these formats look, at first glance, like they'd need real reverse engineering —
game-specific extensions usually do. Neither did. The lesson isn't "everything is secretly
a standard format" (`.RFM` and `ART.CAR` very much are not, see the next two documents) —
it's **look at the raw bytes and check for a known magic number before assuming you need a
disassembler.** `file`, a hex viewer, or just `data[:4]` in a Python REPL costs nothing and
sometimes finishes the whole job.

**Next:** [The Ghidra workflow — what to do when the bytes *aren't* a standard format](03-ghidra-workflow.md).
