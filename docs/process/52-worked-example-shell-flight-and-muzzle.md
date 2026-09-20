# 52. Worked example: where a shell starts, how it flies, and the muzzle flash

Document 51 could not play land/water/pavement impacts because it assumed a shot ends when it reaches the
ground. Reading the fire handler and the projectile update shows that is only true for some shots.

## The muzzle

`FUN_0040d240` (the Tank's fire handler, record `+0x17c`) builds the muzzle with `FUN_00402bf0(out, base,
offset, 1, pitch)`: the point `base = (0, -6.75, 0)` at `0x43e400` is rotated by the gun's pitch (about the
x axis, `FUN_0041ae10`) and then the vector `(0, -5.25, 7.0)` at `0x43e40c` is **added** (`FUN_00409b10`).
At level fire (pitch 0) that is `(0, -12, 7)`: **12 units in front of the vehicle's centre, 7 units up** (the
front is -y at heading 0; 12 is the hull's half-length, document 37). The vehicle's own position plus this
vector turned by the *turret* heading (`state+0x58` aim offset plus hull heading; the port has no separate
aim) is the shot's spawn point (`FUN_00415480`). The port's placeholder was 20 px.

Gun elevation is a separate state (`state+0x50`, moved toward 0 or `0x3b8e39` at `0x4ccc` per tick by
`FUN_004319e0`): fired with the alternate key (a negative slot argument) the handler waits for the gun to
reach `0x3b8e39` and then passes pitch `0x38e38f` (index 56 of the 64-step circle, 45 degrees up) to the
spawn; otherwise the shot is level. Not modelled.

## The flight

`FUN_004148f0` gives the shell `speed = entry[3]` and the velocity `(0, -speed, 0)` turned by the pitch
matrix (if any) and then the heading matrix (`FUN_0041e770`). Each tick `FUN_00414b10`:

- for a type without flag bit 1 (the Tank shell, type 0, flags 0) moves the shell's pitch toward 0 by
  `entry[10]` per tick (`FUN_004319e0`; 0.15 x 5.625 deg / tick for type 0) and recomputes the velocity
  from the pitch and heading -- there is no gravity term in these two functions, so a **level shot keeps
  the height it left the muzzle at (7)** and flies straight;
- for types with flag bit 1 (types 6 and 8) the pitch instead grows, bending the shot down in an arc;
- counts the lifetime byte down and, when it reaches zero, kills the shell with `FUN_0042c0f0` and
  **no effect**; only when the shell's height goes below 0 does it end with a surface code (land 0, water 1,
  pavement 2, document 50) and play an impact record; and a hit on an object or a tile ends it with code 3
  or 4 (`FUN_00414e60`, `FUN_00414dd0`).

So the Tank's ordinary shots never land: they end on something they hit, or vanish silently after 80 ticks.
The port already does exactly that (document 45); the land/water/pavement records are for arcing types and
the elevated shot, which are not implemented. (As read from these two functions; the generic mover
`FUN_0042c830` was not examined for a vertical term.)

## The muzzle flash

After spawning the shell the handler calls `FUN_0042e0b0(vehicle, owner, muzzle, &record 0x445138)`: an "Expl"
object attached to the vehicle (`FUN_0042cc50`) with the muzzle as its local offset (three signed bytes at
`+0x54..0x56`); `FUN_0042daf0` re-places it every tick at the vehicle's position plus that offset turned by
the vehicle's (turret) heading, and `FUN_0042e120` stores the pitch byte used to tilt it. The record is a
16-frame, 3-ticks-per-frame flash of cel 1746: a trapezoid on the ground plane extending 10.4 units forward
from the muzzle, fading from frame 10.

## Applied in the port

`Vehicle.MUZZLE_OFFSET_PX = 12` and `MUZZLE_HEIGHT_PX = 7`; the shell's picture is drawn 7 units up (level
flight); `ExplosionEffect3D.spawn_attached()` plays record `0x445138` following the firing vehicle. Verified
by screenshot with `RF_DEBUG_FIRE=1`: the flash at the barrel tip and a shell ahead of it.

## Not done

Elevated fire and the arcing types (6, 8); impacts on land, water and pavement (only reachable by them); a
turret aim separate from the hull; the collision shapes that decide when a level shot hits a tile or a
vehicle (still the placeholder radii); the muzzle flash of the Jeep, MSV and Heli (`0x4450d8`, `0x445168`
have their own handlers).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
