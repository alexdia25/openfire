# 60. Worked example: the MSV's mines and the explosion damage box

**Question:** how does the MSV lay a mine, what does a mine do, and how does its explosion hurt things? Document 50
had found the one explosion that damages anything (record `0x445058`) and guessed it belonged to a mine, without
tracing what spawns it. Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: which button lays a mine

The per-tick weapon dispatch is in `FUN_0040b980`'s neighbour at `0x40bfbe-0x40c026`. Reading its disassembly
(`DumpDisasm.java 0x0040bf90 0x0040c130`) shows three buttons, each testing a group of bits of the input flags
(`state+8`) and calling a handler stored in the vehicle's record:

```
0040bfc1  TEST AL,0xe0          ; bits 5-7   -> handler [record+0x17c], slot [record+0x188]
0040bfe2  TEST AH,0x7           ; bits 8-10  -> handler [record+0x180], slot [record+0x18c]
0040c007  TEST AH,0x38          ; bits 11-13 -> handler [record+0x184], slot [record+0x190]
```

For the MSV (record `0x445c88`, dumped with `DumpDwords.java 0x445df8 60`) the handlers are `0x40d520` (rockets) for
the first two and **`0x40d820` for button C, with slot 1**. Slot 1 of the record's weapon table (`+0x194 + 1*0x34`)
reads: offsets `0` and `5.0` at `+4` / `+8`, **cooldown `0x8c` = 140 ticks** at `+0x10`, **ammo 10** at `+0x14`.

## Step 2: what `FUN_0040d820` does

```c
if ((keys & 0x60) != 0 && 1 < DAT_00442fbc) {
  slot = record + 0x194 + slot_no*0x34;  st = state + 0x24 + slot_no*0x10;
  if (st[+8] < now && st[+0xc] > 0 && state[+0x70] != 2) {            // ready, has ammo, not in deep water
    idx = obj[+0x4c] >> 16;                                          // heading step
    x = dir[idx].x * slot[+4]  + obj.x;
    y = dir[idx].y * slot[+8]  + obj.y;
    mine = FUN_00409e30(x, y);                                       // create; refused on deep water
    if (mine) { st[+0xc] -= 1;  st[+8] = slot[+0x10] + now; }
```

`FUN_00409e30` checks the terrain at the spot (`FUN_0042f410 == 2` refuses) and spawns class `0x4430c8`.
**Quirk kept as coded:** the x offset field is 0 and the y field is 5.0, and each is multiplied by the matching
component of the heading's unit vector. So the mine lands `5 * dir.y` units away in y only: 5 units ahead of a
vehicle facing along y, and exactly on top of a vehicle facing along x. (We cannot tell whether the original meant a
rotated offset; the code does not.)

## Step 3: the mine object (class `0x4430c8`)

Dumping the class table (`DumpDwords.java 0x4430c8 24`) gives: init `0x409ca0`, destroy `0x409d80`, update `0x409cd0`,
draw descriptor `0x454200`, **priority `0x96` (150)**, object-collision callback `0x409dd0` (`+0x38`), hit callback
`0x409e00` (`+0x3c`). None of these are recognised functions, so they were read with `DisasmForce.java` (the decompiler
gave the smaller ones):

- **Init:** state (draw variant, `obj+0x10`) = 0, age `obj+0x60` = **5.0**, blink counter `obj+0x5c` = 0, plays a sound.
  The object's descriptor (`obj+0x3c`, copied from the class's `+0x14`) is `0x454200`, whose shape-chain field (`+8`)
  is **0**: with no shapes, the collision code (`FUN_0042bd40`, and the loop in `FUN_0042bb10` that runs `FUN_0041e4c0`)
  never reports a hit. So a fresh mine is **inert**.
- **Update:** `age += 8738 * dt` (raw 16.16, so 0.1333 per tick); the blink counter counts ticks and wraps at 30; the
  variant is **2 while whole(age) > counter, else 0**, and a beep plays on each switch to 2. When age reaches **26.0**
  (about 158 ticks) it does `obj+0x3c = 0x4542c8`, calls `FUN_0042c250`, and sets the variant to 1. Descriptor
  `0x4542c8` is a copy of the mine's with `+8` = `0x454288`: **a shape chain**. From then on the mine collides. So the
  fast-beeping blink is a **fuse that speeds up** (5 of every 30 ticks lit at first, 25 of 30 at the end), and the
  steady variant 1 means **armed**.
- **Destroy** (`0x409d80`): only if flag `0x200` is set (set by the two callbacks below) it spawns explosion record
  `0x445058` at its position. An armed mine stays until something sets it off.
- **Collision callback** (`0x409dd0`): if the other object's class is 1 (a vehicle), set flag `0x200` and destroy.
- **Hit callback** (`0x409e00`): if the damage is **above 1.5** (`0x18000`), do the same.
- **Art:** descriptor `0x454200` is one quad, cel `0x439` = 1081 with flag 8 (+ variant), corners +-6 in x and y at
  z = 1. The three cels are 8 x 8 "ember" sprites: a small blinking light on the ground.

