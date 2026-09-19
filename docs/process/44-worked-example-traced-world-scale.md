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
- The ground quads (cels 133/137) live on the **effect page** (document 9's translucent darken
  masks, registry name `bush_white.*` is wrong): they are the palm shadows. Drawn as black at
  `SHADOW_ALPHA = 0.3` -- **placeholder strength, not traced** (doc 9: rows 2/4 of the darken table).
- `tools/build_pack.py` emits corners into `terrain/decorations.json` for covered ids.

## Still not modelled / open

- The original's per-tile position jitter (descriptor callback +0x28, document 35) -- decorations
  sit on tile centres here.
- Team-colour cel variant for flag bit 3; ids 49, 50 (angle-bucket path, part count 0) and 76.
- Shadow strength; registry names for cels 133/137 (shadows) and 134 (called `rock_tan`).
- Camera FOV/tilt came from traced constants in document 43; the tank/tree *sizes* now do too.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
