# 85. Worked example: the Heli's rotor has four real modes, not one

**Question (user-flagged, 2026-09-22, from real gameplay footage):** "there are different textures used
when the helicopter is in full flight, we aren't using those here." Document 63 already traced and
applied the Heli's spinning rotor (`game/vehicle_render_3d.gd`'s `_build_heli_extras()`), so what's
actually different?

## Step 1: re-reading document 63's own trace, not guessing fresh

Document 63, "Step 3: the rotor", already has the answer, just not yet applied:

> The Heli's draw descriptor (`0x440b70`, twelve parts of the body) has a next-link at `+4` ... pointing
> at the rotor descriptor `0x440708`. Its init callback `0x403350` copies the parent's heading, pitch,
> bank and rotor angle into the rotor's draw object, and **picks a mode from the rotor speed `state+0x84`:
> `whole(speed) - 1`, clamped to 0-3, or 4 while the start-up value `state+0x58` is below 1.** The draw
> callback `0x403420` chooses one of three corner sets by the mode: mode 0-1 `0x440558` (blade 6.8 wide),
> 2 `0x4405e8` (13.6), 3 `0x4405a0` (27.2), all 54.4 long at height 10; **mode 4 draws a separate folded
> pair (`0x4406c0`)**.

`game/vehicle_render_3d.gd` had only ever implemented mode 3 -- the full-width blur -- unconditionally,
from the moment a Heli is created. That's *correct* once flying (document 63: "during flight the speed
is 4.0 ... so mode 3"), but wrong for the ~56-tick silent phase and the ~160-tick ramp that document 79
already traced and applied to the *state* (`Vehicle.heli_spinup_stage`, `rotor_speed_steps`) without
ever wiring it to the *renderer*. So a freshly spawned or just-undocked Heli showed the full spinning
blur from tick 0, where the original shows a static, non-spinning single blade first, then widens the
blur through the ramp.

## Step 2: confirming mode 4 is a real, different asset, not a reused width

Re-disassembling the generic vehicle draw dispatcher (`FUN_0042eae0`) and the two extra descriptors it
references alongside the Heli's own body (`0x440b70`) surfaced the same three addresses document 63's
"Shadows" section had already resolved for the *dying* Heli (body + shadow `0x440ed8` + stopped rotor
`0x4406c0`) -- a dead end for this question, already correctly flagged as the wreck sequence, not touched
here. But `0x4406c0` on its own (the mode-4 corner set document 63 names directly) is real, separate data:

```
DumpDescriptorParts.java 4406c0:
# desc=0x4406c0 corner_count=4 corner_ptr=0x440630 parts_ptr=0x4406a0
part part_idx=0 cel=588 flags=0x0 corner_idx=3,0,1,2
     corners_fixed16_16=222822,111411,655360; 222822,-1671168,655360;
                         -222822,-1671168,655360; -222822,111411,655360
```

Divided by 65536: `x = +-3.4`, `y` from `1.7` to `-25.5`, `z = 10` -- a single blade, half-width 3.4
(matching document 63's "6.8 wide" mode 0/1 corner set exactly), 27.2 long, drooping toward one side
rather than spanning the full +-27.2 the spinning bar does. The registry (`packs/registry/asset_ids.json`,
already correct from an earlier session) independently confirms this is real, distinct, previously
unrendered art: cel 588 is `vehicle.heli.rotor.c`, "Heli rotor part (descriptors 0x4406c0, 0x440708)" --
a third rotor part alongside `rotor.a`/`rotor.b` (cels 580/584), not a colour or width variant of them.

## Step 3: the state that picks the mode is already ported

`game/vehicle.gd` already has everything document 79 traced, just never consulted by the renderer:

```gdscript
var heli_spinup_stage := 0        ## 0 done/flying, 1 blade accel (silent), 2 rotor ramp-up
var _heli_spinup_progress := 0.0  ## stage 1's accumulator (0..1)  -- state+0x58
var rotor_speed_steps := 4.0      ## the renderer's rotor speed (document 63's constant 4.0) -- state+0x84
```

`heli_spinup_stage == 1` is exactly "`state+0x58` below 1" (the stage only advances to 2 once
`_heli_spinup_progress >= 1.0`), so the mode function is a direct transcription of document 63's own
formula, no new tracing needed:

```gdscript
func _heli_rotor_mode() -> int:
	if vehicle.heli_spinup_stage == 1:
		return 4
	return clampi(int(floorf(vehicle.rotor_speed_steps)) - 1, 0, 3)
```

## Applied in the port (verified by test and screenshot)

`game/vehicle_render_3d.gd`'s `_build_heli_extras()`/`_animate_heli()` now rebuild the rotor's children
only when the mode actually changes (cheap per-frame check, same pattern as the Jeep/MSV animated-part
caching already in this file), picking real corners for all 4 non-folded widths (`ROTOR_HALF_WIDTHS :=
[3.4, 3.4, 6.8, 13.6]`, halves of document 63's own numbers) or the single `vehicle.heli.rotor.c` quad at
`ROTOR_FOLDED_CORNERS` for mode 4. Mode 4 does not spin (the original never advances the rotor angle
during stage 1 either -- `rotor_speed_steps` stays 0.0 the whole time, document 79).

`tools/tests/heli_rotor_mode_check.gd` drives a fresh Heli through 260 ticks and logs every mode change:

```
tick 0: stage 1 rotor_speed 0.0 -> mode 4
tick 55: stage 2 rotor_speed 0.0 -> mode 0
tick 136: stage 2 rotor_speed 2.02 -> mode 1
tick 176: stage 2 rotor_speed 3.02 -> mode 2
tick 216: stage 0 rotor_speed 4.0 -> mode 3
```

-- the exact sequence and tick numbers document 63's formula and document 79's own ~56/~216-tick timings
predict. Two screenshots (`RF_DEBUG_SWAP=0:3`, one 10 frames after spawn, one 280) confirm mode 4 renders
a single real blade (not a missing-texture placeholder or a crash) and mode 3 still renders the same
full-width blur this file always drew once flying.

## Still not modelled

The dying/wreck sequence (document 63's "Shadows", `FUN_0042eae0`'s other branch: body + shadow `0x440ed8`
+ stopped rotor `0x4406c0`) remains unimplemented -- unrelated to this fix, already tracked in
`NEXT_STEPS.md`. Whether mode 4's single blade is meant to look "folded" (as document 63's prose put it)
or just "drooping/stopped" was not re-litigated here; the corner data is applied exactly as read.
