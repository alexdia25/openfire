# 50. Worked example: which explosion plays where, traced

Document 49 named the animation clips by look and stopped, because guessing which clip goes with which
event is exactly what this project does not do. This document traces the linkage from the code.

## The explosion object

Every explosion, muzzle flash, impact puff and tile collapse is an object of class `0x44bb70` ("Expl"),
spawned with `FUN_0042e080(owner, x, y, z, record, extra)`. The **record** (26 of them at
`0x443b90-0x445238`, all catalogued in `tools/data/explosion_records.json`) is:

| Record field | Meaning |
| --- | --- |
| `[0]` | pointer to a byte-coded script (below) |
| `[1]` | pointer to a table of sub-scripts / draw descriptors (ops 10 and 12) |
| `[3]` | duration (16.16) |
| `[5]` | progress added per tick (16.16); the effect lasts `duration / rate` ticks |
| tail | the record's last words are also an animated-part descriptor based at `record - 0x10` (document 49) |

`FUN_0042dbe0` runs the script every tick: byte 0 ends the object, 1 yields until the next tick, 2 waits
until progress reaches the next byte; anything else calls handler `n` of the table at `0x44bae0`. The
23 ops (arguments are signed bytes):

| Op | Args | Does |
| --- | --- | --- |
| 3 | 1 | play sound `n` from the table at `0x44b9a0` |
| 4 | 0 | tile changes state (`FUN_0042e600`) |
| 5 | 4 | set/convert a neighbouring tile (`FUN_0042e4f0`) |
| 6, 12 | 1 | switch the drawn descriptor from the global table (`0x4439b0`, 0x44 apart) or from record field `[1]` |
| 7 | 0 | back to the default (no) descriptor |
| 8 | 1 | set the progress counter to `n` (a jump forward in the effect) |
| 9 | 3 | conditional skip of the next ops |
| 10 | 1 | jump to sub-script `n` of record field `[1]` |
| 11, 16 | 0 | kill the object / detach from its owner |
| 13 | 6 | **create an area damage box** (extents, offsets, a signed damage per tick in whole units) |
| 14 | 1 | set the damage box's half-extents to `n` on all axes |
| 17 | 1 | draw the tile's decoration descriptors in render mode `n` |
| 18, 19 | 3 | damage a neighbouring tile by 255 if its coastal id matches (document 44) |
| 15 | 2 | does nothing (two ignored bytes) |
| 22 | 2 | if the tile's coastal id equals `a`, set its team/variant bits to `b` |
| 20 | | repeats the following ops |
| 21 | 1 | clears the tile's decoration now and schedules the tile's state change `n` ticks later (`FUN_004146d0` -> `FUN_0042da50` -> `FUN_0042e600`; document 53) |

## Only one explosion damages anything

