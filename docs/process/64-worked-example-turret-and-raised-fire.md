# 64. Worked example: the Tank's turret, the raised gun, and the MSV's raised rocket

**Question:** the Tank's hull and turret are drawn as separate things (documents 39-42), and the original has a second
fire button whose shots the ground vehicles never used in the port. What moves the turret, what is the "raised" gun for,
and what does the MSV's raised rocket do? Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: find what writes the turret angle

Document 39 showed that the Tank's draw callback `FUN_00402dc0` draws the hull, then adds `state+0x58` to the draw heading
and draws the turret, using `state+0x50` for the barrel. So `+0x58` is the turret's angle from the hull and `+0x50` an
elevation. To find who writes them, we searched for stores (`FindDispOps.java 0x40b000 0x410800 "+ 0x58],"`): the writers
are the MSV's salvo counter (document 59), the Heli, and inits, but **nothing that looks like an aiming input**. The answer
is in the Tank record: its `+0x14` field (`0x40d430`) is a per-tick state handler, and it hands over to `0x40d460`. That
function was unrecognised by Ghidra; `DisasmForce.java 0x40d430 0x40d520` shows it:

```
0040d46b  AND EAX,0xd000                 ; the aim inputs: bits 0x1000, 0x4000, 0x8000 of state+8
0040d48b  CMP EAX,0x4000 ; JZ ...          ; 0x4000: target = state+0x58 - step   (turret left)
0040d495  CMP EAX,0x8000 ; JZ ...          ; 0x8000: target = state+0x58 + step   (turret right)
0040d49c  MOV [ESI+0x5c],0                 ; anything else of the three (0x1000): target = 0 (recentre)
0040d4b9  PUSH 0x4ccc ; ... FUN_004319e0(&state+0x58, target, 0x4ccc)   ; the turret follows its target
0040d4d1  ...        FUN_004319e0(&state+0x50, state+0x54, 0x4ccc)      ; the elevation follows ITS target
0040d4e3  CMP [ESI+0x60],0 ; JZ                                       ; a pending shot?
...       CALL 0x0040d240 (slot = elevation == 0 ? 0 : -1, keys 0x20)   ; fire when the elevation has arrived
```

`step` is `0x4ccc * dt` (0.3 of a 5.625-degree step, **1.69 degrees a tick, 105 degrees a second**), the same value as the
following rate; `FUN_004319e0` moves an angle toward a target by at most a rate the short way round the circle. So: **hold
turret-left or turret-right and the turret turns at 1.69 degrees a tick, all the way round; press the recentre input and it
goes back to 0; release and it stays where it is.** (0x4000 and 0x8000 are also the Heli's strafe bits, document 63.)

## Step 2: the fire handler and the second button

The Tank record's two fire handlers (`+0x17c`, `+0x180`) are both `FUN_0040d240`, with different slot arguments (`+0x188` = 0,
`+0x18c` = -1). Its decompile:

```c
if (param_4 < 0) {                       // the second button: -1 - slot is the slot
    param_4 = -1 - param_4;
    if (state[+0x54] == 0) { state[+0x54] = 0x3b8e39; if (state[+0x50] == 0) FUN_004319e0(&state[+0x50], 0x3b8e39, 0x4ccc); }
} else {                                  // the first button
    state[+0x54] = 0;  if (state[+0x50] == 0x3b8e39) FUN_004319e0(&state[+0x50], 0, 0x4ccc);
}
if (state[+0x50] == 0)            pitch = 0;                    // level
else if (state[+0x50] != 0x3b8e39) { state[+0x60] = 1; return 0; }   // the gun is still moving: ask again when it arrives
else                              pitch = DAT_00445484;         // raised (0x38e38f)
...  shot heading = obj.heading + state[+0x58]                    // the turret angle
     muzzle   = FUN_00402bf0(0x43e400 = (0, -6.75, 0), 0x43e40c = (0, -5.25, 7), pitch)
     proj     = FUN_00415480(obj.pos, muzzle, heading, pitch, type 0, team, obj)
```

`0x3b8e39` is **335 degrees: 25 degrees up**, and `0x38e38f` is 320 degrees: **40 degrees up**. So the first button fires
level from the muzzle `(0, -12, 7)` (12 ahead, 7 up: document 52), the second raises the gun to 25 degrees (15 ticks) and
fires the same shell 40 degrees **up**; the gun stays raised until a level shot is asked for. The muzzle of a raised shot is
`(0, -6.75, 0)` turned by -40 degrees plus `(0, -5.25, 7)`: 10.4 ahead and 11.3 up.

## Step 3: why a shell fired upward matters

