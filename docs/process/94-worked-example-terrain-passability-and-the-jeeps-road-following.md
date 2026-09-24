# 94. Worked example: what the terrain does to a vehicle, and the Jeep's road-following steering

**Question:** the next-steps list carried "terrain-based vehicle passability and height (elevation bits, height byte)" as not started since 2026-09-06. What does the terrain actually do to a vehicle in the original? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the "elevation" lead is hit points, and there is no height

The note said the coastal table's byte `+9` ("height_seed") and the tile word's bits 25-27 ("elevation-ish") looked like physics. They are not: [document 93](93-worked-example-the-buildings-stages-checked-against-the-code.md) reads `FUN_0042e8c0`, which takes the tile word's bits 25-27 as **hit points** (`hp = *tile & 0xe000000`, ">> 25") and the entry's byte as the initial value (6 for the building). There is no tile height anywhere in the movement code: a vehicle's height (`obj+0x48`) is its own (the Heli's climb, a sinking, the pad's rise), not the ground's. So the "height" half of the item is closed: **there is no terrain height to model**.

## Step 2: what the terrain does read, all of it already in the port except one thing

Every place a vehicle's tile is read in the drive code goes through `FUN_0040c390(obj, record, state)`, the speed scale. Decompiled (`DecompileMany.java 0x0040c390 0x0040c460`):

```c
DAT_0048c7b0 = 0;                                  // the road mask, cleared on every call
if (obj.height > 0xffff) return 0x10000;           // airborne: 1.0
if (state.in_water /* +0x70 */) return (record.type == 1 && state.immersion /* +0x80 */ == 0x10000) ? 0x4000 : 0xc000;   // 0.25 swimming Jeep, else 0.75
if (record.type == 1 && state.immersion == 0x10000) return 0x28f;                    // a swim-mode Jeep on dry land: 0.01
art = *obj.tile & 0x7f;
if (art > 0x48 && art < 0x5a) { DAT_0048c7b0 = table_0x44523c[art]; return 0x13333; }   // road art 73-89: 1.2, and the piece's DIRECTION MASK
coastal = (*obj.tile & 0x3f80) >> 7;
if (coastal == 0x4a) { DAT_0048c7b0 = 0xc; return 0x13333; }
if (coastal == 0x4b) { DAT_0048c7b0 = 3;   return 0x13333; }
return 0x10000;
```

The speed factors (1.0 / 1.2 / 0.75 / 0.25 / 0.01) were traced in documents 45 and 62 and applied (`Vehicle._terrain_speed_scale`). Passability itself (what stops a vehicle) is the collision shapes and tile callbacks of documents 53 and 67, and water is the three-class rule of document 62 (`FUN_0042f280`: land, shallow, deep; a Tank sinks in deep water, only a swim-mode Jeep crosses it). What had been **left out is the second output**, the mask in `DAT_0048c7b0`.

## Step 3: who reads the mask

`FindPointerRefsMulti.java 0048c7b0` gives ten references: the four writes above and **six reads, all inside the Jeep's drive handler `FUN_0040db80`** (`0x40dcfe`, `0x40dd52`, `0x40dd69`, `0x40dd9c`, `0x40ddd0`, `0x40de03`). No other type's handler reads it (`FindCallRel.java 40c390` shows four callers: the Tank's `0x40c233`, two others `0x40cf56` / `0x40d0da`, the Jeep's `0x40dc6f`). The table at `0x44523c + art * 4` (`DumpDwords.java 0x445360 17`) is, for art 73 to 89:
`3, 7, 0xe, 0xd, 7, 0xf, 0xc, 6, 0xa, 5, 9, 0xc, 0xc, 3, 3, 3, 0xc`: four direction bits, so a straight piece has two, a corner two, a junction three or four.

The block that uses it (`DisasmForce.java 0x40db80 0x40dee0`; the handler is the drive function of document 45 with the differences of document 62 and this one) runs when **no turn key is held** (`keys & 0x18 == 0`):