Scanning all 26 scripts for op 13 finds exactly one area-damage explosion, record **`0x445058`**:
`DAMAGE_BOX(-4, 4, 8, 8, 0x43, -1)` then sound 14, wait, `BOX_EXTENT 25`, later 12, 16, 20 -- a box that
grows to 25 units either side and deals **1.0 damage per tick** (negative arg -> `FUN_0042dd20` passes
`-(rate x dt)` to the victim's hit callback, i.e. the vehicle rule of document 47). It is spawned from
`FUN_00409d80`, the destroy handler of class 10 (`0x4430c8`), an object drawn from cel 1081 whose update
blinks (`FUN_00409cd0`, a sound at `0x44b580`), which detonates when a class-1 object (a vehicle) touches
it (`FUN_00409dd0`) or a tile hit with damage above 1.5 lands on it (`FUN_00409e00`). That is a **mine**.
The vehicle-death landing record (`0x444c80` per type via `0x4453d8`) and every tile collapse have no
damage box: they play a sound and swap drawn descriptors. What spawns mines (the single `0x4430c8`
reference is inside the spawn function at `0x409e6d`) is not yet traced.

## Tile collapses: coastal id -> record -> clips

`FUN_0042e6a0` (a tile's hit points ran out) spawns the record stored at coastal-table entry field `+0x2c`
(entry base `0x447030 + id * 0x38`); when the field is 0 it just re-textures the tile. Traced from the
table, with the clips of each record:

| Record | Coastal ids | Clips (first cel, frames) |
| --- | --- | --- |
| `0x443b90` | 1-6, 11 (bushes, palms, sapling) | 1139 (20), 1159 (24) |
| `0x443e10` | 12, 13, 43-46, 49, 50, 54-60, 68, 90 (buildings, walls, gantries) | 1084 (25), 1109 (18), 1123 (24) |
| `0x443f30` | 22 (the candidate building) | 1580 (17), 1084 (17) |
| `0x443ee8` | 18-21, 35, 69-72 | 1580 (17), 1084 (17) |
| `0x4441a0` | 15-17 | 1580 (18), 1275 (20) |
| `0x4440d0` | 36-38 | 1251 (25), 1210 (18) |
| `0x443cc0` | 39-42 (gun turrets) | 1172 (25), 1197 (29), 1210 (25) |
| `0x444330` | 23-26, 30-34 | 1580, 1251, three 1197, three 1291 |
| `0x4444a8` | 27-29, 62, 63 | 1484, three 1523, three 1123, 1109 |
| `0x444000` | 74-89 (docks, debris, scorch) | 1537 (22), 1484 (19) |
| `0x444740` | 64-67 | sand puffs 1612, 1626, 1640 |
| `0x444778` | 47, 48 | the same sand puffs |

(The coastal id labels in `tools/data/coastal_id_labels.json` remain visual; this table is the traced
part.) Field `+0x28` of ids 1, 2, 6, 11, 12, 13 points at `0x4451b8` (cel 1746, 16 frames); its use is not
traced. `FUN_00434980` (called when a tile is nearly destroyed) spawns a separate debris object class
`0x44eb38`.

## Projectile impacts: surface -> record

A projectile's death handler `FUN_00414e20` spawns `entry[13][surface]`, where `entry[13]` is projectile
type field `+0x34` and `surface` is byte `obj+0x73`, set when the shot ends: **0** land, **1** water,
**2** pavement (tile art 73-83, `FUN_00414b10`), **3** hit an object (`FUN_00414e60`), **4** hit a tile
(`FUN_00414dd0`). Water is `FUN_0042f280`: tile art 1 and 2 (the two open-water cels, 2 the deep kind
that sinks vehicles, document 47), the coast pieces by a per-cel geometry test, land otherwise.

| Surface | Types 0, 3, 5, 7, 11 (table `0x448970`) | Types 1, 2, 4, 6, 8, 9, 10 (`0x448988`) |
| --- | --- | --- |
| land | `0x444740`: sand puffs 1612/1626/1640 (14) | `0x444840`: 1580 (18), 1598 (18) |
| water | `0x4445b8`: 1555 (10) | `0x4445e8`: 1537 (18), 1565 (15) |
| pavement | `0x444968`: puffs 1686/1700/1714 (14) | `0x444a30`: 1654 (18), 1672 (18) |
| object / tile hit | `0x444b68`, `0x444ac8`: 1452 (16), 1468 (16) | same |

So the Tank shell (type 0) on land plays the sand puffs, on water the small ring, on a hit the 1452/1468
sparks. Muzzle flashes: Tank `0x445138`, MSV/Jeep `0x4450d8`, Heli `0x445168` (from their fire handlers);
rocket smoke trail `0x445238` (cel 1529) from the projectile update `FUN_00415100`.

## Still open

- **How a clip's frame is chosen:** resolved in [document 51](51-worked-example-explosion-playback.md).
- Field `+0x28` of the coastal entries is the crush effect of the bush ids (document 54); what spawns mines; the sub-script table use in `0x444c80`.
- Explosion damage to vehicles is now defined (record `0x445058`, 1.0 per tick in a growing box) but is
  only reachable through mines, which are not spawned by anything traced.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
