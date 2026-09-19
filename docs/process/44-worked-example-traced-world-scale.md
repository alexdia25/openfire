# 44. Worked example: sizes traced from the source instead of estimated

User direction after document 43: "reference the source code for sizes." Two estimates (tank 0.4,
palm 0.5) became traced values, and a real gap turned up in the process.

## The unit

Document 35 already had the anchor: a tile's world centre is `(tile + 0x10) * 0x10000`, so world
coordinates are 16.16 fixed point and **one tile = 32 world units**. Vehicle and decoration part
corners are in the same units. Document 37's "8/3 factor" only converted them to *texture pixels*
to match each cel's dimensions; it never said how big the tank is in the world.

## Tank

`tools/data/vehicle_type_parts.json`: the hull top's raw corners are +-786432 = +-12.0 -> **24 world
units wide** (on a 32-unit tile; matches the ~24-unit road). Scale = 24/64 = **0.375** exactly
(`VEHICLE_SCALE`, was an estimated 0.4).

## Decorations (new extraction)

`tools/ghidra_scripts/DumpCoastalDecorationCorners.java` walks each coastal id's descriptor
(same layout as a vehicle's: corner count +0x2c, corners +0x30, parts +0x38) and, new, follows the
`+4` "next" link document 35 noticed but never chased. Output: `tools/data/coastal_decoration_corners.json`
(82 ids, 399 parts, corners in world units, plus each link's local x/y offset).

- A palm (coastal id 3) is a **chain of two sub-objects**: fronds (two 16x16-unit quads tilted
  and floating at z 18-29) and a second link with a flat 16x16 ground quad (cel 133) and a
  vertical trunk quad (cel 134). Id 4 chains cel 137 (ground) + 138 (trunk). So the trunk cel is
  real; document 36/41's hand-made "canopy + invented trunk + ring layout" was a lucky
  approximation of it and is removed. `PALM_SCALE` is gone: 32px frond cel on a 16-unit quad is 0.5.
- `game/decoration_field_3d.gd` now builds every part as its real quad (one batched mesh per atlas
  page, alpha-scissor, cel stretched to the corners like `_build_warped_mesh`).
- The ground quads (cels 133/137) live on the **effect page**: they are PRE0=13 masks, document 9's
  "darken row 4" blend, i.e. the palm shadows. Drawn black at `SHADOW_ALPHA = 5/32`: the darken
  table generator (FUN_00424420) scales each channel by `(31 - row) >> 5`-style `(31 - k) / 32`,
  so row 4 keeps 27/32. (The original then snaps to the nearest palette index; not reproduced.)
- `tools/build_pack.py` emits corners into `terrain/decorations.json`; `zoff` (descriptor +0x1c,
  skipped when flag byte +0x10 has 0x10) and `jitter` ride along.

## The three follow-ups (same day)

1. **Shadow strength** -- traced, above (was a 0.3 placeholder).
2. **Per-tile position jitter** -- `FUN_004365c0` (descriptor `+0x28` callback, set on 28 parts)
   adds `table[(tile_y & 15) * 16 + (tile_x & 15)]` = `(dx, dy)`, each `rand(25) - 12` world units,
   to the tile-centre position; the queue function re-copies the original position per chained
   link, so every link of one decoration shifts identically. The table (`FUN_00436540`) is built
   at level load from the MSVC LCG (`seed*214013 + 2531011`, `>>16 & 0x7fff`, range as
   `(r*2*n)>>16`; `FUN_0041d3d0`) seeded with **the 32-bit sum of every raw tile byte**
   (`FUN_00414130`), now recorded as `tile_seed` by `tools/convert_rfm.py` and reproduced in
   `DecorationField3D`. Palms now scatter organically as in the reference. **Caveat:** the
   seed rule is read from the decompile, not cross-checked against a real capture of the
   original's palm positions.
3. **Team colour + the missing ids.** A flag-8 part's cel is offset by bits 14-15 of the tile word
   (`FUN_0041b2b0`), which `FUN_0042e4f0` fills from `primary_table[raw].param4` (0 or 1 on every
   tile that spawns a flag-8 decoration: tan/green). Carried per decoration as `variant`, resolved in
   `build_pack.py` to `variant_sprite_ids`. Ids **49 and 50** (17,907 and 33,477 tiles across the
   levels) turned out to be the **buildings**: part count 0 means "draw the parts named by angle-
   bucket list 0" (decorations always use bucket 0), a truncated-pyramid roof (32x32 base to
   ~18x18 top, 24 / 34 units tall) with team-varied walls, a small raised cap, and a ground quad.
   Extracted; RFMAP117 (`RF_DEBUG_LEVEL=RFMAP117`) now renders whole bases (huts, walls, barracks).
   Id 76 (corner count 0) is used by no level and is still skipped.
   Registry: cels 133/137/116/117/141/120/121 are shadow masks (`effect.shadow.hard.*`), 134/138/
   142 palm trunks (`decoration.tree.palm_trunk.01-03`); cel 145 is a real sprite and keeps its name.

## Still open

- **Candidate-pool buildings: resolved, no new system.** `FUN_00432600` treats a candidate as
  "intact" when its tile word's coastal id is 22 (`(word & 0x3f80) == 0xb00`), and the raw
  candidate tiles 0xB4/0xDC carry exactly coastal id 22 (param4 0/1 = tan/green). So a pool's
  buildings are ordinary coastal-id decorations (22 intact; the neighbouring ids are its damaged
  states) -- already rendered by `DecorationField3D`. RFMAP001's candidate at tile (75,56) draws
  the green-roofed building with its doorway, and the spawn tile's striped pad is plain ground art
  (cel 90); both appear in the reference shots once the debug markers are hidden. New debug env
  vars for comparing: `RF_DEBUG_NO_MARKERS=1`, `RF_DEBUG_FOCUS_TILE=x,y`, `RF_DEBUG_LEVEL=RFMAPnnn`.
  What is NOT done here is the *gameplay* side (a destroyed building switching to its damaged
  decoration id): the pool logic still only tracks which candidate is active.
- Angle-bucket lists 1-7 (vehicle-style rotation) are unused by decorations and not extracted.
- Part culling flags (bits 0/1) rely on the depth buffer here rather than the original's
  screen-space test.
- Cels 52-55 / 48-51 biome-name swap (registry) is still unrenamed.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
