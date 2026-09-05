# 17. Worked example: reference discs arrive, and a stale guess gets corrected for free

Every worked example so far started from a question and went looking for an answer inside
`RFIRE.BIN`. This one starts from new material showing up — the user handed over two disc
images — and the interesting part is that just *cataloguing* them, with no Ghidra involved
at all, quietly resolved something this project had been carrying as an open guess since
section 1.2: the "missing `.avi` cutscenes."

## What arrived

Two images, both kept outside the repo (`C:\Users\Alex\Documents\returnfire\`, never
committed — see document 3's legal ground rules):

- `RFIRE US.iso` — the retail PC CD.
- `Return-Fire-Maps-O-Death_3DO_EN\*.bin/*.cue` — a 3DO-exclusive expansion pack that was
  never released for PC.

Neither needed a hex editor to identify. `RFIRE US.iso` opens with `CD001` at sector 16 —
the standard ISO9660 primary volume descriptor signature, so it was safe to just mount it
(`Mount-DiskImage` in PowerShell, read-only, no extraction tool needed) and browse it like
any folder. The `.bin`/`.cue` pair's first raw sector, by contrast, has none of that: instead
it has a `ZZZZZ` marker, an ASCII `cd-rom` label, and thousands of repeats of
`duckiamaduckiama...` filling the rest of the sector. That's not noise — it's the
well-documented 3DO disc volume header, and that filler string specifically is a known
quirk of 3DO's own disc-mastering tools padding out unused directory blocks. No filesystem
parsing needed yet to know *what it is*; just enough of a look to confirm it's a genuine 3DO
disc, not some corrupt or mislabeled PC image.

## The PC ISO: cataloguing it directly answered a question nobody was actively chasing

`Get-ChildItem -Recurse` on the mounted drive gives a full file listing for free. Two things
immediately confirm existing findings:

- `Sound\Score.wav` is 222 MB here, versus a 20-byte stub in the installed copy. Exactly
  the file section 1.8 traced the music-fallback mechanism to, just missing its actual
  content in this install.
- `Sound\Drums.wav` is a real 2.8 MB file here too — confirming it does exist as a shipped
  asset, while leaving section 1.8's actual finding (`FindBytes.java` found the string
  `DRUM` nowhere in the binary) untouched. It's real. It's also still unused.

But the interesting one is `Title\*.stm` — six files, the largest 20 MB, that look exactly
like what section 1.2's guess about missing `.avi` cutscenes would predict: big media files,
gone from the stripped-down install, needed for a complete port. Rather than accept that
guess, the recipe from document 6 applies again — **look, don't assume** — so the next step
was reading the first 32-64 bytes of a few of them:

```
twi.stm:      00 10 00 00 00 e8 00 00 22 00 00 00 61 75 64 73 ...
win.stm:      00 10 00 00 00 00 01 00 39 01 00 00 61 75 64 73 ...
rf.stm:       00 10 00 00 00 00 01 00 88 00 00 00 61 75 64 73 ...
prolific.stm: 00 10 00 00 00 00 01 00 2b 00 00 00 61 75 64 73 ...
```

`61 75 64 73` is `auds` — the exact AVIFile audio-stream fourCC (`0x73647561` little-endian)
that section 1.8 already identified as the trick `Score.WAV` is opened with
(`AVIStreamOpenFromFileA` happily accepts a non-AVI container tagged this way). Every `.stm`
file checked has it, at the same offset. **These are not video files.** The whole "missing
cutscene video" question dissolves — there was never a cutscene format to find, because
there's no cutscene video in this game at all. `.stm` is just another name for the same
audio-streaming container, almost certainly extra music (a "win" theme with three variants,
a "twilight" track, the publisher jingle).

This is the same shape of correction as [document 13](13-worked-example-reticle-not-swatch.md)
(a plausible-sounding guess, retracted by actually looking) and
[document 16](16-worked-example-3d-projection.md) (a whole question dissolving because its
premise was wrong) — except this time the "look" was a file header, not a render, and it
cost nothing: the reference material had to be catalogued anyway.

## The 3DO expansion: identified, not yet opened

`Return Fire: Maps o' Death` is a different project shape entirely — not an open question
with a lead, but a new goal (`docs/PORTING_PLAN.md` section 0 and section 1.11). The 3DO
used its own filesystem (not ISO9660) and its own native asset formats, and this expansion
predates the PC port, so its map format is almost certainly not `.RFM`. Section 1.6 already
leaned on `trapexit/3doplay` once (to confirm the `CCB_BGND` flag), and it's the obvious
place to check again before writing a 3DO filesystem/CEL reader from scratch — no need to
re-derive public disc-format knowledge that's already been reverse engineered by that
project.

Nothing has been extracted from it yet. It's recorded in the backlog (plan section 4, item
7) with a concrete next step — get or write a 3DO CD-ROM filesystem reader and enumerate
its real files — rather than chased further in this pass.

## The lesson

Not every finding starts with "form a hypothesis, then go check it against `RFIRE.BIN`."
Sometimes new source material just arrives, and the discipline that matters is the same one
document 6 already named: when you have the real file in front of you, look at it before
trusting whatever guess is already written down. A "missing `.avi` cutscenes" line had been
sitting in the plan since very early in this project; it took under five minutes of header
inspection to find out it was never true.

**Next:** whichever of plan section 4's open items gets picked up next — including, now,
the 3DO expansion (item 7) as a real option rather than a hypothetical future goal.
