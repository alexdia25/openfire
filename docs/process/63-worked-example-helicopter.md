# 63. Worked example: the helicopter (flight, guns, bombs, rotor)

**Question:** how does the Heli fly and fight? Documents 45-62 traced the ground vehicles; the Heli (vehicle type 3) has
its own drive handler, its own weapons and a rotor drawn by a separate object. Field names and scripts are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md). Everything below was read from disassembly or decompile; what is a choice of
the port rather than a trace is said so.

## Step 1: what is in the Heli's record

The Heli record is `0x4460b8` (`DumpDwords.java 0x4456b8 744`, the row for type 3). The fields that matter:

| Offset | Value | Meaning |
| --- | --- | --- |
| `+0x18` | `0x40e0e0` | **drive handler** |
| `+0x14` | `0x40e8c0` | spawn / start-up handler (step 6) |
| `+0x168..0x178` | 1.8, -0.6, 0.02, 0.02, 0.75 | max forward, reverse, accel, friction, turn (units/tick, steps/tick) |
| `+0x17c`, `+0x180` | `0x40e600` | the two fire buttons |
| `+0x184` | `0x40e7a0` | third button: switch weapon |
| `+0x194` slot 0 | type 7, cooldown 15, ammo 100 | gun; mount offsets `(0, -12, 8)` (unused, see step 4) |
| `+0x1c8` slot 1 | type 6, cooldown 30, ammo 50 | bomb |
| `+0x4c` | 0 | **no water handler**: the Heli is never asked whether it is over water |

## Step 2: the drive handler `FUN_0040e0e0`

Decompiled. Compared with the ground handler of [document 45](45-worked-example-traced-vehicle-movement.md):

- **Speed** changes the same way (accelerate, brake, friction, no terrain factor).
- **Turning** does not change the heading directly: an angular velocity `state+0x8c` follows a target of +-0.75 steps a tick
  (record `+0x178`) at `0x7ae` = 0.03 per tick per tick when it is building up, at `0x1eb8` = 0.12 when it slows or reverses
  (the two constants at `0x445498` / `0x44549c`, `FUN_0042cdd0` is "move toward by at most"). The heading grows by the
  angular velocity each tick. A full turn-rate takes about 25 ticks to reach and 6 to stop.
- **Strafing**: two more input bits (`0x4000`, `0x8000`) move it sideways at `0xcccc` = 0.8 units a tick along the heading
  turned by -+16 steps (90 degrees). Turning has priority over strafing.
- **Velocity** is smoothed: the velocity it actually moves with (`state+0x98/0x9c`) follows the sum of the forward speed
  (along the heading rounded down to one of 64 steps) and the strafe at `0x7ae` = 0.03 a tick per tick.
- **Altitude:** `z` grows by `0x8000` = 0.5 a tick up to `0x320000` = **50.0** and stays there; nothing in this handler ever
  lowers it.
- **Tilt:** `state+0x88` (the bank) follows +-3 steps while turning or strafing (+-`0x30000`), at `0x147a` = 0.02 a tick, and
  decays at `0x28f4` = 0.16; the turn bank is multiplied by the speed when the speed is below 1.0, so a hovering
  Heli does not bank. `obj+0x70` is set to `1.5 x speed` in steps: the nose-down pitch (15 degrees at full speed).
  `FUN_0041b590` builds the drawing matrix from these two angles, then the heading.
- Random values written to `state+0x90/0x94` while it hovers (a wobble) are not used by anything read so far.

Because it flies at z 50 and its shape is 0-10 high above that, **it clears every building (up to 34) and cannot be hit by
level fire**: the collision test of document 53 needs the heights to overlap. While it climbs (the first 100 ticks) it can
still bump into tall tiles. The port shifts the shape's heights by `z` in the tile and vehicle blocking tests for this.

## Step 3: the rotor

