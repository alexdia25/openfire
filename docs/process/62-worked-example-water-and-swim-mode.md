# 62. Worked example: water, sinking, and the Jeep's swim mode

**Question:** what does the original do when a vehicle is over water, and what is the Jeep's second button for?
Earlier documents met the pieces without tracing them: the "in water" speed caps (document 45), deep-water sinking
(document 47), the mine's deep-water refusal (document 60), the missile's water landing (document 61). This document
traces the rule they all call. Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: what is "in water"?

The Jeep's second button handler `FUN_0040dfe0` (record `+0x180`) begins with `FUN_0042f280(obj)`; the vehicle's
per-tick code stores the same answer in state `+0x70` (`0x40c038`). Its decompile is a chain of tests on the terrain
tile under the object (art id = tile word `& 0x7f`, coastal decoration id = `(word & 0x3f80) >> 7`):

```
if height > 1.0                      -> 0   (in the air)
if art > 0x33 or coastal 0x4a/0x4b   -> 0   (land, and the pavement pieces)
art 1 -> 1     art 2 -> 2     art < 4 -> 0
art < 0x18   (shore pieces 4-23)     -> shape test (below)
art < 0x28                           -> 1
art 0x28-0x33                        -> the object's point in a box around the tile centre ? 1 : 2
```

So **0 is land, 1 shallow, 2 deep**. The terrain names agree (document 44: cels 1, 2 and 24-51 are open water, 4-23 the
sand/water coast pieces). `FUN_0042f410` is the same test for a bare point (used for mines).

**The shore pieces** use a table at `0x44de10 + art * 8` (`DumpDwords.java 0x44de10 52`): a flag byte, a rotation byte and a
shape pointer. The shapes (`0x44dc70`, `0x44dcf0`, `0x44dd70`, `0x44ddf0`) are polygons of 5-6 corners in tile
coordinates (dumped from `0x44dc28`, `0x44dcb0`, `0x44dd30`, `0x44ddb0`); the rotation byte is in steps of 5.625 degrees, so
`0x10` is a quarter turn. The vehicle's own shape is tested against the polygon at the tile centre with `FUN_0041e060` (the
geometry test of document 53, no layer or height check): **with the flag set an overlap means shallow, with it clear NO
overlap means shallow**, otherwise land. The boxes for arts `0x28-0x33` are at `0x44ded0 + (art - 0x28) * 0x10` (x0, y0,
x1, y1 from the tile centre; a point-in-box test `FUN_0041d5b0`). Everything is in `tools/data/water_tables.json` (script
`extract_water_tables.py`) and `game/water.gd` implements the chain.

## Step 2: sinking (`FUN_0040cef0`, `FUN_0040cf90`, `FUN_0040d150`)

The vehicle's water handler (state `+0x44`, copied from record `+0x4c`) is one of three functions that hand over to each
other. Decompiled:

- **`0x40cef0` (dry):** deep water (2) and not a Jeep in swim mode (`record[0] == 1 && state+0x84 == 1.0`) -> switch to the
  sinking handler and the sinking descriptor (`record+0x154`). In any water, moving faster than half the water-scaled top
  speed -> the wading handler and descriptor (`record+0x14c`).
- **`0x40cf90` (sinking):** on land (0) -> back to dry, height 0. In shallow water, or a swimming Jeep -> the height rises
  0.4 a tick (`0x6666`) back to 0. **In deep water the height falls 0.4 a tick; when `z >> 16 <= -(depth >> 16)` the
  vehicle is destroyed** (`FUN_0042c4d0`) and record `0x444ee8` plays at its position.
- **`0x40d150` (wading):** a splash counter (`+0x48` grows 0.2 a tick); cosmetic.

The depth is record `+0x158`: **Tank 14, Jeep 13, MSV 14, Heli 14** (`0xe0000`, `0xd0000`, ...). So a vehicle that drives into
deep water is gone after about 35 ticks (0.56 s), unless it turns back to shallows in time.