```
0040dd50  CMP [0x48c7b0],0 ; JZ done          ; a road mask?
0040dd5d  CMP [steer_scale],0 ; JZ done        ; (the damage steering limiter, never 0)
0040dd67  TEST [0x48c7b0],1 ; JZ next          ; bit 1: a road running north
0040dd70  EAX = obj.heading (+0x4c)
0040dd73  CMP EAX,0x380000 ; JG go            ;   heading > 315 degrees ...
0040dd7a  CMP EAX,0x80000  ; JGE next         ;   ... or < 45 degrees
0040dd81  EBX = obj.x (+0x40) & 0x1ffffc       ;   go: x within the tile (0 .. 32 units)
0040dd8a  SUB EBX,0x100000 ; SAR EBX,2 ; NEG EBX   ;   target = -(x - centre) / 4        (0x40000 = 22.5 degrees at the tile edge)
  bit 2 (south):  heading in (0x180000, 0x280000)  -> target = (x - centre) / 4 + 0x200000
  bit 4 (east):   heading in (0x80000, 0x180000)   -> target = 0x100000 - (y - centre) / 4
  bit 8 (west):   heading in (0x280000, 0x380000)  -> target = (y - centre) / 4 - 0x100000
0040de33  AND EBX,0x3fffff
0040de42  EDX = mul(record.turn_rate (+0x178), steer_scale)
0040de4d  CALL FUN_004319e0(&heading, target, EDX)   ; steer the heading toward the target at the vehicle's full turn rate
```

`FUN_004319e0` (decompiled) moves the heading toward the target the short way round by at most `rate * dt` and lands on it. So: **a Jeep whose driver is not turning is pulled along the road it is on**, to the road's direction when its heading is within 45 degrees of it, leaning back toward the centre line by 22.5 degrees per 16 units of offset. (The original's heading 0 is north, clockwise; the port's `heading_deg` is that minus 90.)

Two details worth stating. `FUN_0040c390` is only called when the friction bit (bit 0) is clear, i.e. while a throttle key is on (or the Jeep creeps while turning, document 62), so **the mask keeps its last value while coasting**; and the airborne, in-water and swim-mode returns above clear it. And the "both turn keys" case, `FUN_004319e0(&heading, state+0xb0, ...)`, that document 45 called auto-steer, is not something a player does: its writer is the enemy AI's controller (`0x42d0e7`: `OR EAX,0x18 ; state+0xb0 = target heading`), which steers toward a heading by pressing both bits. The combined condition in front of it (`road && diff > 0x3c0000 && diff < 0x40000`) can never be true, so it always steers.

## Applied in the port

`game/road_assist.gd` holds the mask table and the rule; `Vehicle._process` runs it for the Jeep only:

```gdscript
if vehicle_type == 1:
	if controls.y != 0.0:
		_road_mask = _road_mask_here()          # FUN_0040c390 is only called while a throttle is on
	if turn == 0.0 and _road_mask != 0:
		heading_deg = RoadAssist.steer(_road_mask, heading_deg, position, turn_rate_deg, delta)
```
```gdscript
if (mask & 1) != 0 and (h > 315.0 or h < 45.0):
	return fposmod(-lx, 360.0)                   # lx = (x within the tile - 16) * 22.5 / 16
```

`_terrain_speed_scale` now also gives the 1.2 for coastal ids `0x4a` / `0x4b` (no level uses either). `tools/tests/road_assist_check.gd` (17 checks): the table, the four target rules with numbers (north, 8 units east of centre: 348.75; south: 191.25; east, 8 south: 78.75; west: 281.25), a Jeep on level 1's first N/S road (74, 58) pulled from 20 degrees to the lateral target, a held turn key not overridden, nothing 60 degrees off the road, the thrust clearing the mask off the roads, and a Tank unaffected. Level 1 has 29 road tiles (art 73, 75, 76, 79-83); 198 of the 204 levels have roads. The level playthrough, `dock_check`, `ruin_access` (identical output before and after) and the real-scene autoplay all still pass.

## Not done / untraced

- **Whether the Tank, MSV and Heli drive handlers (`0x40c190`, `0x40cf...`, `0x40d0...`) have a road effect of their own:** they call the same speed function but do not read the mask; nothing else was seen. Their handlers were not re-read line by line for this.
- **The enemy AI's steering** (the both-keys channel through `state+0xb0`, `0x42d0a0` onward) is the original's AI controller, still the port's placeholder (`enemy_vehicle.gd`); this is the place to start when the AI is traced.
- The mask is applied with the port's continuous heading; the original's movement uses the heading's 64-step direction table, the assist itself works on the 22-bit angle as above.
- What the stale-mask-while-coasting rule looks like on a road's edge (a coasting Jeep that rolls off the road keeps steering with the last mask until the next throttle press) is reproduced but was not compared with footage.

**Next:** [the next-steps doc](NEXT_STEPS.md).
