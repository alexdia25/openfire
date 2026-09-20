# 45. Worked example: tracing the Tank's movement constants

[Document 44](44-worked-example-traced-world-scale.md) ended with the Tank's vehicle-type record
dumped but unlabelled, and `Vehicle.MAX_SPEED = 220` still a placeholder. This document labels the
movement fields by reading the function that consumes them.

## Finding the consumer

Nothing references the Tank record (0x4456b8) directly; it is reached through a 4-entry pointer table
at `0x4452d8` (Tank, Jeep, MSV, Heli in that order -- `FUN_0040b510` special-cases index 3). Searching
the raw bytes for the pointer (`FindBytes.java b8564400`) gave the users: `FUN_0040b700` (vehicle
spawn) copies `0x50` dwords from record `+8` into a per-player state block at `0x458100 + player *
0x140`, stores the object's update handler at state `+0x10` (default `FUN_0040c190`), and copies
several record fields onto the object. `FUN_0040c190` is the per-frame drive function.

## What FUN_0040c190 does

`(state_out_vec, obj, type_record, state)`; `obj+0x54` = speed, `obj+0x4c` = heading, `state+8` =
input flags.

| Flag (`state+8`) | Effect |
| --- | --- |
| bit 1 | accelerate: `speed += rec[0x5c] * dt`, capped at `rec[0x5a] * scale` |
| bit 2 | reverse/brake: `speed -= rec[0x5c] * dt`, floored at `rec[0x5b] * scale` |
| bit 3 / 4 | turn one way / the other by `rec[0x5e] * dt` (heading wraps at `0x3fffff`) |
| bits 3+4 | `FUN_004319e0`: steer toward a target heading at `state+0xb0` (auto-steer) |
| bit 0 | friction: `speed` moves toward 0 by `rec[0x5d] * dt` |

Then the position delta is `dir[heading >> 16] * speed * dt`, where `dir` is a 64-entry table of unit
vectors (`FUN_0041ae50`, 0x40000 apart over a 0x1000000 circle), so **heading is 22-bit fixed: 64
steps of 5.625 degrees**.

`scale` is `FUN_0040c390(obj, rec, state)` times `((byte)(state+0xb) + 1) * 0x100 / 65536` (the state
byte is 0xff for a healthy vehicle, so this factor is 1.0; its meaning is untraced but it reads like
a damage speed limiter). `FUN_0040c390`: 1.0 when airborne, **1.2** (`0x13333`) on tile terrain
ids 0x49-0x59 (the pavement cels renamed in document 44) and coastal ids 0x4a/0x4b, 0.75 / 0.25
(Jeep-type) when the state's `+0x70` is set (looks like "in water"), 0.01 when a type-1 vehicle is
pinned.

## The tick

`dt` is `DAT_00480d2c`, written only in `FUN_0041d000`: the whole-number count of timer ticks since
the last frame (capped at 30), from `FUN_00401110` = **`timeGetTime() >> 4`, i.e. one tick = 16 ms
(62.5 Hz)**. Document 18's "no fixed simulation tick" still holds: the simulation runs a
variable number of 16 ms steps per frame, so speeds are frame-rate independent.

## Tank values (type record `+0x168..+0x178`)

| Field | Raw | Value | In real units |
| --- | --- | --- | --- |
| max forward `[0x5a]` | `0x00010ccc` | 1.05 units/tick | 65.6 units/s (~2.05 tiles/s) |
| max reverse `[0x5b]` | `0xffff999a` | -0.4 units/tick | 25 units/s |
| accel + brake `[0x5c]` | `0x00000ccc` | 0.05 units/tick^2 | 195 units/s^2 (full speed in 0.34 s) |
| friction `[0x5d]` | `0x00000666` | 0.025 units/tick^2 | 97.6 units/s^2 |
| turn `[0x5e]` | `0x00004000` | 0.25 steps/tick | 87.9 deg/s |

`game/vehicle.gd` now uses these (previously 220 / 260 / 90 / 140 / 160 -- the Tank was 3.4x too
fast, which is why it looked huge-strided now that its size is traced).

## The other three vehicles (same offsets, same units)

