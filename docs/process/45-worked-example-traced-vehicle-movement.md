# 45. Worked example: tracing the Tank's movement constants

**Question:** how fast does the Tank drive, how quickly does it speed up and turn, and how hard does its shell hit?
[Document 44](44-worked-example-traced-world-scale.md) had dumped the Tank's *vehicle-type record* (a block of
constants per vehicle) but left it unlabelled, and `Vehicle.MAX_SPEED = 220` was a placeholder. **Method:** find the
function that reads the record, read it line by line, and label each field by what the function does with it.
Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: find who reads the record

The Tank record is at `0x4456b8`. Nothing points at it directly, so we searched the raw bytes for the pointer
value (`b8 56 44 00`, little-endian):

```bash
... -postScript FindBytes.java b8564400
```

The only hit is a 4-entry pointer table at `0x4452d8`: Tank, Jeep, MSV, Heli in that order (the records are
`0x2e8` bytes apart, `0x4456b8 + n*0x2e8`). Repeating the search for the *table's* address finds `FUN_0040b700`,
the vehicle spawn function. Reading it shows three things that matter:

1. it copies `0x50` dwords from record `+8` into a **state block** for the player, at `0x458100 + player*0x140`;
2. it stores the vehicle's **per-frame handler** in the state at `+0x10` (by default `FUN_0040c190`);
3. it copies several record fields onto the object itself.

So `FUN_0040c190` runs once per vehicle per tick. That is the function that turns the record's numbers into motion.

## Step 2: read the drive function

`FUN_0040c190(out_vector, obj, record, state)` decompiles to this (trimmed to the parts that matter; `param_2` is
the object, `param_3` the record, `param_4` the state, `DAT_00480d2c` the time step):

```c
uVar3 = *(uint *)(param_4 + 8);              // input flags for this tick (state+8)
uVar4 = *(uint *)(param_2 + 0x54);           // speed
local_c = *(uint *)(param_2 + 0x4c);         // heading
...
if ((uVar3 & 2) != 0) {                      // bit 1: accelerate
    uVar4 = uVar4 + param_3[0x5c] * DAT_00480d2c;          // speed += accel * dt
    uVar1 = FUN_00410b70(param_3[0x5a], local_8);          // limit = max_forward * scale
    if ((int)uVar1 < (int)uVar4) uVar4 = uVar1;            // clamp
}
if ((uVar3 & 4) != 0) {                      // bit 2: reverse / brake
    uVar4 = uVar4 - param_3[0x5c] * DAT_00480d2c;
    uVar1 = FUN_00410b70(param_3[0x5b], local_8);          // floor = max_reverse * scale
    if ((int)uVar4 < (int)uVar1) uVar4 = uVar1;
}
... turning: bit 3 adds, bit 4 subtracts  param_3[0x5e] * DAT_00480d2c to the heading (& 0x3fffff)
if ((uVar3 & 1) != 0) { ... move speed toward 0 by param_3[0x5d] * DAT_00480d2c }   // bit 0: friction
iVar2 = local_c >> 0x10;                     // heading index 0..63
*param_1   = dir_table[iVar2].x;  param_1[1] = dir_table[iVar2].y;
... each multiplied by (speed * dt)          // the movement this tick
```

Reading it gives the labels (`param_3[0x5a]` is dword 0x5a of the record, i.e. record offset `+0x168`):

| Input flag (`state+8`) | What the code does | Record field |
| --- | --- | --- |
| bit 1 | speed goes up by `accel * dt`, up to `max_forward * scale` | `[0x5c]` accel, `[0x5a]` max forward |
| bit 2 | speed goes down by the same amount, down to `max_reverse * scale` | `[0x5c]` brake, `[0x5b]` max reverse |
| bits 3 / 4 | heading turns one way / the other by `turn * dt` | `[0x5e]` |
| bits 3 and 4 together | `FUN_004319e0` steers toward a target heading at `state+0xb0`: the enemy AI's steering channel, not a player action (document 94) | |
| bit 0 | friction pulls speed toward 0 by `friction * dt` | `[0x5d]` |

The last lines look the heading up in a 64-entry table of unit vectors (built by `FUN_0041ae50`, entries `0x40000`
apart on a `0x1000000` circle). So **a heading is a 22-bit angle with 64 steps of 5.625 degrees**, and the movement
is `direction[heading >> 16] * speed * dt`.

**`scale`** comes from `FUN_0040c390` times `((byte)(state+0xb) + 1) * 0x100 / 65536`. The state byte is `0xff` for
a healthy vehicle, so that second factor is 1.0 (its meaning is untraced; it reads like a damage speed limiter).
`FUN_0040c390` returns: 1.0 in the air, **1.2** (`0x13333`) on the pavement tile ids `0x49-0x59` (renamed in document
44) and coastal ids `0x4a/0x4b`, 0.75 or 0.25 when state `+0x70` is set (what sets it is untraced), and 0.01 for a
pinned type-1 vehicle.

## Step 3: what is `dt`?

`DAT_00480d2c` is written in exactly one place, `FUN_0041d000`: the whole number of timer ticks since the last
frame, capped at 30. The timer is `FUN_00401110` = **`timeGetTime() >> 4`, so one tick = 16 ms (62.5 Hz)**. Document
18's "no fixed simulation tick" still holds: the game runs a variable number of 16 ms steps per frame, so speeds
do not depend on frame rate. Every per-tick value below converts with x 62.5.

