# 53. Worked example: what a shell actually hits

**Question:** the port's hit tests were placeholders (a 24 px circle around a pool's active target, a 12 px circle
around a vehicle). What shapes does the original test, and against what? **Method:** find where a shell decides it
has hit something, read the shape structure it compares, then dump the real shapes for the objects that matter.
Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the shape structure

An object's draw descriptor `+8` points at a chain of **collision shapes**; each shape's `+4` points at the next.
Reading the pair test `FUN_0041e4c0` and the geometry function `FUN_0041e060` gives the shape layout:

| Offset | Field |
| --- | --- |
| `+0x00` | type: 1 point, 2 axis-aligned box, 3 convex polygon, 4 swept point |
| `+0x0a` | layer bits: which layer this shape is on |
| `+0x0b` | mask: which layers it collides with |
| `+0x0c`, `+0x10` | z range (low, high) |
| `+0x14`, `+0x18` | x / y offset |
| `+0x1c..+0x28` | box `[minx, miny, maxx, maxy]` (types 2 and 3) |
| `+0x2c`, `+0x30` | corner count and corner array (type 3) |

`FUN_0041e4c0` decides whether two shapes collide with three checks, all of which must pass:

1. each shape's mask contains the other's layer;
2. the two z ranges, each shifted by its object's height, overlap;
3. the geometry test in `FUN_0041e060` passes.

Type 4, the **swept point**, is the segment from where a moving object was (`DAT_0046a7c0`, saved by the mover
`FUN_0042c830`) to where it is now. That is why fast shells cannot skip through thin walls.

## Step 2: dump the shapes of the objects that matter

`tools/ghidra_scripts/DumpShapes.java <descriptor address>` walks a descriptor's shape chain and prints these
fields. Running it on the shell, Tank and a building gave:

| Object | Descriptor | Shape |
| --- | --- | --- |
| Tank shell (types 0-10) | `0x4547f0` etc. | type 4, layer 4, mask `0x43`, z +-1.5 about its height (7) |
| Tank | `0x43ea18` | type 3, layer 2, mask `0x27`, z 0-10, polygon +-7.5 x +-11.25 (15 wide, 22.5 long), turned with the heading |
| Candidate building (coastal 22) | `0x4517e8` | type 2, layer 1, mask `0xff`, z 0-30, box x -13..15, y -16..9 |

Checking with the masks (layers are bit values: 1, 2, 4, ...): the shell's mask `0x43` contains the building's layer 1
and the Tank's layer 2, and the Tank's mask `0x27` contains the shell's layer 4, so each pair is consistent from both
sides.

The geometry, from `FUN_0041deb0` and `FUN_0041d670`:

- **swept point vs box:** a hit when the new position is inside the box, or the segment crosses one of the box's four
  edges;
- **swept point vs polygon:** a hit when the segment crosses an edge, or the segment from the new position to the
  polygon's centre crosses none (the point is inside);
- edge crossing is an exact 2D segment-against-segment test.

## Step 3: what a shell tests on the map

`FUN_0042bb10` tests a moving object against the **tile's** coastal id (tile word `& 0x3f80 >> 7`). It uses the shape
chain of the id's *first* descriptor (`*(entry[0] + 8)`; the chained sub-objects of a palm or bush are not consulted),
placed at the tile centre, plus the decoration jitter (the same function the draw code uses, document 44), plus the
shape's own offset. `FUN_0042bd40` and `FUN_0042bf30` test the object's own tile and its neighbours.

A hit calls the coastal entry's own callback (`+0x14`) and then the mover's class callback. For a shell that is
`FUN_00414dd0`, which damages the tile (`FUN_0042e8c0`, document 45) and ends the shell. The consequence is that
**every tile whose id has a shape can be shot, not just a pool's active target.** 62 of the 84 ids have one
(`tools/data/coastal_shapes.json`, produced by `DumpCoastalShapes.java`): the boxes are mostly 32 x 32 or smaller with
heights from 5 (fence posts) to 34, palms have a 4 x 4 trunk box up to z 18 (and a canopy box above the shell's
height), and a few turret ids use octagons.

## Step 4: what a shell tests on vehicles

For an object hit (`FUN_00414e60`) the shell tests the vehicle's shape as above, and the callback is the vehicle
class's hit callback (document 47). `FUN_0042bb10` also applies a priority rule between the two classes' `+0x30`
values to decide whose callback runs; for a shell and a vehicle the result is the same damage.

## Applied in the port

- `game/collision.gd`: the shell's layer/mask/z rule, swept point vs box, and swept point vs convex polygon.
- `Vehicle.hit_polygon()` (15 x 22.5, z 0-10, layer 2, mask `0x27`). `Projectile.prev_checked` provides the swept
  segment. `MatchController` tests the shell every frame against the nine tiles around it and against every living
  vehicle but its shooter. `TARGET_HIT_RADIUS_PX` and `Vehicle.HIT_RADIUS_PX` are gone.
- A shot tile loses hit points (coastal `hp`; 0 = indestructible but still stops shells). When they run out, a
  pool's active target goes through `TargetPool` as before; any other tile emits `tile_destroyed`.
- The destroyed state follows the traced rule (`FUN_0042e600`, `FUN_0042e4f0`): the entry's destroyed coastal id and
  its art (byte `0xFF` = keep the ground; flags exactly 8 add the tile's team variant), or the decoration removed with
  the entry's own art byte plus a random 0..1 or 0..3 (flag bits 1 and 2).
- Bush and palm collapse scripts use op 21 (`FUN_0042d9f0`): the decoration is cleared **at once** and the state change
  is scheduled `n` ticks later (`FUN_004146d0` -> `FUN_0042da50` -> `FUN_0042e600`). Other records change state at their
  `TILE_STATE` op (document 51).
- The muzzle flash and the shell are drawn at the barrel's tip including the box render's 2-unit ground clearance (the
  flash had been drawn 2.5 units too low; you reported it).

## How it was checked

On RFMAP001 a palm (coastal 3) is removed, burns, then leaves branch and leaf debris (id 84). A scripted 7-shot run:
6 shots destroy the building; a shot 20 units off the box misses; a shot 8 to the side of a Tank misses and 5 hit.

## Not done

Vehicle vs tile collision (`FUN_0040cea0` with damage 34, and blocking; done in document 54), vehicle vs vehicle,
the tile callback `+0x14`, the shard debris `FUN_00434980` makes when a tile is nearly gone, budget accounting for
non-pool candidate buildings (`FUN_00432710` for a destroyed candidate that is not the active target), and the
priority rule between the two classes' hit callbacks.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