The Heli's draw descriptor (`0x440b70`, twelve parts of the body) has a next-link at `+4` (found in document 48) pointing
at the rotor descriptor `0x440708`. Its init callback `0x403350` copies the parent's heading, pitch (`obj+0x70`), bank
(`state+0x88`) and **rotor angle `state+0x80`** into the rotor's draw object, and picks a mode from the **rotor speed
`state+0x84`**: `whole(speed) - 1`, clamped to 0-3, or 4 while the start-up value `state+0x58` is below 1. The draw callback
`0x403420` chooses one of three corner sets by the mode: mode 0-1 `0x440558` (blade 6.8 wide), 2 `0x4405e8` (13.6), 3 `0x4405a0`
(27.2), all 54.4 long at height 10; mode 4 draws a separate folded pair (`0x4406c0`). The two parts are the halves of one bar:
cel 584 + team for y from -27.2 to 0, cel 580 + team for 0 to 27.2. So a fast rotor is the same 32 x 8 blade art stretched to
four times its natural width (a blur), spinning. During flight the speed is `0x40000` = 4.0 (the start-up handler at
`0x40e930` ramps `state+0x84` up to it and adds it to the angle each tick: **4 steps of 5.625 degrees a tick**), so mode 3.
The Heli's shadow art (cel 579 and the rotor-spin frames) is covered under "Shadows" below: **a live Heli has none**.

## Step 4: the weapons `FUN_0040e600`

```c
if ((keys & 0x60) == 0) return;
slot = (obj[+0xc] & 0x10000000) >> 28;                     // which weapon: 0 gun, 1 bomb
if (ready[slot] < now) {
  if (ammo[slot] < 1) { click; ready = now + cooldown; return }
  mount = (obj[+0xc] & 0x8000000) ? 0x440f20 : 0x440f38;   // left or right
  heading = param4 == 0 ? obj.heading : ((bit27 == 0 ? -0x40000 : 0) + 0x20000 + obj.heading);   // toe-in of 0.5 step
  obj[+0xc] ^= 0x8000000;                                  // alternate the mounts
  if (type == 7 && param4 != 0) param4 = 0x71c71;          // pitch 7 steps
  proj = FUN_00415480(obj.pos, mount, heading, param4, type, team, obj);
  if (obj.speed > 0) FUN_004155a0(proj, obj.speed);        // add the launcher's speed
  if (type == 6) flash record 0x445168 at mount + 3 ints
```

The mounts (`DumpDwords.java 0x440f20 12`) are `(-9.35, -6.8, 0)`, `(-9.35, -2.55, 0)`, `(9.35, -6.8, 0)`, `(9.35, -2.55, 0)`: gun
positions 9.35 to each side and 6.8 ahead (original y is minus forward); the flash of a bomb is drawn at the second triple of its
side. The two fire buttons pass different fourth arguments (the record's `+0x188` = `0x3fffff` for the first, `+0x18c` = 0 for the
second): with the first the guns are toed in and depressed **39.4 degrees**, with the second everything flies level. `FUN_0040e7a0`
(third button) toggles bit 28 and plays a sound.

**Projectile motion for pitched shots** (`FUN_004148f0`, `FUN_00414b10`, both in [document 52](52-worked-example-shell-flight-and-muzzle.md)'s
family): the velocity is `(0, -speed, 0)` turned by the pitch and then the heading, so it goes `speed * cos(pitch)` along the
heading and drops `speed * sin(pitch)` a tick. A type without the ballistic flag keeps its pitch (the table index is `pitch >> 16`,
i.e. rounded down to a step) and moves it toward 0 by the type's rate (0 for type 7: constant); a ballistic type (bit 1: type 6,
rate 0x6666 = 2.25 degrees a tick) has its pitch **grow** each tick, bending it down. Positive pitch is downward (the MSV's
raised gun is 315 degrees, document 58). A shot with z < 0 has hit the ground and plays its type's impact record by what is
under it (document 61). Type 7 is the Tank-shell art with damage 1.0; type 6 is the rocket-like art with damage 4.0.

Checked by a scripted run: from z 50 a gun round lands **62.6 units ahead after 27 ticks** at pitch 39.4 degrees; a bomb dropped
level lands **70.7 ahead after 31 ticks** (z 43.6, 26.6, 1.5 at 10, 20, 30 ticks); three gun shots in 40 ticks alternate right,
left, right with headings -2.8, +2.8, -2.8 degrees; the switch selects the bomb with its flash.

## Applied in the port

`Vehicle` type 3 runs `_process_heli` (all of step 2, with the water handler skipped as its record has none); `Space` fires the
downward buttons, `Z` the level ones, `X` switches weapon (port keys), `Q`/`E` strafe, `F4` and `V` reach the Heli, `RF_VEHICLE=heli`
starts as one. `Projectile` gained pitched flight; `MatchController` handles the launch fields and the ground impact; both
renderers draw the height, and `VehicleRender3D` tilts the whole Heli by its pitch and bank, spins the rotor at 4 steps a tick and draws
the rotor (no shadow: see "Shadows"). A screenshot shows the banked Heli with its blurred rotor and dust puffs where its rounds
land.

