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

## Following the descriptor's own callbacks to the literal cel index

Continuing straight from the last section (user direction: keep tracing rather than stop at
"mechanism confirmed"), both of the descriptor's callback pointers turned out to be real,
previously-undisassembled code -- Ghidra's `-noanalysis` mode never touches a function until
something forces it to, so `ForceDecompile.java` (disassemble-then-decompile at a raw address)
was needed for each:

- **Offset `+0x28`** (called first, given a copy of the tile-centre position) is a small
  position-jitter routine: it hashes sub-tile fractional-position bits into a lookup table
  (`DAT_0045aa20`) and adds a small (dx, dy) offset. Not art selection -- this is what keeps
  decorations from all sitting dead-centre on their tile, scattering them slightly and
  deterministically instead.
- **Offset `+0x00`** turned out to be the actual draw callback (invoked later, once the queued
  entry reaches the front of the depth-sorted list) -- it leads, via one more small dispatch
  function, to `FUN_0041b2b0`. That function is the payoff: it walks an array of "part" records
  (`piVar7`), and for each one computes

  ```c
  puVar4 = FUN_00413c90((*piVar7 + (((piVar7[1] & 8) == 0) - 1 & uVar1)) * 0x44 + DAT_0044964c);
  FUN_00436fb0(puVar4, piVar7 + 4, param_2);
  ```

  `* 0x44 + DAT_0044964c` is the *exact* `ART.CAR` CCB-array indexing this project already
  confirmed in section 1.7 for ordinary terrain tiles (`sizeof(CCB) == 0x44`, `DAT_0044964c`
  the array base) -- `*piVar7` is a real cel index. `piVar7[1]`'s bit 3 selects a team-colour
  variant (add `uVar1`, a colour-offset constant, exactly the mirrored-pair pattern document 21
  already found for vehicle team colours). `FUN_00436fb0` is section 1.10's own already-found
  CCB arbitrary-quadrilateral corner-mapping function -- the same one vehicles use.

**This closes the loop completely.** Decorations are not a separate rendering format at all --
a decoration "type" is an array of one or more parts, each a plain `ART.CAR` cel index plus
per-part quad-corner offsets, submitted through the identical CCB-quadrilateral path vehicles
use. There is no separate decoration renderer to reimplement; there is exactly one per-object
renderer in this game, and both vehicles and decorations are just different data fed into it.

## What's still open

The `*piVar7` cel index is read from **per-instance** data (an offset off the queued render
entry, itself populated when a decoration instance is created), not from the shared
type-descriptor this document traced statically from the coastal table. Getting an actual
number (e.g., "coastal id N's decoration uses cel 138") means finding the constructor that
copies a static parts-array template into a fresh instance -- the same shape of function
`FUN_0042d640` already is for vehicles (document 31) -- and hasn't been located yet. That's a
well-defined next step, not an open-ended one, but it's a new function to find, not just one
more field to read off an address already in hand.

Also unconfirmed: whether *every* nonzero-`valid` coastal tile really does spawn something
visible every time it's drawn (as the code reads), or whether some other condition gates it --
worth checking against a real screenshot's decoration density once an art id can actually be
rendered to compare against.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
