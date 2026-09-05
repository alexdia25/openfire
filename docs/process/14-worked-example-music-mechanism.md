# 14. Worked example: is the music CD audio or a WAV file? (Both.)

This backlog item sat in `docs/PORTING_PLAN.md` since document 1's very first import-list
pass: `RFIRE.BIN` imports `mciSendCommandA` (suggesting Redbook CD audio) and the game's
`SOUND` folder has a 2.8 MB `DRUMS.WAV` (suggesting a local fallback), but nobody had traced
which one the game actually uses for music, or whether it's really either/or. It turned out
to be both — and the obvious guess about which file is the fallback was wrong.

## The anchor: every caller of the CD-audio import

[Document 3](03-ghidra-workflow.md)'s recipe again: find the import, find every place that
calls it, read outward. `mciSendCommandA` is a `WINMM.DLL` import, so its IAT slot address
(found with `FindSymbol.java mci`) is a data address like any other —
`FindDataXrefs.java 0048e804` decompiles every function that calls through it in one pass.
Five functions came back, and reading them together tells the whole story:

- One (`FUN_004051c0`) starts a track — and it's a two-way branch. If an MCI device handle
  global is open, it calls `mciSendCommandA(handle, 0x806 /* MCI_PLAY */, 0xC /* MCI_FROM |
  MCI_TO */, &range)`, reading a from/to frame range out of a small per-track table. If that
  handle is *not* open, it goes down a completely different path instead, into a function
  that doesn't call `mciSendCommandA` at all.
- Two more (`FUN_00405360`, `FUN_004055d0`) stop and close the same handle
  (`0x808`/`MCI_STOP`, `0x804`/`MCI_CLOSE`).
- One (`FUN_00405480`) is a background thread that polls `mciSendCommandA(handle, 0x814
  /* MCI_STATUS */, ...)` every 200ms and advances to the next track when the device reports
  stopped.

That's a completely ordinary MCI `cdaudio` playback loop: open, play a track by frame range,
poll for completion, advance, eventually close. Nothing surprising yet — this confirms
Redbook CD audio is real, but says nothing yet about the WAV fallback.

## Following the branch that *doesn't* call MCI

The interesting part is the other branch of `FUN_004051c0` — what happens when the MCI
handle is 0. It calls `FUN_00403ef0`, and *that* function is where the fallback lives. It
doesn't call `waveOutOpen` or `DirectSoundCreate` — it calls:

```
AVIStreamOpenFromFileA(&stream, filename, 0x73647561 /* 'auds' */, 0, 0, 0)
```

`0x73647561` read as four ASCII bytes (little-endian) is `auds` — the AVI "audio stream" fourCC. This is a
real, documented trick from that era: `AVIStreamOpenFromFileA` isn't limited to `.avi`
containers — Windows ships a WAV file handler for the same AVIFile API, so a game already
using `AVIFIL32`/`MSVFW32` for its cutscenes (section 1.2) can reuse the exact same streaming
API to play a big WAV file without writing a second file-format reader. Once opened this way,
the same per-track table `FUN_004051c0` used as CD frame ranges gets reused as **byte
offsets into that one WAV file** — one table, two backends, chosen by which branch runs.

## Which WAV file, actually — and why the guess was wrong

The filename passed to `AVIStreamOpenFromFileA` is a string sitting right next to the
function that calls it: `DumpStringAt.java` on its address reads `SOUND\Score.WAV`. Not
`DRUMS.WAV` — the backlog item's own wording had assumed the 2.8 MB WAV file sitting in the
`SOUND` folder was the obvious candidate, since it's by far the largest audio file there. It
isn't. Checking directly settled it two ways:

1. The user's actual `SOUND\SCORE.WAV` exists and is exactly the file this code opens — but
   it's a **20-byte stub**, not real audio.
2. `FindBytes.java` (a raw byte-pattern scan across the *entire* binary, not just strings
   Ghidra has already identified) searched for the literal bytes `DRUM` and found **zero
   hits**, anywhere. `RFIRE.BIN` never references that filename by any string. Whatever
   `DRUMS.WAV` is — a cut feature, a leftover from an earlier build, an asset for a tool that
   isn't `RFIRE.BIN` itself — the game does not load it.

That second check is the one that actually closes the question. Without it, "the code opens
some WAV file, and there happens to be a big WAV file in the folder" would have been an easy,
wrong story to settle for.

## What this means for the install the user has

Both music-content files this install could plausibly have used are effectively missing:
`SOUND\Score.WAV` is a real filename the game genuinely opens, but the copy on disk is a
20-byte placeholder, and there's no way to summon Redbook audio from files alone since it
was never meant to live in this directory at all — it's supposed to come off a physical
audio CD. This lines up exactly with [section 1.2](../PORTING_PLAN.md#12-what-rfirebin-binds-to-informs-what-must-be-reimplemented)'s
earlier finding that the `.avi` cutscene files were also stripped from this particular
install: the big, copyrighted media assets are gone, while every small data file
(`.RFM`, `.SDT`, `ART.CAR`) survived. The *mechanism* is now fully understood and portable
regardless; the actual soundtrack audio itself would need to come from the original CD, same
caveat as the cutscenes.

## The lesson

Two things worth carrying forward: first, tracing every caller of an import instead of just
the one you expect is what surfaced the WAV branch at all — a narrower search (just look at
CD-audio calls) would have missed that a completely different playback path exists in the
same function. Second, a large, suggestively-named file sitting in the right folder is a
hypothesis, not a finding — `FindBytes.java`'s zero-hit result on `DRUM` is what turned "the
game probably uses DRUMS.WAV" from a reasonable guess into a settled no.

**Next:** [Worked example: the native resolution, and a tick rate that resists being found](15-worked-example-resolution-and-tick-rate.md) —
one clean win and one honestly-unfinished trace, in the same investigation.