## Step 4: convert the Tank's values

Dumping the record (`DumpDwords.java 0x4456b8 744`) and reading dwords `0x5a-0x5e` (all 16.16 fixed point: divide by
65536):

| Field | Raw | Value | Real units |
| --- | --- | --- | --- |
| max forward `[0x5a]` | `0x00010ccc` | 1.05 units/tick | 65.6 units/s (about 2.05 tiles/s) |
| max reverse `[0x5b]` | `0xffff999a` | -0.4 units/tick | 25 units/s |
| accel and brake `[0x5c]` | `0x00000ccc` | 0.05 units/tick^2 | 195 units/s^2 (full speed in 0.34 s) |
| friction `[0x5d]` | `0x00000666` | 0.025 units/tick^2 | 97.6 units/s^2 |
| turn `[0x5e]` | `0x00004000` | 0.25 steps/tick | 87.9 deg/s |

`game/vehicle.gd` now uses these. Before, it used 220 / 260 / 90 / 140 / 160, which made the Tank 3.4 times too
fast.

The other three vehicles have the same layout, at `0x4456b8 + n*0x2e8`:

| | Tank | Jeep | MSV | Heli |
| --- | --- | --- | --- | --- |
| max forward (units/tick) | 1.05 | 1.40 | 0.72 | 1.80 |
| max reverse | -0.4 | -0.8 | -0.3 | -0.6 |
| accel / brake | 0.05 | 0.05 | 0.04 | 0.02 |
| friction | 0.025 | 0.01 | 0.025 | 0.02 |
| turn (steps/tick) | 0.25 | 0.5 | 0.2 | 0.75 |
| forward, units/s | 65.6 | 87.5 | 45 | 112.5 |

The Jeep and Heli install their own drive handlers at record `+0x18`, so these numbers may not be the whole story
for them. The Tank and MSV use `FUN_0040c190` as read above.

## Step 5: the weapon slot and the shell

The record's weapon slots start at `+0x194`, `0x34` bytes apart. The fire handler is `FUN_0040d240` (record `+0x17c`)
and `FUN_0040c540` refills ammo. Per slot: `+0x00` projectile type, `+0x10` cooldown in ticks, `+0x14` maximum ammo.
Tank slot 0 = type 0, **cooldown 20 ticks (0.32 s)**, **150 rounds** (refilled 0.5 per tick on a rearm tile;
deliberately not modelled).

The projectile types are a table of 12 entries x `0x3c` bytes at `0x4489a0`. Spawn is `FUN_00415480`, setup is
`FUN_004148f0`. Reading what the shell code does with each field:

| Entry field | Meaning | Type 0 (the Tank shell) |
| --- | --- | --- |
| `+0x0c` | speed, units/tick | 3.0 (187.5 units/s) |
| `+0x24` | **damage**, handed to `FUN_0042e8c0` on hitting a tile (via `FUN_00414dd0`) | 1.0 |
| `+0x38` (low byte) | lifetime in ticks | `0x50` = 80 (1.28 s; a range of 240 units = 7.5 tiles) |

Speed / damage of the other types: 1: 2.5/2.0, 2: 2.3/4.0, 3: 6.0/1.0, 4: 4.0/1.5, 5: 3.0/1.0, 6: 3.0/4.0, 7:
3.0/1.0, 8: 2.3/2.0, 9: 2.3/2.0, **10: 3.0/400 (`0x1900000`, a super-weapon)**, 11: 3.5/0.95. Which vehicle slot fires
which type had only been read for the Tank at this point (the MSV's is in [document 58](58-worked-example-msv-rockets.md)).

A correction to an earlier note: `FUN_0042dcd0` is *not* the projectile hit callback. It is an explosion-object
callback. The projectile's own tile hit is `FUN_00414dd0`, so the damage above is the right field.

## Step 6: what a hit does to a tile

`FUN_0042e8c0` (all 91 coastal entries have armour threshold `E+0x20 = 0` and multiplier `E+0x24 = 0`, so armour
plays no part): a hit removes `max(1, damage >> 16)` from the 3-bit hit-point field (tile word bits 25-27), and the
tile is destroyed when its hit points are at most that amount. So a 6-HP candidate building (id 22) takes **six
Tank-shell hits** to become id 62; the port used to destroy it in one. `MatchController` now tracks per-tile hit
points. Checked by a scripted run: shots 1-5 leave 5, 4, 3, 2, 1 hit points; shot 6 destroys the building and
triggers the pool replacement.

## Applied in the port

`Vehicle`: the traced speeds, acceleration, friction, turn rate, and the 1.2x pavement cap (art ids `0x49-0x59`).
`Projectile`: 187.5 px/s, 1.28 s life, damage 1. `Vehicle.FIRE_COOLDOWN_SEC = 0.32`.

## Not done

- Ammo and rearm tiles; the "in water" speed cap (what sets state `+0x70` is untraced); auto-steer; the `+0xec` tilt
  smoothing.
- Jeep, MSV and Heli behaviour and weapon slots (later documents).
- Vehicle-vs-vehicle damage: solved in [document 47](47-worked-example-vehicle-damage.md) (hit points are record
  `+0x28`, not `+0xe8`).
- ~~The 62 -> 63 stage of a building.~~ Done (document 44, checked again in [document 93](93-worked-example-the-buildings-stages-checked-against-the-code.md)).