Document 52 found that a non-ballistic projectile's pitch shrinks toward 0 at the type's rate and that its velocity uses the
pitch's table row (`pitch >> 16`, a 5.625-degree step, rounded down). Type 0 has a rate of `0x2666` = 0.15 step a tick, so
starting at row 56 (-45 degrees) it climbs less steeply each tick and levels off after about 50 ticks. The projectile update
(`FUN_00414b10`, decompiled in the scratch notes of document 63) also caps the height: `0x370000 < z + dz` sets `z` to
**55** and, for a non-ballistic type, pulls the pitch toward 0 at its rate. A scripted run: the raised shell reaches z 50 at tick
25 and 55 at the ceiling, then flies level. **55 is exactly the altitude band of the Heli (50 + its 10-high shape): the raised
gun is the anti-aircraft gun.** In the port a raised shell that meets a vehicle at height 50 hits it, a level one cannot.

## Step 4: the MSV's rack and rocket (`FUN_00402ec0`, `FUN_0040d520`)

The MSV has the same elevation machinery (its state handler `0x40d790` follows `state+0x54` with `FUN_004319e0` at `0x4ccc`),
no turret, and the same two buttons. Its rocket code (decompiled, document 58) picks type `(pitch == DAT_0044548c) + 8`: **type
8 level, type 9 raised**. The raised pitch is `0x38e38f` (40 up), the level pitch `0x4f5c` (1.744 degrees down).

- **The launch points** are `FUN_00402bf0(0x43edb8, 0x43ed90 + salvo * 12, count 2, pitch)`: the two points `(0, -15, -1)` (rocket) and
  `(0, 1.5, -1)` (back-blast) are turned by the pitch about the lateral axis (the matrix of `FUN_0041ae10`: a row vector `(x, y, z)`
  becomes `(x, y cos - z sin, y sin + z cos)`) and then the salvo's offset `(-1.5 / 0 / 1.5, 6, 12)` is added. **Level** this gives
  the `(x, 8.96 ahead, 10.54)` of document 58, so that trace is confirmed. **Raised** it gives `(x, 6.13 ahead, 20.88)`.
- `FUN_00415480` then turns a type's `(x, y, 0)` by the pitch's table row for types with flag bit 0 (types 8 and 9), and adds
  the height back. With row 56 that puts the raised rocket at `(x, 4.34 ahead, 25.21)`. (A double rotation, but it is what the
  code does; level it is the identity.) The back-blast is at `(x, 6.5 behind, 10.3)`.
- **The rack** (`0x43ed30`, 8 corners, 4 for the plate and 4 for the canister strip) is recomputed every frame as
  `R(elevation) * base + (0, 6, 12)`, where `(0, 6, 12)` is the dword triple at `0x43ed9c`. **This corrects
  [document 59](59-worked-example-vehicle-part-animation.md), which had assumed an offset of 11.25:** the steady canister strip
  spans y 0 to 6 (corners 48/49 at `-n`, 50/51 at 6, where `n` runs -6 to 0 while reloading) and the plate y -2.25 to 7.5.

Type 9 (speed 2.3, damage 2.0, lifetime 90, non-ballistic rate `0x1c28` = 0.11 step a tick) climbs like the Tank's shell: a
scripted run reaches z 55.

## Applied in the port

`Vehicle` has `turret_deg`, `gun_elev_deg` and the pending-shot logic for the Tank and MSV: `Q` / `E` turn the turret, `R` recentres it,
`Space` fires level and `Z` fires raised (port keys; the enemy AI has none of them). The shot heading includes the turret; a raised
Tank shell or MSV rocket is a pitched projectile (`Projectile.start_pitched`, with the ceiling of 55). `VehicleBoxRender3D`
turns the whole turret about the vertical axis and rebuilds the barrel panels and the muzzle ring from
`R(elevation) * base + offset` (the tables of document 40) for a raised gun; `VehicleRender3D` builds the MSV's plate and canisters from
`tools/data/vehicle_types.json` (`rack`) with the elevation. Checks: a scripted run (turret 50.62 degrees after 30 ticks of the key,
0.3 steps x 5.625 x 30 = 50.6; the raised Tank shot comes 15 ticks after the press with heading 50.6, pitch 40 up, height 11.34; the level
MSV rocket keeps the traced `(8.96, 10.54)` and the raised one leaves at `(4.34, 25.21)`); screenshots of the turret at 60 and -70 degrees
with the gun level and raised, and of the MSV rack level and raised; and a raised Tank shell that reaches a vehicle at height 50 hits it
while a level one does not.

## Not done / to trace

The Tank's turret does not yet reach the enemy AI or a second player; the ammo counts; the **sounds**; the recentre input's meaning
(`0x1000`: any of the three bits that is not exactly left or right recentres); the exact stopping of the turret when the key is released
(the target set one step ahead is reached in a tick, as coded); the shot's flash follows the turret (its yaw is passed) but its exact
placement for a raised gun follows the muzzle only.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
