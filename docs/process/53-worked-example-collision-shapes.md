# 53. Worked example: what a shell actually hits

The port's hit tests were placeholders: a 24 px circle around a pool's active target, a 12 px circle around
a vehicle. The original has a real shape system, and reading it replaces both.

## Shapes

An object's draw descriptor `+8` points at a chain of collision shapes (each shape's `+4` is the next). A
shape is: type at `+0`; layer bits `+0xa` and a mask of layers it collides with `+0xb`; a z range (`+0xc`
low, `+0x10` high); an x/y offset (`+0x14`, `+0x18`); for types 2 and 3 a box `[minx, miny, maxx, maxy]`
(`+0x1c..+0x28`); and for type 3 a corner array (`+0x30`, count `+0x2c`). `FUN_0041e4c0` decides a pair:
each mask must contain the other's layer, the z ranges (each shifted by its object's height) must overlap,
and the geometry test in `FUN_0041e060` must pass. Types: 1 point, 2 axis-aligned box, 3 convex polygon,
4 a **swept point** -- the segment from where a moving object was (`DAT_0046a7c0`, saved by the mover
`FUN_0042c830`) to where it is.

| Object | Descriptor | Shape |
| --- | --- | --- |
| Tank shell (types 0-10) | `0x4547f0` etc. | type 4, layer 4, mask `0x43`, z +-1.5 about its height (7) |
| Tank | `0x43ea18` | type 3, layer 2, mask `0x27`, z 0-10, polygon +-7.5 x +-11.25 (15 wide, 22.5 long), turned with the heading |
| Candidate building (coastal 22) | `0x4517e8` | type 2, layer 1, mask `0xff`, z 0-30, box x -13..15, y -16..9 |

Geometry: swept point vs box (`FUN_0041deb0`) hits when the new position is inside the box or the segment
crosses one of its four edges; vs polygon when the segment crosses an edge or the segment from the new
position to the polygon's centre crosses none (inside). Edge crossing is `FUN_0041d670`, an exact 2D
segment-segment test.

## Tiles

`FUN_0042bb10` tests a moving object against the *tile's* coastal id (`tile word & 0x3f80 >> 7`): the shape
chain of the id's **first** descriptor (`*(entry[0] + 8)`, the chained sub-objects of a palm or bush are not
consulted), placed at the tile centre plus the decoration jitter (the same callback the draw code uses,
document 44) plus the shape's own offset. `FUN_0042bd40` / `FUN_0042bf30` test the object's tile and its
neighbours. A hit calls the coastal entry's own callback (`+0x14`) and then the mover's class callback:
for a shell `FUN_00414dd0`, which damages the tile (`FUN_0042e8c0`, document 45) and ends the shell. So
**every tile whose id has a shape can be shot, not just a pool's active target**. 62 of the 84 ids do
(`tools/data/coastal_shapes.json`, from `DumpCoastalShapes.java`); the boxes are mostly 32 x 32 or smaller
with heights from 5 (fence posts) to 34, palms have a 4 x 4 trunk box to z 18 (and a canopy box above the
shell's height), and a few turret ids use octagons.

## Vehicles

For an object hit (`FUN_00414e60`) the shell tests the vehicle's shape as above; the callback is the vehicle
class's hit callback (document 47). `FUN_0042bb10` also applies a priority rule between the two classes'
`+0x30` values to decide whose callback runs; for a shell and a vehicle the result is the same damage.

## Applied in the port

- `game/collision.gd`: shell layer/mask/z rule, swept point vs box and vs convex polygon.
- `Vehicle.hit_polygon()` (15 x 22.5, z 0-10, layer 2, mask `0x27`); `Projectile.prev_checked` gives the
  swept segment; `MatchController` tests the shell against the nine tiles around it and against every
  living vehicle but its shooter each frame. `TARGET_HIT_RADIUS_PX` and `Vehicle.HIT_RADIUS_PX` are gone.
- Any shot tile loses hit points (coastal `hp`, 0 = indestructible but still stops shells); when they run
  out a pool's active target goes through `TargetPool` as before, any other tile emits `tile_destroyed`.
- The destroyed state follows the traced rule (`FUN_0042e600` / `FUN_0042e4f0`): the entry's destroyed
  coastal id and its art (byte `0xFF` = keep the ground; flags exactly 8 add the tile's team variant), or
  the decoration removed with the entry's own art byte plus a random 0..1 / 0..3 (flag bits 1 / 2).
- Bush and palm collapse scripts use op 21 (`FUN_0042d9f0`): the decoration is cleared **at once** and the
  state change is scheduled `n` ticks later (`FUN_004146d0` -> `FUN_0042da50` -> `FUN_0042e600`); other
  records change state at their `TILE_STATE` op (document 51). Verified on RFMAP001: a palm (coastal 3) is
  removed, burns, then leaves branch and leaf debris (id 84); a scripted 7-shot run: 6 shots destroy the
  building, a shot 20 units off the box misses, a shot 8 to the side of a Tank misses and 5 hits.
- The muzzle flash and the shell are drawn at the barrel's tip including the box render's 2-unit ground
  clearance (the flash had been drawn 2.5 units too low, reported by the user).

## Not done

Vehicle vs tile collision (`FUN_0040cea0` with damage 34, and blocking), vehicle vs vehicle, the tile
callback `+0x14`, `FUN_00434980`'s shard debris when a tile is nearly gone, non-pool candidate buildings'
budget accounting (`FUN_00432710` for a destroyed candidate that is not the active target), and the
priority rule between the two classes' hit callbacks.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