## Choices that were checked afterwards

Three things were first chosen "for realism" and were then traced (2026-09-21, at your request that nothing be left as our own choice):

- **The lean signs.** `FUN_0041b590` builds two matrices (`0x458c38` for the pitch, `0x458c60` for the bank) and `FUN_00410c60`
  multiplies a point (a row vector) by a matrix. Reading the stores: the pitch matrix is `[1 0 0; 0 c s; 0 -s c]`, so a nose point
  `(0, -1, 0)` (forward is minus y) goes to height `-s`: **a positive pitch (the speed's) dips the nose**. The bank matrix is
  `[c 0 s; 0 1 0; -s 0 c]`, so a right-hand point `(1, 0, 0)` goes to height `+s`: **a negative bank lowers the right side**,
  and a right turn sets a target of `-3` steps. The heading matrix table (`FUN_0041ae50` at `0x41aea0-0x41af3f`) is
  `[c s 0; -s c 0; 0 0 1]`, which turns `(0, -1, 0)` into `(sin, -cos, 0)`: heading grows clockwise, x is to the right.
  So the Heli rolls into the turn and dips its nose, exactly as drawn.
- **The rotor's direction:** its angle goes through the same heading-matrix table, so it turns clockwise as its angle grows.
- **The shadow's place.** Every shadow object (class 4, `0x443078`) is moved each tick by `FUN_00409bd0` to the parent's position
  plus **(0.332 x height, -0.5 x height)** (`85 * (z >> 8)` and `-(z / 2)`). The earlier "+height in both" belonged to its init
  function only, and had also been used for the Jeep missile; both now use the traced offset, and shells' shadows (drawn straight
  below before) are offset the same way (2.3, -3.5 at their height 7).

## Shadows: a double check (2026-09-21) found that a flying Heli casts none

The port drew the Heli's body shadow (cel 579) under it. Checking who creates shadow objects:

- `FindPointerRefsMulti.java 443078` (the shadow class) finds exactly four creators: the projectile init `FUN_004148f0`, the missile
  `FUN_004159a0`, an unrelated spawner at height 50 (`FUN_0040a7b0`, class `0x443838`) and **`FUN_00409c50`**, which takes an object and a shadow
  descriptor. `FindCallRel.java 409c50` (a new script that finds `E8` calls even in code Ghidra never disassembled) finds **one caller: `0x40eaed`,
  inside the Heli's dying handler `0x40eae0` (record `+0x234`), which pushes the descriptor `0x440ed8`.** Nothing creates a shadow
  for a Tank, Jeep, MSV or a live Heli.
- The other references to the shadow descriptors agree: `0x440ed8` (draw callback `0x403760`) is used only by that call and by the wreck-draw
  dispatcher `0x42eae0`, which draws `0x440ed8`, the body `0x440b70` and the stopped rotor `0x4406c0` for a *dying* vehicle;
  `0x403760` itself reads the parent's rotor speed and start-up state and picks `0x440e90` (cel 579 with the rotor-spin frames 589-605
  of `0x440da8`, chosen by the rotor angle) once the speed is 4.0 or more, else shifts its corners by `18 x (1 - state+0x58)`.

So the shadow (body and rotor frames) belongs to the **dying Heli sequence**, which is not modelled; a live Heli casts nothing, exactly like the
ground vehicles. The port's Heli shadow was removed. (The rest of the dying sequence, from `0x40eae0`, is open: see below.)

## What is still a choice or missing

- **Port keys** (Space, Z, X, Q, E): the original reads input bits; which physical key sets them is the port's business.
- **Not done:** the start-up sequence at the base (the state handlers at `0x40e8c0`, `0x40e930`, `0x40e9c0`: gear, rotor spin-up,
  modes 0-2 and the folded mode 4 of the rotor), the landing at the base and leaving the vehicle (`0x40eb00`, `0x40eb40`: it turns to a
  fixed heading of 24 steps and glides onto the tile centre), the hover wobble, the dying handler (`0x40eae0`, record `+0x234`),
  auto-steer, ammo (100 / 50) and sounds. The Heli starts flying at once, and it can only be shot by weapons that reach z 50
  (the Tank's raised gun and the MSV's raised rocket, [document 64](64-worked-example-turret-and-raised-fire.md), reach it).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
