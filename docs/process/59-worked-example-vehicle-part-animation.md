# 59. Worked example: how the original animates its vehicles

The four vehicle types are drawn by callbacks stored at descriptor `+0` (Tank `0x402dc0`, Jeep `0x402fc0`,
MSV `0x402ec0`, Heli `0x403550`; the Tank/Jeep/MSV also have a second callback `0x402d20` at `+0x24` that
Ghidra has not disassembled). Each callback edits the descriptor's own tables (part cels, corner arrays)
before calling the generic drawer `FUN_0041b430`; the drawer itself (`FUN_0041b2b0`) only draws the parts as
they stand (cel, plus the team variant if part flag 8), so **all animation is in these callbacks**.
Traced from their disassembly (`tools/ghidra_scripts/FindDispOps.java` finds field writers).

## Object fields the callbacks read

`draw+0x2c` is the vehicle object; object `+0x40/+0x44/+0x48` is its x/y/z position (16.16; the wreck spawn at
`0x40bba0` passes them), `+0x4c` heading, `+0x54` speed, `+0x60` the player's state block. State `+0x50` is the
gun elevation, `+0x58` a weapon counter, `+0x80` the water immersion (0..1.0), `+0x84` the engine value.

## What each type does

- **Tank (`FUN_00402dc0`):** turns the turret by state `+0x58` and pitches the barrel by `+0x50` (independent
  aim, not modelled). Nothing is done to the tracks: their cels (182/183) are just the team variants, so **the
  Tank's tracks are not animated by its draw code**.
- **Jeep (`FUN_00402fc0`):** the wheel strips (parts 9 and 10, cel 457) are drawn as `457 + ((x & 0x30000) >> 16)`
  where `x` is the object's position: the frame is the integer world x modulo 4, so the strip steps once per unit
  travelled along x and does not change when driving along y (a quirk of the code, kept). Cel 461 is never
  chosen by this callback. State `+0x80` (water immersion, 0..8 in steps of 1/8) picks a row of the table at
  `0x43fb78` that moves the wheel corners, and above 3/8 it switches to a second descriptor (`0x43fcb8`): the
  Jeep's amphibious look, not modelled (no water mode yet).
- **MSV (`FUN_00402ec0`):** the canister part (13) is cel `326 - n`, `n` being the rockets fired in the
  salvo (state `+0x58` counts 0, 1, 2, then `FUN_0040d6e4` sets it to -6.0 and `FUN_0040d790` raises it 0.15 per
  tick). So three, two, one canisters (cels 326, 325, 324, the registry's `canisters_3/2/1`). While the counter is
  negative the part's two front corners (48, 49) slide: `y = 11.25 - 6 + 6 * remaining / 40`; the steady state
  is y = 5.25, not the descriptor's static 6.75. The gun elevation (state `+0x50`) also rotates corners 44-51
  (the rack), not modelled.
- **Heli (`FUN_00403550`):** while state `+0x58` is below 1.0 it shifts a list of corners (`0x440b48`) by
  `(1 - value) * 18` units: the landing gear or a similar retract. The rotor is not drawn by these parts alone
  (part flags `0x100/0x200` select render modes; the second callback is `0x4034c0`). Not applied: the Heli
  cannot fly yet.

## Applied in the port

`VehicleRender3D` keeps every part's mesh and rebuilds only the animated ones when their state changes: the
Jeep's wheel frame from its x position, and the MSV's canister cel and sliding corners from
`Vehicle.salvo_index()` / `salvo_reload_remaining()`. Screenshots with `RF_DEBUG_FIRE` show the canister block
change through a salvo and slide back on reload. The Jeep's strip is a thin part and its change is hard to see
in stills; the rule is exactly the traced one.

## Not done

Tank tracks (none in the code read, so nothing to add), turret aim and barrel pitch, the Jeep's water mode, the
MSV's elevated rack, the Heli's gear/rotor and its second callback, and `0x402d20` / `0x4034c0` (undisassembled).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
