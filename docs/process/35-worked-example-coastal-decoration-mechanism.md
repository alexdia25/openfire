# 35. Worked example: the coastline-blend id is also the decoration-spawn id

[Document 34](34-worked-example-decoration-not-tile-art.md) established that trees can't be
flat tile art -- the terrain blitter masks every tile's art id to 7 bits, and the real tree
cels in `ART.CAR` are numbered above that ceiling. It left one question open: if not the tile
grid, what *does* place a tree? Continuing the same thread (per user direction -- authentic
asset placement matters to this project) traced the answer all the way to a confirmed
mechanism, by decompiling three more functions this project hadn't looked at before.

## Re-reading the level loader's fill loop, more carefully this time

`FUN_00414130` (the real `.RFM` level loader, already known from section 1.5) resolves each
tile's on-disk byte into an art id via the same 240-entry primary table this project's own
`tools/rf_tile_art.py` reproduces. That part was already understood. What hadn't been
connected: when a tile has a nonzero coastal id, resolving `base_art` isn't the only thing
that happens. The loader calls `FUN_0042e4f0(coastal_id, tile_word_ptr, 0, param4)` for every
such tile -- a function this project's own converter already treats as "the coastal-blend
helper" (it does write `base_art` into the tile's low 7 bits, matching what `raw_tile_to_art_id`
already reproduces). Decompiling its full body this time showed one more write nobody had
transcribed before:

```c
uVar2 = (param_1 << 7 ^ *param_2) & 0x3f80 ^ *param_2;
*param_2 = uVar2;
```

`param_1` here is the coastal id itself. This copies it into **bits 7-13** of the tile's
in-memory 32-bit word -- a completely separate 7-bit field from the art id (bits 0-6) that this
project had never decoded, because the on-disk file only ever needed the art id; this second
field only exists in the runtime tile representation the level loader builds.

## What reads that second field

Two functions read bits 7-13 back out. `FUN_00413050` (builds the minimap/radar overview,
unrelated to this thread) is one. The other is the terrain blitter's own per-tile helper,
`FUN_00408c80` -- called once per tile as the floor is drawn, the exact function section 1.10
already knew did *something* per-tile beyond blitting:

```c
uVar2 = (*param_2 & 0x3f80) >> 7;
if (uVar2 != 0) {
    local_10 = (param_3 + 0x10) * 0x10000;   // this tile's world-space centre, X
    local_c  = (param_4 + 0x10) * 0x10000;   // this tile's world-space centre, Y
    FUN_0041afb0(param_1, *(int *)(&DAT_00447038 + uVar2 * 0x38), &local_10, param_2, 0);
}
```

`&DAT_00447038` is `tools/rf_tile_art.py`'s own `COASTAL_TABLE` base address -- the same table
this project already fully dumps for coastline-blend resolution. `uVar2 * 0x38` is the same
per-entry stride the converter already uses. What's new is realizing the *first field* of each
entry (already dumped and named `"valid"` in `tools/data/tile_lookup_tables.json`, treated
until now as nothing more than a nonzero/zero validity flag) is read here as a real pointer and
handed straight to `FUN_0041afb0` -- **every tile whose coastal id resolves to a nonzero
`valid` pointer gets a real object queued for rendering at that tile's exact centre, in
addition to its blended ground texture.** 85 of the table's 91 real coastal ids have a nonzero
`valid` pointer; only 6 are genuinely deco-free.

## Confirming `FUN_0041afb0` is a real per-object render-queue insert

Decompiling it settled any doubt that this is coincidental. It treats its second argument as a
pointer to an object-type descriptor -- reading local position offsets (`+0x14`/`+0x18`), a
flags byte (`+0x10`), and two callback function pointers (`+0x24`, `+0x28`) -- exactly the
"art/CCB pointer plus callback pointers" descriptor shape [document 31](31-worked-example-vehicle-roster.md)
already found driving the shared vehicle object-type table. It computes a camera-relative
screen position and inserts the result into `DAT_00458c30`, a depth-sorted linked list, for
later rendering in back-to-front order -- a real painter's-algorithm object queue, the same one
vehicles go through. A `*(int *)(param_2 + 4)` "next" read at the end of the function's loop
means one descriptor can chain into a whole sequence of sub-objects, not just one.

**The conclusion this supports:** decorations are not a separate system bolted onto the
terrain renderer -- they're the exact same coastal-blend mechanism this project has understood
since section 1.5, doing double duty. Resolving a tile's coastal id was always understood to
pick a blended ground texture; it *also*, via the same table entry's own pointer field,
optionally queues a real object for the same per-object 3D pipeline vehicles use. One id,
two jobs. This closes the "where would decorations even come from" question document 34 left
open -- no hidden chunk, no procedural scatter rule, no separate placement list. It's the
coastal table this project already has fully dumped.

## What's still open

The exact shape of the descriptor struct `valid` points to isn't pinned down byte-for-byte --
in particular, which field (if any, directly) names the actual `ART.CAR` cel/CCB to draw is
not yet identified with confidence. Manually walking a couple of real descriptor instances
found plausible position/scale/flag fields but nothing yet that reads unambiguously as a small
integer in `ART.CAR`'s 0-2164 cel range. The two callback pointers (offsets `+0x24`/`+0x28`)
are genuine code addresses in the expected `.text` range and almost certainly resolve this --
following them is the natural next RE step, not attempted this session.

Also unconfirmed: whether *every* nonzero-`valid` coastal tile really does spawn something
visible every time it's drawn (as the code reads), or whether some other condition gates it --
worth checking against a real screenshot's decoration density once an art id can actually be
rendered to compare against.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
