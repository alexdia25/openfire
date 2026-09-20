# 54. Worked example: how a vehicle is blocked, and what it can crush

Document 53 traced the shape system for shells. The same tests stop vehicles; what differs is the
callbacks. Until now the Tank drove through buildings.

## The movement step

`FUN_0040b980` (the vehicle class update, `0x445438 + 0x10`) computes the tick's displacement with the drive
function (document 45), then:

- **Standing still** (`speed == 0`): if the heading changed, `FUN_0042bd40` tests the shape at the new
  heading; if it overlaps something the heading is restored.
- **Moving**: the displacement is applied with `FUN_0042c830`, which moves the object, updates its tile
  membership and runs the collision test (`FUN_0042bd40`); a return of 1 means blocked and the move is undone.
  If it was blocked and the heading had changed, the turn is undone and the *same* displacement is tried
  again; if that is blocked too the vehicle stays put, is flagged as having collided (`+0xc |= 0x4000000`)
  and its speed becomes `-speed >> 2` -- it bounces back at a quarter of its speed.

## What blocks

`FUN_0042bb10` tests the vehicle's shape (document 53: a 15 x 22.5 polygon, z 0-10, layer 2, mask `0x27`)
against the tiles around it, then against other objects.

- **Tile shapes** of the coastal ids (`tools/data/coastal_shapes.json`): every layer-1 shape with mask 255
  matches the vehicle. The coastal entry's own callback (`+0x14`) runs first, and only if it does not answer
  "pass" (8) does the vehicle class's tile callback `FUN_0040c130` run; it records the tile in the vehicle
  state and returns 1: **blocked**. So any tile shape without a callback blocks.
- **Other vehicles**: `FUN_0040c150` returns 5 (blocked) and records the other object.

## The tile callbacks

Only these coastal ids have one (all return 0, i.e. defer to "blocked", for a mover that is not a vehicle):

| Callback | Ids | For a vehicle |
| --- | --- | --- |
| `FUN_00436640` | 1, 2, 6, 11, 12, 13 (bushes) | shapes with mask 4 are ignored; a Jeep (type 1) is blocked; otherwise **faster than 0.5 units/tick it flattens the tile** (damage 100 through `FUN_0042e8c0`, with the entry's field `+0x28` swapped in as the effect record, and the tile's variant bits set to 1) and passes; slower, it is blocked |
| `FUN_00436610` | 7-10 (rocks) | everything but a Jeep passes over them |
| `FUN_004366f0` | 14, 39-44 | a shape flagged as a zone (byte `+9` bit 1) is passed and remembered in the vehicle state (`+0x68`, `+0x6c`, read by the ammo/rearm code `FUN_0040c540`); other shapes block |
| `FUN_00436a50` | 47, 48 (crates) | faster than 0.5 units/tick: flattened by damage 100 with the ordinary destroy effect, and passed; slower: blocked |
| `FUN_00432d80` | 63 | if one of the two tracked objects in the list at `0x45ae48` sits on this tile and is not yet carried, attaches it to the vehicle (`FUN_0042cc50`) and plays a sound; returns 0, so the tile still blocks |

This resolves document 50's open item: coastal field `+0x28` (record `0x4451b8`, cel 1746) is the **crush
effect** of the bush ids.

## Fuel (traced, not applied)

The same update subtracts `|speed| x dt >> 5` from the vehicle's `state+0x14` every tick it moves; the state
starts at the type record's `+0x210` (Tank 400). At zero the vehicle is destroyed exactly as by damage (wreck
object, document 48). At top speed (1.05 units/tick) that is 2.05 per second: **a full Tank runs dry after
about 195 seconds of flat-out driving**. A gauge (`record +0x22c`) is redrawn from it, and the ammo/rearm code
tops it up. Not applied here: nothing refuels yet.

## Applied in the port

- `Vehicle` moves through `_move()` with the turn-undo and quarter-speed bounce above, calling
  `blocked_test` (set by `MatchController.vehicle_blocked()`): the nine tiles around, each shape tested with
  `Collision.polygon_hits_box` / `polygons_hit`, the callbacks above (bushes and crates crushed above
  31.25 px/s, rocks passed, zones passed), and other living vehicles.
- A crushed tile plays its record (`Pack.get_crush_effect()` for bushes, the ordinary destroy record for
  crates) and changes state at the record's `TILE_STATE`. Scripted checks on RFMAP001: the spawn point is
  clear; ramming the building from 60 units at 65 px/s stops the Tank at its wall and bounces it back at a
  quarter speed; a bush blocks at 10 px/s and is flattened at 60 px/s.

## Not done

The Jeep, MSV and Heli (their own shapes and flight height), the zone effects (rearm/refuel), the tile
callback `FUN_00432d80`, fuel, sound, and vehicle contact damage: nothing damages a vehicle for ramming a
wall. (The tile-collision damage callback `FUN_0040cea0`, damage 34 at speed above 1.0, belongs to the falling
wreck object, not to a driving vehicle.)

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
