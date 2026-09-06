# 31. Worked example: chasing a rotation-mirroring bug found a whole vehicle roster

A user observation about Phase 3's billboard vehicle ("it looks like the tank is ALWAYS
facing the same way, no matter what") led to a precise diagnosis — and then, while
re-attempting the long-abandoned trace of the original's real per-heading facing table, into
a much bigger discovery: the original game has at least four distinct vehicle types, not the
one this project has built against for its entire history.

## The rotation bug, precisely diagnosed

Checking the actual pack data confirmed the user's read: only **9 real images per team**
exist, covering one 90-degree quarter-turn. The other 270 degrees come from flipping those
same 9 images. Comparing heading 0 and heading 180 directly showed why this reads as "never
turns": `_frame_for_heading()`'s quadrant math always folds a heading down to the same base
frame index and only ever flips it — and the base frame happens to be left-right symmetric,
so flipping it changes nothing. Turning the vehicle a full 180 degrees, to face the exact
opposite direction, produces a pixel-identical image. No mirror scheme built from a single
90-degree arc of source art can fix this; flipping a symmetric image can't make it
asymmetric. Real front/back-distinct art is the only real fix.

## Re-opening the facing-table trace

An earlier session's attempt to find the original's real per-heading facing table (`FUN_
0042dd90`/`FUN_0042d640`) had stalled: it found the *mechanism* but never located real table
content, and a `.data` scan for a fixed record layout found nothing. Re-reading `FUN_0042dd90`
in full this time explained why: the table is addressed through a **per-object-type data
pointer**, not a flat array anywhere in `.data` — exactly the kind of thing a fixed-address
scan can't find. The heading resolution itself also turned out finer than assumed: a full
256-step facing byte, matched against `[start, end] -> base cel index` records with the cel
index increasing linearly across the range.

One dead lead got ruled out cleanly: `.RFM`'s `vehicle_params` block is only 6 bytes, far too
small to be this per-object-type structure. One false lead got caught before it wasted more
time: a reported "caller" of the facing-table function turned out, on raw disassembly
inspection, to be a `REP MOVSD` (a memory copy) that Ghidra's reference database had
mis-tagged as a call — worth remembering that a caller list is only as good as the
instruction it points at, and checking the actual bytes when something looks structurally odd
is cheap insurance against building on a wrong xref.

Tracing the *real* callers (a literal-address xref search, not a call-instruction search,
since the function's address turned out to be a virtual-method slot in a shared 11-entry
object vtable) led to `PTR_FUN_0044bb40` — the same vtable `FUN_0042d640`, a generic
"construct a CCB-rendered object from a byte-record" constructor, copies into every object it
spawns.

## The vehicle roster: real names, in the binary's own data

Dumping the `.data` region around that vtable as raw dwords surfaced a string: `"ART/EM1.RFA"`
followed immediately by a run of short strings — `MSV`, `JEEP`, `Tank`, `Vehicle`, `Destroyed
Vehicle`. A second, separate table nearby held sound-cue names: `HELI Death`, `Heli 1`, `Heli
2`, `MSV Death`, `MSV 1`, `Jeep Death`, `Jeep 1`, `Tank Death`, `Tank 1`, `Tank 2`, `Tank 3` —
alongside non-vehicle cues (`Drums`, `Sub`, `Bunker`, `Win`, `Flag Pickup`, `Flag Discovery`),
consistent with a debug sound-test/level-editor menu rather than anything player-facing.

This directly resolves an old, previously-unchased note in the plan: *"no confirmed
helicopter sprite exists in the registry despite that being Return Fire's best-known
vehicle."* It exists — this project just never had the name `HELI` to search for. The game's
real vehicle roster is at least **Tank, Jeep, MSV, and Helicopter** — this project has only
ever built the Tank (misnamed "hovercraft" throughout, on nothing but a visual guess).

`ART/EM1.RFA` itself doesn't exist in the installed game (checked directly) — likely a
dev-only asset path that never shipped, or renamed before release.

## Finding the icons, by looking for the one shape that couldn't hide

Four vehicle types should mean four sets of rotation art somewhere in `ART.CAR`. A quick check
of the obvious suspects — cel families already in the registry with vague names
(`vehicle.cart`, `vehicle.jetski`, `vehicle.hovercraft.hull`, `vehicle.mobile_gun`) — turned
up nothing: `jetski` is a water-wake spray effect, `cart` and `mobile_gun` are tank
tread/turret detail pieces, `hull` is more tank body art. All of it already belongs to the one
vehicle this project has.

A helicopter's rotor blades are visually distinctive even at small scale — long and thin — so
a cheap geometric search (every cel's width/height ratio, no image-viewing needed) for
extreme aspect ratios surfaced a short list of candidates. Most were unrelated (dashed lines,
wire props, pipes) but one, right next to a run of cels already labelled `ui.icon.vehicle_
mini.NN` (a bulk-pass placeholder name nobody had gone back to look at closely), led straight
to it: a full mini-map/radar icon set showing a tank, a jeep, a wheeled vehicle, and a
helicopter with unmistakable rotor blades, each in tan and green team colours.

Registry corrected for the five unambiguous icons (`ui.icon.tank_mini.*`, `ui.icon.jeep_
mini.*`, `ui.icon.heli_mini`) at `visual` confidence, plus four more from a second wheeled/
rounded silhouette family at `visual_group` confidence — real vehicle icons, honestly not
identified further than that (which one is literally "MSV" versus some other unit/marker
isn't resolved yet).

## What this doesn't solve, on purpose

These are 128x31-to-64x64-scale **map icons** — small, stylized, single-pose silhouettes —
not the 32x32 rotation cels `vehicle.gd` actually renders at gameplay scale. Finding these
confirms the roster and gives a visual reference for what to look for, but the real,
in-game, per-heading rotation art for Jeep/MSV/Heli (if it survives anywhere in `ART.CAR`)
has not been located. That's a separate, still-open search — this document records what's
confirmed, not a finished one.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
