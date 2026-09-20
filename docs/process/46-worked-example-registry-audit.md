# 46. Worked example: auditing the asset registry against code

The registry (2165 cels) was 82% `visual_group`: names guessed from thumbnails. With document 44's
extraction of every decoration part, document 45's descriptor trail and the vehicle geometry from
documents 37-40, most of what the game *uses* can now be checked against what the registry *says*.
This is what that audit found and changed. Method: (1) extend `audit_code_referenced_cels.py` with
the new data sources, (2) render contact sheets of all 2165 cels and of every coastal decoration id
(a flat composite of its parts) and compare against the names, (3) fix by direct registry edit with
a matching block in `classify_batch2.py` (never re-running `main()`), (4) rebuild the pack and
re-screenshot (unchanged).

## Findings that change how cels should be read

**Every vehicle part is a group of five consecutive cels.** For each part cel `c` in a vehicle-type
descriptor: `c` = tan, `c+1` = green (identical size, near-identical pixel count), `c+2` = a
"yellow" version (half size for the Tank/MSV/Jeep, full size for the Heli), `c+3`/`c+4` = two more
slots (a wreck decal for the Tank/MSV/Jeep; unclear for the Heli). The descriptor's part flag `0x8`
adds the variant to the cel (document 44). The registry had scattered these across `prop`, `effect`,
`character` and `ui` families (a Jeep's green hull panel was `prop.tank_cylinder.cyan`, the MSV's
green body `prop.fuel_drum.cyan`, its wreck decals `effect.explosion_splash`...). 147 cels renamed to
`vehicle.<type>.p<cel>.<tan|green|yellow|alt3|alt4>`; Tank slots 0/1 keep their names because
`game/vehicle_box_3d.gd` looks them up. Two groups are not team groups: MSV 324-326 (1/2/3 blue
canisters, likely ammo levels) and Jeep 457-461 (five wheel-strip frames, probably spin animation).

**Structures come in the same tan/green pairs.** All 81 decoration part cels with flag `0x8` are the
even (tan) member of a pair; the odd cel is the green one. Recorded as `variant` / `pair_cel` fields
on the registry entries (additive; the tan cels are now `code_verified`).

**Projectiles are ordinary draw descriptors** (`tools/data/projectile_types.json`, from the table at
`0x4489a0` and `DumpDescriptorParts.java` on each entry's `+0x2c`/`+0x30`). Speed, damage and
lifetime are in document 45; the art:

| Types | Body cel | Shadow cel | Trail |
| --- | --- | --- | --- |
| 0, 7, 11 (shell; damage 1, 1, 0.95) | 1075 (4x4 units) | 1076 | none |
| 1, 3, 4, 5, 6 (red rocket; damage 2, 1, 1.5, 1, 4) | 1069 (+1070) | 1071 | 1077 |
| 2, 8, 9 (blue rocket; damage 4, 2, 2) | 1066 (+1067) | 1068 | 1077 |
| 10 (large orange rocket; damage 400) | 1072 (+1073) | 1074 | 1077 |

(Types 3 and 5 use the red-rocket art but are fast (6.0) or slow-lived, so they may be tracers or
bullets drawn with it; not checked.) Those cels were `prop.debris_faint`, `prop.bone_shape`,
`prop.dart_icon`, `decoration.foliage.bush_green` and `effect.burst_*`; renamed `projectile.*`, with
the four shadows `effect.shadow.hard.projectile_*`. The rocket trail (1077-1080, flag `0x8`) is drawn
behind rockets. 1081-1083 were `marker.checkered_flag` but are small embers.

**Coastal decorations, identified.** `tools/data/coastal_id_labels.json` names all 84 ids by what a
flat composite of their parts looks like (bush, palm, rocks, wall pieces, hangar roofs, gun turrets,
wreckage, dock planks, scorch marks, the base buildings...). Tentative: what they look like, not names
from the binary. Cels used by a single-purpose id were renamed where the old family was plainly wrong:
grey rocks (`flower_red`), rocks in the shallows (`coral_red`), red flowers (`sparkle`), pebble
(`dot_red`), dock planks (`reeds`), wreckage (`mine_icon`).

**Terrain cels 0-72** were renamed earlier the same day (document 44's open-items list).

## Still unresolved (found, not fixed)

- Heli-related: 580-588 (red-banded bars and blurred grey bars, 32x8 to 33x16) and 608/609 look like
  rotor blades or missiles; not referenced by any descriptor traced so far. 606/607, 610-613, 616-625
  are tan/green object pairs with no known owner (610/611 a gate-like frame, 624/625 a dome turret,
  622/623 a yellow ring).
- Explosion effect frames (1084-1089 and the large `effect.explosion_large` / `effect.burst_*` ranges)
  are unowned: explosion records (e.g. `0x445138`, damage field 25.0; `0x444ee8`, 90.0) point at frame
  lists whose format is not decoded. This also carries explosion damage, which matters for vehicle hits.
- Several `visual_group` families used by no traced descriptor (troopers, dust, jetski/watercraft,
  most `prop.*`) are still guesses by thumbnail; the contact sheets suggest their names are plausible.
- Building pieces (cels 834-1057) keep their running-number names; only the tan/green pairing is now
  recorded.
- The yellow variants (slot 2) suggest a third player colour or a hit flash; untraced.

Data added: `tools/data/projectile_types.json`, `tools/data/coastal_id_labels.json`. The audit tool
now checks the corner and projectile data too (213 code-verified cels: 81 strong, 130 soft category
mismatches that are legitimate reuse, 2 unverified).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
