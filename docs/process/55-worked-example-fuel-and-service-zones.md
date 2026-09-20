# 55. Worked example: fuel, and the zones that refill it

Document 54 found the fuel drain and a "zone" flag on some tile shapes and left both untied. They are one
system: `FUN_0040c540`, called at the end of every vehicle update.

## Zones

A coastal shape whose byte `+8` has bit 1 is a **zone** a vehicle may drive into: the tile callback
`FUN_004366f0` (coastal ids 14 and 39-44) returns "pass" for it and stores the tile and the shape in the
vehicle's state (`+0x68`, `+0x6c`). (Document 54 tested byte `+9` by mistake, which is the zone's *kind*.) The
kinds, from `tools/data/coastal_shapes.json` (`b8` / `b9`):

| Kind (`b9`) | Coastal ids | Zone box (relative to the tile, rotated per id) |
| --- | --- | --- |
| 1 refuel | 39, 40, 41, 42 | 6 x 6 at 12 units from the tile centre, z 0-3 (a pump's nozzle spot, beside a solid octagonal body) |
| 2 rearm | 14 (15-17 have the same zone but no callback, so it blocks) | 32 x 12, 8 units off the centre |
| 3 pick-up | 43, 44 | 64 x 64 around the tile |

The coastal id labels in `tools/data/coastal_id_labels.json` for these ids were visual guesses; they are
corrected there.

## What `FUN_0040c540` does

While the vehicle is **moving** (speed nonzero or its heading changed this tick) nothing happens and the zone
stays remembered. While it **stands still**, each tick:

1. Its shape must still overlap the zone's box (`FUN_0041e4c0`), else the zone is forgotten.
2. **Refuel (kind 1):** `fuel += 0.5` per tick (62.5 per second), clamped to the type's maximum (record
   `+0x210`, 400 for the Tank: a full tank in 6.4 s), with a looping sound every 40 ticks while it is still
   rising.
3. **Rearm (kind 2):** each weapon slot's ammunition rises by `max(1, dt / 2)` per tick up to its cap (record
   slot `+0x14`: 150 for the Tank's gun), slot after slot.
4. **Pick-up (kind 3):** if the tile's variant bits equal the player's index, `FUN_00432550` clears the tile's
   decoration and spawns a carried object (class `0x44e370`, drawn from the descriptor of coastal id 43 or 44)
   attached to the vehicle.

## The other end: fuel and ammunition

- Fuel starts full and is drained in `FUN_0040b980`: `|speed| x dt >> 5` per tick while the speed is nonzero,
  applied before the move so it is spent even when the vehicle is blocked. In world terms that is **one fuel
  per 32 units driven** (400 = 400 tiles). At 0 the vehicle is destroyed by the same path as 0 hit points
  (the Tank has no dying state, so it becomes a wreck).
- Ammunition starts at each slot's cap (150) and the fire handler refuses a shot with none left (an empty
  click, `0x44b988`), which the port still does not model (kept out at the user's request).

## Applied in the port

`Vehicle.fuel` (400) drains by distance / 32, kills the vehicle at 0 and resets on respawn;
`MatchController` remembers the zone a collision test entered and refuels 0.5 per tick while the vehicle
stands still over a kind-1 zone. Scripted checks: driving 300 units burned 9.38 fuel (300 / 32); on RFMAP002
(coastal 40, tile (44,36)) a tank parked on the pump's zone gained 62.5 fuel per second, none while moving,
and the zone was forgotten on leaving; running dry destroyed it. There is no gauge yet (nothing traced about
the HUD's layout), so fuel is only observable through the property and its consequences.

## Not done

Ammunition (traced above), pick-up objects and what they do once carried, the HUD gauges, the sounds, the
enemy AI's fuel use (a placeholder AI that never refuels will eventually run dry), and the other vehicles'
fuel maxima.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