| | Tank | Jeep | MSV | Heli |
| --- | --- | --- | --- | --- |
| max forward (units/tick) | 1.05 | 1.40 | 0.72 | 1.80 |
| max reverse | -0.4 | -0.8 | -0.3 | -0.6 |
| accel / brake | 0.05 | 0.05 | 0.04 | 0.02 |
| friction | 0.025 | 0.01 | 0.025 | 0.02 |
| turn (steps/tick) | 0.25 | 0.5 | 0.2 | 0.75 |
| forward, units/s | 65.6 | 87.5 | 45 | 112.5 |

(Read from the four records at `0x4456b8 + n*0x2e8`; the Jeep and the Heli install their own drive
handlers at record `+0x18`, so these values may not be the whole story for them. The Tank and MSV
use the default `FUN_0040c190`.) `Vehicle` still hard-codes the Tank's.

## Weapons: the Tank shell

The record's weapon slots start at `+0x194`, stride `0x34`; the fire handler is `FUN_0040d240`
(record `+0x17c`) and `FUN_0040c540` refills ammo. Per slot: `+0x00` projectile type index,
`+0x10` cooldown in ticks, `+0x14` maximum ammo. The Tank's slot 0 = type 0, **cooldown 20 ticks
(0.32 s)**, **150 rounds** (refilled at 0.5 round/tick while on a rearm tile; not modelled).

Projectile types are a table of 12 entries x 0x3c bytes at `0x4489a0`, spawned by `FUN_00415480`
and initialised by `FUN_004148f0`:

| Entry field | Meaning | Type 0 (Tank shell) |
| --- | --- | --- |
| `+0x0c` | speed, units/tick | 3.0 (187.5 units/s) |
| `+0x24` | **damage** passed to `FUN_0042e8c0` on hitting a tile (`FUN_00414dd0`) | 1.0 |
| `+0x38` (byte) | lifetime in ticks | 0x50 = 80 (1.28 s, range 240 units = 7.5 tiles) |

Other types' speed/damage: 1: 2.5/2.0, 2: 2.3/4.0, 3: 6.0/1.0, 4: 4.0/1.5, 5: 3.0/1.0, 6: 3.0/4.0,
7: 3.0/1.0, 8: 2.3/2.0, 9: 2.3/2.0, **10: 3.0/400 (0x1900000, a super-weapon)**, 11: 3.5/0.95.
Which vehicle slot fires which type is only read for the Tank.

Earlier this document's predecessor flagged `FUN_0042dcd0` as the projectile hit callback. It is
not: it is an *explosion-object* callback (damage -(speed x dt) per tick from `obj+0x58`'s record).
The projectile's own tile hit is `FUN_00414dd0`, so damage is the entry field above.

## Tile hit points, completed

`FUN_0042e8c0` (all 91 coastal entries have armour threshold `E+0x20 = 0` and multiplier
`E+0x24 = 0`): a hit removes `max(1, damage >> 16)` from the 3-bit hit-point field (tile word bits
25-27), and the tile is destroyed when its hit points are <= that amount. So a 6-HP candidate
building (id 22) takes **six Tank-shell hits** to become id 62; before, the port destroyed it in one.
`MatchController` now tracks per-tile hit points and subtracts `Projectile.damage_hp`, verified by a
scripted run: shots 1-5 leave 5..1 HP, shot 6 destroys and triggers the pool replacement.

## Applied in the port

`Vehicle`: traced speeds/accel/friction/turn, plus the 1.2x pavement cap (art ids 0x49-0x59).
`Projectile`: 187.5 px/s, 1.28 s life, `damage_hp = 1`. `Vehicle.FIRE_COOLDOWN_SEC = 0.32`.

## Not done

- Ammo (150, rearm tiles) and the muzzle offset; the state-flag "in water" speed cap (what sets
  state `+0x70` is untraced); auto-steer; the `+0xec` tilt smoothing.
- Jeep/MSV/Heli behaviour in the port (they aren't playable here), and their weapon slots.
- Vehicle-vs-vehicle damage (health `+0xe8` = 100/250/?/200 looks like hit points; untraced).
- The 62 -> 63 stage of a building.
