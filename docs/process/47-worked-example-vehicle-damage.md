# 47. Worked example: how a hit reaches a vehicle

Document 45 left "vehicle health and vehicle-vs-vehicle damage" open, guessing that the Tank record's
`+0xe8` (100.0) was hit points. It is not. Document 46's unresolved list also carried the explosion
records. This document closes the first and narrows the second.

## The vehicle class and its hit callback

The vehicle object class descriptor is at `0x445438` (found by searching the raw bytes for the init
function `0x40b700`): `+0x08` init `FUN_0040b700`, `+0x0c` destroy `FUN_0040b8b0`, `+0x10` update
`FUN_0040b980`, `+0x14` the Tank draw descriptor, and **`+0x3c` the hit callback `FUN_0040c460`**
`(victim, hitter, damage)`. Both projectile hits (`FUN_00414e60` calls `victim_class->+0x3c` with the
projectile type's damage, document 45) and explosions (`FUN_0042dd20`, damage -(rate x dt) per tick)
end up here. `state[0]` (the per-player block at `0x458100`) is a pointer back to the type record, so
`FUN_0040c460` reads record fields through it:

| Record offset | Meaning | Tank | Jeep | MSV | Heli |
| --- | --- | --- | --- | --- | --- |
| `+0x24` | armour | 0.3 | 0 | 0.5 | 0.2 |
| `+0x28` | **hit points** | **22** | **1** | **26** | **15** |
| `+0x234` | dying state handler (0 = spawn a wreck object at once) | 0 | see below | | |
| `+0x238` | hit-reaction callback (optional) | none | | | |

The rule: if `damage - armour < 1 raw unit`, nothing happens; otherwise `hp -= damage - armour`, and
the vehicle records "hit at tick now+10" (`state+0x4c`, presumably the yellow variant cels of
document 46 flashing for 10 ticks = 0.16 s; not confirmed). While `hp > 0` the optional reaction
callback runs. At `hp <= 0` the vehicle either switches to the dying handler `rec+0x234` or spawns a
wreck object (class `0x4453e8`) and is destroyed; a very negative hp (< -40) additionally flags the
wreck.

So a Tank shell (damage 1.0) does 0.7 to a Tank: **32 shells** to kill one (22 / 0.7), 13 rockets of
damage 2 (1.7 each), or 6 of damage 4 (3.7 each). The Jeep (1 hp, no armour) dies to any shot.
Document 45's `+0xe8` = 100/250/?/200 is something else (it sits in the block copied to the state at
`+0xe0`, a speed-tilt or fuel-like quantity; still untraced), and its reading of `+0xe8` as health was
wrong.

## Water

`FUN_0040cef0` (record `+0x4c`) reads `state+0x70`: nonzero means the vehicle is in water. Value 2
(deep) sinks it: it swaps the drawn descriptor to `rec+0x154` and installs the sinking handler
`FUN_0040cf90` (unless it is a type-1 vehicle with `state+0x84 == 1.0`, the amphibious case). Value 1
(shallow) with speed above half the terrain-scaled maximum switches to the wading descriptor `rec+0x14c`
and the `FUN_0040d150` handler. This is where the "in water" speed caps of document 45 come from. Not
modelled.

## Explosion objects are bytecode scripts, not sprite lists

The explosion class (`0x44bb70`, name string "Expl") runs a small byte-coded script (record `[0]`,
e.g. `0x4450d0`) on a progress counter that advances by `rec[5]` per tick to a duration `rec[3]`
(25 ticks for `0x445138`, 90 for `0x444ee8`). Byte 0 ends, 1 stops, 2 waits until progress reaches
the next byte; everything else indexes the handler table at `0x44bae0`: play a sound
(`FUN_0042d360`), spawn/replace a tile (`FUN_0042d3f0`), damage the tile at an offset
(`FUN_0042d850`/`d8d0`, 255 damage, document 44), swap the draw descriptor (`FUN_0042d4e0`,
`d610`), set a light/quad (`FUN_0042d640`), draw a decoration list (`FUN_0042d790`), loop/branch
(`FUN_0042d540`, `d950`). These are the *tile* destruction sequences that coastal entries and
projectile impacts spawn (`FUN_0042e080`). They reference cels through draw descriptors, so the
explosion art is reachable by extracting each script's descriptor references; that is a separate,
mechanical job (one more Ghidra script) and is left for the audit's unowned effect ranges.

## Applied in the port

`Vehicle` gets `hp = 22`, `ARMOR = 0.3`, `take_damage()`, `alive`, `destroyed`; `Projectile` carries
`damage` and `shooter` (a shot never hits its own shooter, as in `FUN_00414e60`); `MatchController`
tests projectiles against living vehicles with a 12-unit radius (**placeholder**: the real collision
shape is untraced) and respawns a destroyed player at the start point (**placeholder**: no life
system is traced). A dead enemy simply stops and is hidden. Verified by a scripted run: 31 shots leave
0.3 hp, the 32nd kills; self-hits are ignored; the player respawns.

Not done: per-type stats for the Jeep/MSV/Heli (they are not playable here), the hit flash, the
wreck object, the dying handler, water sinking, explosion damage to vehicles.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
