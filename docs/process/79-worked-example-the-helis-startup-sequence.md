# 79. Worked example: the Heli's start-up (the last of "the docking animations")

**Question:** documents 77 and 78 traced docking, undocking and the hangar screen. Document 63's "Still open" list named one more piece: *"the Heli's start-up (gear, rotor spin-up, the folded rotor of mode 4, the base
glide) are not modelled: it flies at once."* Since a Heli is created fresh every time it is undocked (document 77), its start-up is the last of "the docking animations" the user asked for. Field names and scripts are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: finding it — the record's other function pointer

Document 45 already named record `+0x18` the **drive** handler (`FUN_0040e0e0` for the Heli, document 63's flight model) and record `+0x14` went unidentified. Dumping the four vehicle records at `+0x14` (`DumpDwords.java 0x4456b8 2980`):

| type | `+0x14` |
| --- | --- |
| Tank | `0x40d430` |
| Jeep | `0x40d920` |
| MSV | `0x40d760` |
| **Heli** | **`0x40e8c0`** |

Ground vehicles' `+0x14` handlers are single small routines; the Heli's is the head of a **four-stage chain**, each stage overwriting the object's own state-handler pointer (`state + 0xc`) to move to the next:
`0x40e8c0 -> 0x40e930 -> 0x40e9c0 -> 0x40eab0`. `+0x14` only runs **once, right after the object is created** (document 76/77's `FUN_0042c290`/`FUN_0040b700`), so this chain is exactly a start-up sequence.

## Step 2: the four stages (disassembled: `DisasmForce.java 40e8c0 40eab0`)

```c
// stage 1 (0x40e8c0): silent blade acceleration
state.5c = 0;
state.58 += dt * (1179/65536);                 // ~0.018 a tick
if (state.58 > 0x10000 /* 1.0 */) {
   sound(0x44b550);                             // once
   obj.model = table_0x4460b8[team];             // swap to the spinning-rotor draw descriptor
   state.58 = 0x10000;
   state.c = 0x40e930;                           // -> stage 2
}

// stage 2 (0x40e930): the rotor visibly ramps up
state.84 += dt * (1638/65536);                  // ~0.025 a tick -- THE SAME FIELD document 63 already reads
if (state.84 >= 0x40000 /* 4.0 */) {             // as "4 steps of 5.625 degrees a tick" for the LIVE rotor
   obj.model = table_0x4460b8[team];
   state.c = 0x40e9c0;                           // -> stage 3
   state.84 = 0x40000;
}
sound(5, obj, once=1);                           // an engine/rotor loop, started here
state.80 = (state.80 + state.84 * dt) & 0x3fffff;  // the rotor keeps turning all the while

// stage 3 (0x40e9c0): the collision-safe climb to hover height, then hand off
dz = min(dt * (0x8000/65536), 0x320000/65536 - obj.z);   // clamps the climb step to the 50-unit ceiling
FUN_0042c830(obj, &dz);                          // move up, blocked by anything solid above
if (obj.z >= 50.0) { obj.z = 50.0; state.70 = 0; caller.c = 0x40eab0; caller.88 = 0; }  // released: -> stage 4
else { ... bank/pitch offsets from tables 0x4454a0 / 0x4454d8 indexed by floor(state.84) ... }
state.80 += state.84 * dt;                        // still turning

// stage 4 (0x40eab0): steady state for the rest of the Heli's life
state.80 = (state.80 + state.84 * dt) & 0x3fffff; // just keeps the rotor spinning; everything else is the drive handler
```

`0x8000/65536 = 0.5` a tick and the ceiling `0x320000/65536 = 50.0` are exactly document 63's already-known **climb rate and ceiling** (`HELI_CLIMB_PER_TICK`, `HELI_CEILING`), so **stage 3 is the climb the port already had** — it was simply never gated behind
stages 1 and 2. Table `0x4454a0`/`0x4454d8` (bank/pitch offsets by rotor speed, a little bob while climbing) is **not modelled** (cosmetic, low priority). `0x4460b8` is a small per-team model-swap table (two entries, tan/green), the same trick document 78's dock
object and document 63's dying Heli use to change which draw descriptor an object points at; here it is always the ordinary flying model (nothing suggests a distinct "folded rotor" cel set exists, contrary to document 63's guess).

## Step 3: what this means in order

1. **~55.6 ticks (0.89 s), silent**: the Heli sits exactly where it was created (z = 0), rotor motionless, no control.
2. **~160 ticks (2.56 s)**: the rotor visibly speeds up from a standstill to full speed (state `+0x84`, 0 to 4.0); still no movement or weapons.
3. **As soon as the rotor is at full speed**, the existing climb (document 63) takes over on its own and raises it to 50 units.
4. **The whole thing runs every time a Heli is created** — at match start (if a level ever starts one) and, per document 77, every time one is undocked.

## Applied in the port

`Vehicle.heli_spinup_stage` / `_heli_spinup_progress` / `rotor_speed_steps`, started by `_start_heli_spinup()` (called from `_apply_type()` when `vehicle_type == 3`, and from `respawn()`), gate `_process_heli` for stages 1 and 2 with the traced rates
(`HELI_SPINUP_A_RATE = 1179/65536`, `HELI_SPINUP_B_RATE = 1638/65536`); once `rotor_speed_steps` reaches 4.0 the existing climb and flight code run unchanged. `game/vehicle_render_3d.gd`'s rotor now integrates `rotor_speed_steps` directly (replacing the old fixed-speed
formula), so it visibly speeds up instead of starting at full spin. Checked by `tools/tests/heli_spinup_check.gd`: stage 1 ends at tick 55 (traced ~55.6), stage 2 at tick 216 (traced ~215.6), and z stays 0 throughout both (thrust held the whole time has no effect) then
climbs on its own; by two screenshots of a docked Heli mid-spin-up (grounded, rotor at one angle) and after (airborne, rotor at another); and by the existing test suite and the level 1 playthrough, unaffected.

**A pre-existing bug fixed along the way:** `tools/tests/ammo_check.gd` positioned its vehicle at `(2160, 2160)`, which is exactly level 1's home pad centre (tile 67, 67) — since document 77 added docking, holding fire there now docks instead of firing, and every
vehicle read 0 shots. Moved the test's position off the pad.

**Not done:** the bank/pitch bob of stage 3 (tables `0x4454a0`/`0x4454d8`), the sound cues (the sound pass), and whether `0x4460b8`'s second entry is ever actually a different (folded) model — nothing seen so far suggests it is.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