## Step 3: swim mode (`FUN_0040dfe0`) and its ramp (`FUN_0040d990`)

```c
if (button A pressed):
  cls = FUN_0042f280(obj)
  if (cls != 0 && state[+0x84] == 0)      { state[+0x84] = 1.0; return }   // enter swim mode in any water
  if (cls != 2 && state[+0x84] == 1.0)    { state[+0x84] = 0;   return }   // leave it, but not in deep water
```

The Jeep's per-tick state function `FUN_0040d990` (disassembled at `0x40d990`) first does:

```
0040d99c  MOV EDI,[ESI+0x80]      ; immersion
0040d9a2  MOV EDX,[ESI+0x84]      ; target (0 or 1.0)
0040d9a8  CMP EDI,EDX ; JZ done
0040d9af  AND [ESI+8],0xffffffe1  ; clear the accelerate, brake and turn bits
0040d9b8  OR  [ESI+8],1           ; set the friction bit
...       FUN_0042cdd0(EDI, EDX, dt*1092)  ; move immersion toward the target by 1092/65536 a tick
```

So the immersion (`+0x80`) takes about a second to reach 1.0, and **while it is changing the Jeep cannot accelerate
or turn**. The speed caps of document 45 come from `FUN_0040c390`: in any water 0.75 of the top speed; for a Jeep whose
immersion is 1.0, **0.25** in water and **0.01** on dry land (so it must leave swim mode). Which is why the mode exists: a
Jeep in swim mode is the only vehicle that can cross deep water (slowly).

## Step 4: the Jeep's own drive handler (`FUN_0040db80`)

Disassembled (`DisasmForce.java 0x40db80 0x40dd60`), it is the drive function of document 45 with these differences that
matter: **when a turn key is held and neither throttle key is, it acts as if accelerate were pressed** (`TEST BL,6 ... TEST BL,0x18
... OR EBX,2`, and it drops the friction bit), and the friction is skipped while turning. The rest (rates from record
`+0x168..0x178`, the terrain scale, the 22-bit heading step) is the same. It also smooths a tilt value (`state+0xe8/0xec`), which
is cosmetic and not modelled.

## Applied in the port

- `game/water.gd` (the chain of step 1); `Vehicle` recomputes `water_class` every frame, runs the sinking states of step 2
  (its height `z` goes into both renderers, so a sinking vehicle drops out of sight; `drowned` fires at the depth and
  the controller respawns the player, as it does for a destroyed one; the scene plays record `0x444ee8`, no wreck), the swim flag
  and ramp of step 3 with the input lock, the speed caps of `FUN_0040c390`, and the Jeep's throttle-when-turning rule.
- Key `B` toggles swim mode (`FUN_0040dfe0`; a port key). A mine is refused in deep water (`FUN_0040d820`/`FUN_00409e30`), and a
  missile that lands in water plays record `0x4445e8` (document 61). Shells are tested against the vehicle's shape shifted by
  its height.
- Checked by a scripted run on RFMAP001 (15272 of its 16384 tile centres are deep water, 480 shallow, 632 land): a Tank
  placed in deep water sinks to -12.8 and is lost at 35 ticks; a Jeep toggles into swim mode in deep water, the immersion
  reaches 0.5 after 30 ticks and 1.0 after 60, the scale is 0.25 in water and 0.01 on land; the toggle is refused in deep water
  and works again on land; a mine is refused in deep water.

## Not done

The Jeep's swim-mode drawing (the immersion row of the wheel table at `0x43fb78`, and the second descriptor `0x43fcb8` it
switches to above 3/8 immersion: wheels and hull change), the wading and sinking descriptors (`record+0x14c`, `+0x154`; the port
just lowers the vehicle), the wading splash, sounds, the ammo counts (16 missiles), the "last enemy object touched" target rule
and the Heli (it is never in water: its height is above 1.0).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