**Shapes (armed only).** The chain from `0x454288` holds a 12 x 12 box (layer 1, mask 6) and, linked from it, the 32 x 32
box at `0x454248` (layer 1, mask 2); both span z from -50 to 0.1. Who triggers it, using the pair rule of
[document 53](53-worked-example-collision-shapes.md): a vehicle (layer 2) touches either box; a shell (layer 4) could only
touch the small one, but a shell flies at z 7, above the boxes' 0.1 top, so **level shots never touch mines**.

## Step 4: who calls which callback

`FUN_0042bb10` (read in full) decides between two overlapping objects by the classes' priorities at `+0x30`: the
callback of the *higher*-priority class runs, unless it has none. Vehicles have priority 100, mines 150, explosions
200. So a vehicle (the mover) touching a mine runs the **mine's** callback (`0x409dd0`); an explosion box touching a
vehicle runs the **explosion's** (`0x42dd20`). Only a *mover* is tested (`FUN_0042bd40`), so a vehicle that stands
still on a mine does not set it off, but one that starts to move does.

## Step 5: the damage box (records op 13 and 14)

The explosion class (`0x44bb70`, priority `0xc8` = 200) runs its script every tick (`FUN_0042dbe0`), and ends when
its progress reaches the record's duration (the box is freed in `FUN_0042dca0`). The ops that make the box:

- **Op 13, `FUN_0042d640`**: allocates a box object; `DAMAGE_BOX z_lo z_hi width height mask damage` becomes a type-2
  shape with z from `z_lo` to `z_hi`, half-width `width/2`, half-height `height/2`, **layer 0x20**, the given mask,
  and the damage rate stored at `+0x68`.
- **Op 14, `FUN_0042d710`**: `BOX_EXTENT n` sets x, y and z to +-n.

For record `0x445058` the script is `DAMAGE_BOX -4 4 8 8 0x43 -1`, sound, `WAIT 4`, `BOX_EXTENT 25`, (one tick) `BOX_EXTENT
12`, `WAIT 8`, `BOX_EXTENT 16`, `WAIT 12`, `BOX_EXTENT 20`, end; progress advances 1/6 per tick and the duration is 25,
so the explosion lasts **150 ticks (2.4 s)**: the box is +-4 for the first 24 ticks, +-12 until progress 8, +-16 until
12, then +-20 to the end.

**Damage.** The box's object callback `FUN_0042dd20` passes `|rate| * dt` to the victim's hit callback (`-1` in the op =
1.0 per tick; `dt` is the whole ticks since the last frame), and its tile callback `FUN_0042dcd0` passes the same to the
tile damage function of document 45. The vehicle rule of document 47 then applies: a Tank (armour 0.3) loses 0.7 per
tick, an MSV (0.5) loses 0.5, and sitting in the box is fatal within a second or two. **Which things a box can touch:**
it needs each side's mask to contain the other's layer. Vehicles (layer 2, mask `0x27`) and every tile shape (layer 1,
mask `0xff`) qualify; mines (masks 2 and 6, no `0x20`) do not, so **explosions do not set off other mines**.

## Applied in the port

- `game/mine.gd` (age, blink, beep, arming, and the trigger boxes), `game/mine_view_3d.gd` (the quad),
  `game/explosion_box.gd` (the timeline of the box, mirroring the script runner of `explosion_effect_3d.gd`).
- `Vehicle` (MSV only): key `M` (or `RF_DEBUG_MINE=1`) lays a mine every 140 ticks at the traced offset.
- `MatchController`: mines age; any moving vehicle overlapping an armed mine's trigger box sets it off; the explosion
  plays record `0x445058` and its box damages vehicles and tile shapes every tick (a building with 6 hit points falls
  in six ticks). `_damage_tile` now takes an amount.
- Checked by a scripted run: a drop facing east lands on the vehicle, one facing south 5 units ahead; a mine arms after
  158 ticks with 6 beeps; **a vehicle that keeps driving over its own fresh mine does nothing until the fuse ends**;
  armed, a stationary vehicle on it does not set it off but the first movement does, and the vehicle then loses 0.5 hit
  points per tick until it is gone. Screenshots: the unlit mine on the ground, and an explosion with the vehicle in its
  hit flash.

## The dropper question (resolved)

Document 60's first version kept a placeholder: it assumed a mine started colliding at once, so the MSV laying it would
set it off the moment it moved (the code has no owner rule). Reading the creation function (`FUN_0042c290`) and the
mine's descriptor showed the real mechanism: the mine has **no collision shapes for its first 158 ticks**, so the
dropper, which lays it inside its own shape and drives away in well under 2.5 s, is never in danger unless it stays
or comes back. The placeholder and its debug switch were removed.

## Open questions

1. **The offset quirk** of step 2 is reproduced as coded.
2. **Explosion clock.** `FUN_0042dbe0` has a first-tick special case (`flag 0x40` sets the progress to 1.0); the port's
   explosions (documents 50-51) start at 0, so the box timeline is up to 1 progress unit (6 ticks) late if the flag is set
   for this object. Not checked.
3. Not modelled: ammo (10), the deep-water refusal, the sound, the elevated rocket and everything the Jeep and Heli
   add.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
