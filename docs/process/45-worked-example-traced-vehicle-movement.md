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

## Not done

- Jeep / MSV / Heli have their own records at the same offsets (untraced values); `Vehicle` and
  `EnemyVehicle` still use the Tank's.
- Road 1.2x and water penalties (need a terrain lookup in `Vehicle`), auto-steer, and the `+0xec`
  smoothing (a second, tilt-like value eased by the per-type pair at `0x4453a8`).
- Weapons (damage, cooldown, projectile speed) are in the same records; still placeholders.

Tooling added: `tools/ghidra_scripts/FindDataWrites.java` (only WRITE xrefs to an address, then
decompiles the writers) -- the quickest way to find where a runtime-initialised global such as the
tick scale or the heading table is set.
