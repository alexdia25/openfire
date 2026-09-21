# 61. Worked example: the Jeep's "gun" is a lobbed missile that picks its own target

**Question:** what does the Jeep's weapon do? Document 57 listed a "machine gun" (`FUN_0040df00` -> `FUN_00415b00`)
and a homing missile object (`0x448c70`) as separate untraced items. Reading them shows they are **one weapon**: the
Jeep fires a missile that is lobbed in an arc onto a target the game chooses. Field names and scripts are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: which handler, and its numbers

The Jeep record (`0x4459a0`, dumped with `DumpDwords.java 0x445b1c 64`) has the three button handlers at `+0x17c` /
`+0x180` / `+0x184` = `0x40df00`, `0x40dfe0`, `0x40e070` (dispatch as in [document 60](60-worked-example-mines.md) step 1).
Button A is `0x40df00`. Its weapon slot 0 (`+0x194`) reads: offsets `(0, 0, 5.0)` at `+4/+8/+0xc`, **cooldown `0x1e` = 30
ticks**, **ammo 16** (not modelled, by your decision). `FUN_0040df00`:

```c
if (keys & 0x20) == 0 return;                    // button A
if (now <= state.ready) return;
if (ammo < 1) { click sound; return }            // empty
if (FUN_00415b00(obj, slot+4, record, state)) {  // aim and fire
    state.ready = now + cooldown;  ammo -= 1;
```

## Step 2: choosing the target (`FUN_00415b00`)

Its decompile reads as a priority list (`0x3d3ab7` = 61.23 units in 16.16, `FUN_0042cd70` = distance):

