# 87. Worked example: a vehicle's dying/wreck sequence

**Question:** on death the port just hides the vehicle and drops a flat Tank-shaped decal at its feet
(`game/wreck_3d.gd`, document 48). NEXT_STEPS named "a vehicle's dying/wreck sequence is not modelled
for any type" as one of the three biggest remaining mechanics, alongside the Heli's landing sequence
(document 86) and on-foot infantry. This is the first real trace of the death path since document 47.

## Step 1: the death branch, read precisely

Document 47 already found `FUN_0040c460` (the hit callback, `vehicle class 0x445438+0x3c`) spawns a
wreck object at `hp <= 0`. Decompiling it in full this time:

```c
undefined4 __cdecl FUN_0040c460(int param_1,undefined4 param_2,int param_3)
{
  piVar1 = *(int **)(param_1 + 0x60);      // state
  iVar2 = *piVar1;                         // the vehicle's own type record
  if (param_3 - piVar1[7] < 1) return 0;   // damage <= armour: no-op
  piVar1[0x13] = DAT_00480d38 + 10;        // hit-flash timer
  iVar3 = piVar1[8] - (param_3 - piVar1[7]);
  piVar1[8] = iVar3;                       // hp -= damage - armour
  if (0 < iVar3) {                         // still alive
    if (*(code **)(iVar2 + 0x238) == 0) return 0;      // no per-type reaction -> stop here
    iVar3 = (**(code **)(iVar2 + 0x238))(param_1,iVar2,piVar1,param_2);
    if (iVar3 == 0) return 0;
  }
  piVar4 = 0;
  if (*(int *)(iVar2 + 0x234) == 0) {                  // "dying handler" (always 0, all 4 types)
    if ((*(byte *)(param_1 + 0xc) & 0x80) == 0) {
      piVar4 = FUN_0042c290(0x4453e8, param_1[0x10], param_1[0x40], param_1[0x44], param_1[0x48], param_1);
      FUN_0042c4d0((int)param_1);                       // flag the vehicle itself for destroy
    }
  } else { piVar1[3] = *(int *)(iVar2 + 0x234); piVar1[8] = 0; }
  if (piVar4 != 0 && piVar1[8] < -0x280000) piVar4[3] |= 0x2000000;  // hp < -40: an extra flag
  return 2;
}
```

`+0x234` reads 0 for **all four** vehicle types (dumped directly: Tank/Jeep/MSV/Heli all zero), so
every type takes the same "spawn wreck class `0x4453e8`, destroy self at once" path -- there is no
per-type "dying handler" branch after all, despite document 47's table implying one might exist.

**Correcting document 63:** it claimed the Heli's dying handler lived at `record+0x234` (value
`0x40eae0`). Re-checked directly: `+0x234` is 0 for the Heli too. The real value `0x40eae0` sits at
`+0x230` instead (confirmed by scanning all initialised memory for that pointer -- it appears exactly
once, at `0x4461a0` = Heli record `+0x230`), and it is 0 for the other three types. `0x40eae0` itself
is tiny -- it pushes shadow descriptor `0x440ed8` and calls the shadow-spawner `FUN_00409c50` (matches
document 63's own finding about who creates a shadow for a dying Heli) -- so `+0x230` is a genuine
**Heli-only extra hook**, just not the generic "dying handler" `+0x234` is. What actually sits at
Heli's `+0x238` (document 47's "hit-reaction callback") is a *different*, always-present-for-Heli
function, `FUN_0040e830`, decompiled below.

## Step 2: what `+0x238` actually does (not a death override)

```c
undefined4 __cdecl FUN_0040e830(undefined4 p1,undefined4 p2,int obj,int hitter)
{
  obj->0x8c = (rand16(0x180)+rand16(0x180)-0x180) * 0x80;   // a random lean jitter
  if (hitter != 0) {
    // ...a second random jitter into obj->0x98/0x9c, direction-scaled by a lookup table...
  }
  return 0;                                                  // ALWAYS 0
}
```

Since it always returns 0, `FUN_0040c460`'s `if (iVar3 == 0) return 0;` always fires -- a Heli that
survives a hit never falls through to the wreck-spawn code underneath. This is just a hit-reaction
wobble (the Heli visibly jerks when shot), not a death override; `+0x234` staying 0 for every type is
the real, final word on "does anyone get a special dying handler" -- no.

## Step 3: what descriptor is drawn while the wreck falls

The wreck's update, `FUN_0040c8f0` (document 45's decompile, re-read here), swaps the drawn
descriptor to the type record's `+0x164` once the object lands. Before that it draws whatever is
already set from creation -- traced by dumping the type record's own `+0x148` field for all four
types and running `DumpDescriptorParts.java` on each:

| Type | `+0x148` (falling) | Parts |
| --- | --- | --- |
| Tank | `0x43ea18` | the SAME 14-part hull descriptor as the live Tank body (cels 167-212) |
| Jeep | `0x43fd78` | the live Jeep body (11 parts, cels 417-457) |
| MSV | `0x43f358` | the live MSV body (14 parts, cels 279-324) |
| Heli | `0x440b70` | the live Heli body (12 parts, cels 524-574) -- also the "body" cel document 63's dying-composite dispatcher (`0x42eae0`) draws alongside the shadow and the stopped rotor |

