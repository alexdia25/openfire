# 24. Worked example: a debug string, a dedicated object, and a capture-the-flag lead

Every anchor so far in this project has come from inside the investigation itself — a string
already spotted while cataloguing a format, a data structure already known to be nearby. This
one starts differently: **the user, who owns and has played the original, said the real win
condition is returning an enemy flag to your own base**, plus a separate life system, right
after [document 23](23-worked-example-enemy-ai-first-pass.md) closed with "nothing declares a
match-won/lost state" still open. That's a different kind of lead than this project usually
works from — domain knowledge instead of a byte pattern — and it's worth recording how it gets
turned into the same kind of evidence everything else here rests on, rather than just taken on
faith.

## Anchor: not a byte pattern this time, a claim to go verify

The obvious first move, consistent with document 3's recipe, is still "find an anchor" — it
just starts from a word instead of a known data structure. `FindSymbol.java flag` (a
case-insensitive substring search over every symbol Ghidra's auto-analysis found) turned up
exactly one real hit: `s_Flag_in_first_building:_%s_00442a84`. That's not a comment or a
made-up label — it's a literal ASCII string still sitting in the shipped `RFIRE.BIN`, reading
"Flag in first building: %s". Two other searches in the same batch (`life`, `capture`) came
back empty via symbol search; a follow-up raw byte scan (`FindBytes.java`, which finds text
Ghidra's own string detection missed — the same tool that found the `.RFM` chunk tags in
section 1.5) for literal `"Life"`, `"Lives"`, and `"LIVES"` also came back with **zero hits**
anywhere in the whole binary. One claim got an anchor immediately; the other didn't, and that
asymmetry is itself useful information, not a dead end — see the last section.

## Following the string to a shipped, hidden developer menu

`FindDataXrefs.java 00442a84` found the string used from exactly one function, `FUN_004065c0`,
called from two nearby addresses in the same function. Decompiling it revealed something this
project hadn't seen before: a **generic debug-menu renderer**, still compiled into the retail
binary, driving several hidden screens through a shared "menu item" struct (36 bytes, a stride
`pcVar7 = pcVar7 + 0x24` makes obvious once you're looking for it) with fields for a label
string, an up/down/left/right navigation byte array, an optional "link to another screen"
function pointer, and an optional "live value" pointer. A wider raw dump of the surrounding
memory (`DumpStringAt.java`, 1600 bytes from `0x00442800`) turned up the whole menu's text at
once: `EXIT`, `Display FPS: %s`, `Flag in first building: %s`, `On `/`Off`, `AUDIO SCREEN`, and
-- a separate screen entirely -- audio-debug strings (`Stop Sounds`, `SFX Info`, `Freq: %6d`)
and object-pool stats (`Objects: Free %3d, Active %3d, Inactive %3d, Useless %3d`). None of
this ships visibly in a normal game session; it's a developer's own diagnostic overlay, left
in because nothing strips debug menus from a 1996 shipping build the way it might today.

Parsing the actual 4-record table at `0x00442b38` byte-for-byte (dumping it raw and unpacking
it as little-endian dwords rather than trusting the decompiler's variable names, the same
"read the real bytes" instinct document 12 used for the `.RFM` header) placed "Flag in first
building" as record index 1, with its "live value" pointer at `0x00442b00`.

## The payoff: this reads the exact same global the project already reimplemented

Running `FindDataXrefs.java 00442b00` is the moment this stopped being a curiosity and became
directly relevant to Phase 4 step 5. It's read from exactly one gameplay function:
**`FUN_00432710`** — the *same* function [section 1.5](../PORTING_PLAN.md) already fully
traced as the candidate-pool destruction handler, the one `game/target_pool.gd`'s `TargetPool`
(document 22) already reimplements move-for-move. Its logic reads `DAT_00442b00` *before*
decrementing a pool's replacement budget, and uses the result to decide whether destroying the
active target falls through into `TargetPool`'s ordinary "replace it" behaviour, or into a
different branch entirely: spawning an object via a 6-field descriptor at `0x0044e3c0` that
**has exactly one cross-reference in the entire binary** — this call site, and nowhere else.
A generic effect (an explosion, a puff of smoke) would be spawned from dozens of places, the
way [document 21](21-worked-example-vehicle-mirroring-bug.md)'s `FUN_0042c4d0` turned out to
be called from 35+ sites. A single, dedicated caller is exactly what "this object is the
flag" would look like.

Decompiling that object's two callback function pointers filled in the picture further:
one (`FUN_004328f0`) just deregisters the object from a per-team tracking array shared with
this project's earlier target-lock/reticle work (section 4 item 5's lead); the other
(`FUN_00432920`) is a genuine per-frame *homing* update, steering the object along a heading
computed through the same cosine/sine lookup tables [document 16](16-worked-example-3d-projection.md)
found driving vehicle movement, and flips a global status bit when the object's own team index
disagrees with something else's. A static prop doesn't home toward a target and flag a
team mismatch when it changes hands; something being carried does.

## Checking the art honestly, and catching a real mislabel while doing it

`packs/registry/asset_ids.json` already had `marker.capture_flag.01`-`.16`, noted since
[document 19](19-worked-example-asset-registry.md) only as "red flag on a pole... possible
capture-point marker" — a lead nobody had reason to chase further until now. Rendering it
fresh (document 6's rule 1, again) rather than trusting the old note showed two things at
once: it's **two team-coloured animations**, not one generic marker (13 frames orange/red,
7 green) — upgrading "possible" to a real, specific finding — and **4 of the frames weren't in
that classification at all**. Cels 1841-1844 had been swept into a completely unrelated
family, `decoration.terrain_patch_blue` ("irregular map-shaped blob, light blue/ice-like"), by
the original bulk-classification pass. Rendered side by side with their actual neighbours, the
mistake is obvious — a flag-on-a-pole silhouette next to an ice-blue blob looks nothing alike —
but a contact sheet skimmed quickly during a 2165-cel classification effort is exactly the kind
of pass that can wave two genuinely different shapes past without either one screaming
"wrong," similar in spirit to (though a much smaller mistake than) document 20's palette bug
surviving an entire classification pass because nothing about the wrong output looked broken
on its own. Fixed in `tools/registry/classify_bulk.py`'s established correction-block pattern
(append a fix, don't rewrite history) rather than editing the original `seq()` call.

## What this does and doesn't prove

Read together honestly: destroying a pool's active building normally just triggers the
already-implemented replacement bookkeeping — *unless* a flag-related condition holds, in
which case a unique, homing, team-aware object gets spawned instead of a replacement. That
lines up with "the flag drops out of a destroyed building, and something can then carry it"
closely enough to take seriously, and it directly explains why "Flag in first building" is a
sentence that makes sense as a debug readout: buildings are exactly where section 1.5's
candidate pools already live, and this is now the second piece of gameplay (after target
replacement itself) that reads that mechanism's state.

It does **not** yet prove a win condition. Nothing traced so far shows where `DAT_00442b00`
gets *set* (only where it's read), what marks a vehicle as "carrying" the flag, where a "home
base" position lives, or any code that declares a match won or lost. `FUN_0042c4d0` is still
ruled out as that trigger, unchanged from document 21 — this is a different, better-supported
trail, not a replacement finding for that same dead end. The honest state, matching this
project's own standing rule about not asserting more than what's been traced: a strong,
multi-source lead, not a closed case.

## The life system: an anchor that isn't there yet

The user's second claim — a life system — got the opposite result from the same kind of check.
Zero symbol matches, zero raw byte matches, for "Life," "Lives," or "LIVES" anywhere in the
binary. That's a real, useful negative result, not a failed search: it means this project's
usual first move (anchor on a string) has nothing to grab here, so confirming a life system
needs a colder start — most plausibly tracing what happens when a vehicle's own destruction/
health state hits zero, from the *vehicle* side rather than the *building* side this document
worked from, since the registry's `ui.icon.vehicle_mini.01`-`.20` (already tagged "likely
minimap/HUD unit marker") are a plausible but entirely unconfirmed candidate for a text-free,
icon-only lives readout. Recorded as a distinct open item rather than folded into the flag
lead just because a user mentioned them in the same sentence — they may or may not turn out to
be related mechanically, and nothing found this session says either way.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog. Phase 4 step 7
(mission objectives/scoring/level progression) is still blocked on closing this loop; the two
concrete next hops are finding what sets `DAT_00442b00` and finding an anchor for the life
system.
