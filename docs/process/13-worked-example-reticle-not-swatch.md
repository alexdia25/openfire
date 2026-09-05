# 13. Worked example: catching a wrong guess by finally rendering it

This one doesn't solve anything new — it *un-solves* a guess from [document 9](09-worked-example-effect-tint-colour.md)
that had sat unquestioned in `docs/PORTING_PLAN.md` for a few commits. It's here because
that's exactly the kind of finding [document 6](06-verification-philosophy.md) says is worth
recording as honestly as a clean win.

## The guess that needed checking

Document 9 found that 4 of `ART.CAR`'s cels (`PRE0==17`) aren't background-blend masks at
all — they're ordinary sprites with their own embedded palette, rendered through
`FUN_00419ea0`'s plain `dest = OwnPLUT[mask_value]` lookup. At the time, nobody had actually
looked at what those 4 cels *render as*. The byte data alone — a `CCB` with its own PLUT
pointer, structurally a normal sprite — doesn't tell you what's drawn. Lacking any better
idea, document 9 guessed: 4 cels, each a block of a few highly saturated colours, "visually
more like a colour swatch than in-world art" — and filed that as a plausible, unconfirmed
lead for how the game's two teams get their colours.

That guess made it into `docs/PORTING_PLAN.md` section 1.6 *and* section 4's backlog,
worded carefully as "unconfirmed" — but still sitting there as the best available lead,
which is exactly the kind of thing that quietly hardens into assumed fact if nobody comes
back to check it.

## Actually rendering them

Picking the team-colouring backlog item back up, the obvious first move — before writing any
new Ghidra trace — was to finally look at the thing the whole lead rested on. The `.rf_effect_cel`
extraction path (document 9) already exports these 4 cels as ordinary sprites into
`build/car/art_atlas.json`; a quick lookup found their cel indices (1969-1972) and atlas
coordinates, and a crop-and-6x-nearest-scale of that region was enough:

Four 16x16 cels, each a **concentric-ring bullseye** — a purple outer ring, a black ring, a
yellow ring, and an innermost ring or dot in a colour that differs cel-to-cel (red, blue,
purple-red, blue-black). That is not a colour swatch by any reasonable reading. It's a
target-lock reticle — the kind of pulsing ring HUD element a game with guided weapons draws
over whatever it's tracking, cycling through a short handful of frames as the lock builds.
Once seen, it's obvious; it was not obvious from the raw bytes, and it was not obvious from
the code, which only tells you *how* a cel is blitted, never *what it looks like*.

## Confirming there's no easy follow-up trail

Before closing the loop, it's worth checking whether the actual reticle-cycling code is easy
to find. `FindConstant.java` (a full-binary scan for a literal scalar operand) came back with
zero hits for cel index `1969`/`0x7B1` and for the equivalent CCB array byte offset
(`1969 * 0x44 = 0x20AC4`) — nobody in the binary references any of these 4 cels by a
hardcoded immediate. That's a negative result, but an informative one: it means whatever
picks one of the 4 rings per frame does it with a *computed* index (almost certainly an
animation-frame counter added to a base cel id), not four separate call sites — so there's
no quick "find the one call site" shortcut here the way there was for, say,
[document 8](08-worked-example-art-id-mapping.md)'s art-id mapping.

## What this changes

- The team-colouring "lead" from document 9 is retracted. `docs/PORTING_PLAN.md` sections
  1.6 and 4 both now say so explicitly, rather than silently dropping the old wording — per
  [document 10](10-worked-example-target-respawn.md)'s postscript, a disproven lead gets
  written down as disproven, not deleted.
- Team colouring itself goes back to fully open, with no lead at all right now. The
  `GetNearestPaletteIndex` translation-table infrastructure (document 9) is still a
  *plausible mechanism* in the abstract — nothing rules it out — but there's no evidence tying
  it to team colouring specifically anymore. The next real attempt at this needs a fresh
  anchor: most likely starting from wherever a vehicle's `CCB` gets queued for the frame
  (`FUN_0042dd90` was decompiled while looking for this and turned out to be a
  heading-angle-based *directional sprite frame* selector — a real and separate finding,
  itself indexing the same `ART.CAR` CCB array, but its trace never reached a team/owner
  field, so it's not that either).
- The converter behavior doesn't change at all — `tools/convert_car.py` already extracts
  these 4 cels as ordinary sprites (the correct thing structurally, regardless of what they
  depict), so nothing here required a code fix, only a documentation correction.

## The lesson

Document 6 already stated the rule ("render it and look" beats trusting statistics or code
alone) — this is what it costs to actually skip that step even once. The guess wasn't
unreasonable given what was on hand at the time, and it was honestly labeled "unconfirmed"
the whole time it sat in the plan doc — but it still took an actual render, sitting right
there in already-generated converter output, to catch it. The fix cost nothing: no new
Ghidra call, just a `PIL.Image.crop` on a file the project had already produced. The lesson
isn't "always render everything before writing anything down" — it's "an *unconfirmed* label
is not a substitute for actually confirming it the first chance that's cheap to take."

**Next:** [Worked example: is the music CD audio or a WAV file? (Both.)](14-worked-example-music-mechanism.md) —
a cleaner win, and a second guess (this time about a *filename*) that turns out wrong too.