So **a dying vehicle tumbles down showing its own intact model**, not a distinct "wreck" sprite --
the flat decal only appears once it lands. `+0x164` (the landed decal) was already traced by document
48; re-running `DumpDescriptorParts.java` on it confirms that table exactly, and additionally shows
the MSV's "large" decal is numerically the **same size** as the Tank/Jeep's (both ±12/±13.5 units) --
"large" is just the registry's category name, not a bigger decal -- and the Heli's single decal
(`0x440fa0`, cel 606) is a **27.2 x 54.4 unit rectangle offset 13.6 units off-centre**, not a symmetric
square like the other three.

## Step 4: a contradiction found, not resolved

Wanting the actual fall physics (gravity, an initial velocity `FUN_0040c7e0` sets unconditionally at
`+0x6c` = `0xc0000` = 12.0), tracing led to `FUN_0040c8f0`'s own early-out:

```c
if ((code *)param_2[6] == 0) { FUN_0042c0f0(param_2); return; }  // no mover -> ???
(*(code *)param_2[6])();                                          // otherwise: move, then land-check
```

`param_2[6]` (`+0x18`) is populated once, at creation, by the generic allocator `FUN_0042c290`:
`piVar8[6] = *(int *)(class_addr + 0x1c);` -- and the wreck class's own `+0x1c` reads as **0**. That
implies a fresh wreck's mover is always null, so it should take the "no mover" branch on its very
first tick -- and `FUN_0042c0f0` looks like a generic *immediate* object-teardown routine (it clears
the pending-destroy bit, unlinks from destroy/tick lists, and pushes the object onto the free list
`FUN_0042c290` itself pops from). Taken at face value this says a wreck destroys itself the instant
it's created, which cannot be right for an object that is supposed to sit on the ground indefinitely.

Something in this chain is very likely mis-identified -- six or seven pointer hops deep is exactly
where an indexing slip creeps in -- but re-deriving it from scratch was not done this session. Rather
than ship a made-up "confirmed" set of fall constants on top of an unresolved contradiction, this is
flagged as **open** (see NEXT_STEPS) and the applied fall below is explicitly a guess, not a trace.

## Applied in the port

- `Vehicle._die()` (replacing three duplicated `alive = false; destroyed.emit(self)` sites: hit-point
  death, and both ground/Heli fuel-out deaths, which document 55 already said "is destroyed like at 0
  hit points") emits a **new** `wrecked(info: Dictionary)` signal with a value snapshot
  (`position`/`heading_deg`/`team`/`vehicle_type`/`z`) *before* `alive = false` and `destroyed`. This
  matters because the player's vehicle is one persistent node reused across lives: `destroyed`'s own
  listener (`MatchController._on_player_destroyed`) calls `respawn()` **synchronously**, which would
  reset `position`/`z` on the same node before a `destroyed`-based wreck spawner could read them.
  `wrecked`'s snapshot is a plain Dictionary, copied by value, so it is immune to that.
  ```gdscript
  func _die() -> void:
      wrecked.emit({"position": position, "heading_deg": heading_deg, "team": team, "vehicle_type": vehicle_type, "z": z})
      alive = false
      destroyed.emit(self)
  ```
- `game/wreck_3d.gd` now takes `vehicle_type` and `start_height`, picks the traced per-type decal set
  (Tank/Jeep/MSV share geometry, only textures differ; the Heli gets its own off-centre rectangle),
  and -- given step 4's unresolved contradiction -- falls the flat decal itself from the death height
  using the project's already-traced ballistic gravity (`LOB_GRAVITY`, documents 52/61) with zero
  initial velocity, a **guessed interpolation**, not the original's own timing:
  ```gdscript
  func _process(delta: float) -> void:
      if not _falling: return
      var ticks := delta * TICK_HZ
      _vz -= GRAVITY * ticks
      _height += _vz * ticks
      if _height <= 0.0:
          _height = 0.0
          _falling = false
      position.y = _height
  ```
  A ground vehicle (height 0 at death) never enters the falling state at all -- no change from before.
  A Heli shot down mid-flight now visibly drops its wreckage from wherever it died instead of an
  instant flat decal appearing in mid-air.
- `game/terrain_view_3d.gd` connects `wrecked` (not `destroyed`) to spawn the `Wreck3D`.
- Verified by `tools/tests/wreck_fall_check.gd`: a Tank killed with a `destroyed`-triggered respawn
  attached shows the `wrecked` snapshot is unaffected by that respawn (still the death-moment position,
  not `(999, 999)`); its wreck never enters the falling state (height 0). A Heli killed at height 60
  shows a real ~69-tick fall to height 0. Screenshots (`RF_DEBUG_WRECK=1`, extended to drop one of each
  type, the Heli from height) confirm the four decals render correctly, including the Heli's large
  scattered-debris art (traced back to the atlas: cel 606 genuinely is a wide debris-field image, not
  a rendering bug) and the fall being visibly in progress at an early frame.

## Still open

- The tumbling intact-body render during the fall (step 3) and the Heli's trailing shadow object
  (`+0x230`) are **not** reproduced -- the port only falls the final flat decal, a deliberate scope
  cut given step 4's contradiction already put the fall's own correctness in doubt.
- Step 4's contradiction itself: which pointer hop is mis-identified, and what the wreck's real fall
  timing/initial velocity is.
- The `0x2000000` flag (set on the wreck when hp goes below -40, or -- in `FUN_0040c8f0`, reusing the
  same bit -- on a hard landing) is written twice but never found to be *read* anywhere; it likely
  selects a bigger effect on landing, not traced further.
- `FUN_0040c460`'s death branch has **no sound call at all** -- contrary to NEXT_STEPS' earlier guess
  that the dying/wreck sequence was "the most likely home for `ExplDebris`/`ExplLow`", neither cue's
  trigger is here. That guess is now retracted; both remain unwired.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