1. **The enemy vehicle** (`DAT_0048c7b8[team ^ 1]`) if its height is below 5.0 and it is within 61.23 units.
2. Else **the last tile that blocked this vehicle** (state `+0xa4`, written by the vehicle's tile callback `FUN_0040c130`)
   if the tile still has hit points (tile word bits 25-27) and is within 61.23 units; its centre is taken with the same
   decoration jitter as the collision code.
3. Else **the last enemy-team object it touched** (state `+0xa8`) if closer than that tile.
4. Else **a random point ahead**: a heading step `heading_index + rand(0..7) - 4`, at `0x30 + rand(0..14)` = 48-62 units
   (`FUN_0041d3d0(n)` = `(rand & 0x7fff) * 2 * n >> 16`).

## Step 3: launching (`FUN_004159a0`) and the arc (`FUN_00415730`)

The missile is object class `0x12` (`0x448c70`; priority 200; init `0x4156e0` does nothing; update `0x415730`; tile
callback `0x4158f0`; object callback `0x415940`; destroy `0x4156f0`). Launch stores the start point (vehicle position +
the slot's `(0, 0, 5.0)`), a time counter `+0x68 = 0`, a spin `+0x4c = 0`, and two computed values. Reading the disassembly
(`DumpDisasm.java 0x004159a0 0x00415ab0`) with the helper functions (`0x410c10` is `a / b` in 16.16, `0x410e20` is a fixed
square root, `0x43d008` = 65536.0):

```
EAX = whole distance D to the target            ; FUN_0042cd70 >> 16
speed  v = sqrt( 3276 * D / 0xb504 )            ; PUSH 0xb504 ; PUSH 3276*D ; FUN_00410c10 ; FUN_00410e20
heading = atan2(start - target) >> 2 - 0x100000, then the 64-step table index (>> 16)
```

The update (decompiled) then places it, with `t` the whole ticks since launch (`+0x68 += dt`):

```
x, y = start + dir[heading] * ( v * 0x61f7/65536 * t )                     // 0x61f7 = 0.38269
z    = start.z + ( v * 0xec83/65536 - 0x666/65536 * t ) * t               // 0xec83 = 0.92387, 0x666 = 0.024994
```

A launch at 67.5 degrees with gravity 0.025 per tick squared, so it flies for `t = 36.96 v` ticks and covers `14.14 v^2`
units, and `v = sqrt(D / 14.14)` (since `3276 / 0xb504 = 0.0707 = 1 / 14.14`) makes that exactly `D`: **the missile lands on
the target point.** The heading is rounded *down* to one of 64 steps of 5.625 degrees (the `>> 16`), so it lands up to a few
units to one side; the 5.0 launch height adds about 2 units of range. It spins 3 degrees a tick (`+0x4c += 0x8888` of `0x400000`)
and its animation counter `+0x70` grows `0x2aaa` per tick, wrapping at 12.0.

## Step 4: what it hits

- Its collision shape (`0x454310`) is the shell's: type 4 swept point, layer 4, mask `0x43`, **z +-1.5 about its current
  height**. So it hits whatever solid it passes through at that height, on the way down or up (vehicles and building or
  palm shapes, per [document 53](53-worked-example-collision-shapes.md)).
- **Object callback `0x415940`:** ignores the object it was launched from (`obj+0x2c`); otherwise calls the other object's hit
  callback with damage **`0x18000` = 1.5**, destroys itself and records impact 3 (the object-hit explosion, the same as a
  shell's `0x444b68`).
- **Tile callback `0x4158f0`:** `FUN_0042e8c0` with 1.5, destroys itself, impact 4 (`0x444ac8`, the same as a shell's).
  (Document 45: a hit removes `max(1, whole damage)` hit points, so 1.5 removes 1.)
- **Landing (z < 0):** if nothing was hit, destroy handler `0x4156f0` spawns the record `0x448988[impact]`: **0 ground
  `0x444840`, 1 water `0x4445e8`, 2 the pavement tiles (art `0x49`-`0x53`) `0x444a30`**. The water test (`FUN_0042f280`)
  is untraced, so water counts as ground here.

## Step 5: its art

Descriptor `0x4548f0`: one part, cel `0x6f3` = 1779 with flag 8, corners x -2.7..0, y -2.7..2.8 (drawn as read: a
2.7 x 5.5 quad). Its init callback `0x436be0` sets the draw variant to `frame + 12 * (team != 0)` where `frame` is
`whole(obj+0x70)`: so **cels 1779-1790 are 12 spin frames for the tan team and 1791-1802 for green**. The registry had them
as `decoration.camo_mound`; they are now `projectile.jeep_missile.<team>.NN` (hand-edited plus `classify_batch2.py`, as the
standing rule says; only frame 1 is marked code-verified, the rest by the same descriptor). The shadow is an attached
object of class 4 (`0x443078`, init `FUN_00409b50`) placed at (x + z, y + z) on the ground with cel `0x434` = 1076, the same
shadow cel as the shell's. The mine's cels 1081-1083 were also tightened in the registry (document 60).

## Applied in the port

- `Projectile` gets a lob mode (`start_lob`: the distance, speed, heading rounding and the two formulas above; `lob_frame`,
  `spin_deg`); `MatchController._pick_missile_target` (rules 1, 2 and 4; rule 3 needs vehicle-vs-object contact, which is
  not modelled), `_missile_lands`, and `_on_vehicle_shot` handles the new `kind = "missile"`. The Jeep records the tile that
  last blocked it (`last_blocked_tile`).
- `Vehicle` (type 1): the space bar fires every 30 ticks; `ProjectileBillboard3D` draws the spinning quad at its height with the
  ground shadow.
- Checked by a scripted run: free flights land `D` plus 1-4 units away (2.3 at 60 units) in 79 ticks with a 41-unit apex; the
  controller picks a blocked building's centre as the target from 45 units away, the missile removes 1 hit point (6 to 5) and
  plays the tile-hit record; the random fallback stays within 48-62 units.

## Not done / open

Ammo (16) and the empty click; the last-touched-object rule and vehicle-vs-vehicle contact; the water landing record; the missile's
sound (`0x44b9ec` table); whether the half-width quad (x -2.7..0) is drawn mirrored by the draw function `0x41b750` (it draws the
descriptor's corners after rotating them, nothing more was found); a Jeep-vs-enemy check in the running game (this level has no
enemy vehicles); the second and third buttons (`0x40dfe0`, the water mode, and `0x40e070`, the flag action of document 57).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
