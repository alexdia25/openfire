# 58. Worked example: the MSV and its rocket salvo (first weapon of a second vehicle)

Documents 45 and 52 traced the Tank's cannon. This one generalises the shot so any vehicle can fire, and
applies the MSV's first weapon. Everything below was read from the code (`FUN_0040d520` and its helpers), not
guessed; the exceptions are named at the end.

## The projectile table

`tools/extract_projectile_types.py` reads the 12-entry table at `0x4489a0` (0x3c bytes each) and the draw
descriptors it points at into `tools/data/projectile_types.json`; `tools/build_pack.py` resolves each part's cel
to a sprite id (flag 8 = + team variant) and writes `vehicles/projectile_types.json`. `Pack` loads it as
`projectile_types` and `projectile_descriptors`. Type 0 is the Tank shell (speed 3.0 units/tick, damage 1.0, 80
ticks); **type 8 is the MSV rocket: speed 2.3, damage 2.0, 90 ticks** (flags 3: pitch-matrix launch and ballistic
bit, but launched level so it flies straight).

## The MSV weapon (slot 0, level fire)

- Three launcher positions in turn, x = -1.5, 0, +1.5 in the vehicle's frame; the rocket starts at
  (x, -8.96 in original y, 10.54 up), i.e. 8.96 units ahead.
- 30 ticks between rockets; after the third the launcher reloads for 6.0 / 0.15 = 40 ticks.
- A back-blast flash (explosion record `0x4450d8`) plays behind the vehicle at (x, 7.53 behind, 11.05 up).
- Rocket art: two fin quads (cel 1066) plus a team-coloured trail (cel 1077 + variant) and a flat shadow (cel
  1068); drawn straight from the descriptor `0x454580`/`0x4545e8`.

## Applied in the port

`Vehicle` now emits `shot(spec)` (projectile type, position, height, heading, team, flash record and local
offset) instead of a Tank-only `fired`. `MatchController._on_vehicle_shot` builds a `Projectile` configured
from the pack (`speed`, `damage`, `lifetime`, height `z`), and shell collision tests use that height.
`ProjectileBillboard3D` draws any non-shell type from its descriptors. `V` now cycles Tank, Jeep, MSV;
`RF_VEHICLE=msv` starts as an MSV. Screenshot check (`RF_DEBUG_FIRE=1`): rockets fly level with trails and shadows,
the back-blast appears at the rear, salvo spacing is 30 ticks (frames 0 and 63 at 60 fps).

## Not done

The MSV's mine layer (slot 1: cooldown 140 ticks, ammo 10; needs the mine object and explosion damage volume);
the elevated rocket (type 9; done in [document 64](64-worked-example-turret-and-raised-fire.md)); impact effects specific to rockets (they reuse the
shell's); the MSV's own drive quirks. The Jeep's machine gun and homing missile and the Heli follow.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
