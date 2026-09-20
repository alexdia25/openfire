# 48. Worked example: scanning for every draw descriptor, and what a wreck is

Document 46 left the explosion frames and several object families unowned; document 47 showed a
destroyed vehicle spawns "a wreck object" and named its class. Instead of tracing owners one by one,
this pass scans the binary for **every** draw descriptor (the layout of documents 37-40 and 44) and
attributes cels to whatever descriptor uses them.

## The scan

`tools/ghidra_scripts/ScanDescriptors.java` walks `0x43a000-0x45a000` looking for the layout
(`+0x2c` corner count 3-128, `+0x30` corner array and `+0x38` parts array inside the data segment, the
first parts' cels below 2165, corner indices below the corner count, corner values sane). It found 164
descriptors referencing 241 distinct cels, 57 of which no earlier extraction had (`tools/data/
draw_descriptors.json`; heuristic and not exhaustive -- some layouts are rejected, and a part list can
overshoot into a neighbouring array). New owners it exposed:

- **Heli rotor**: the Heli descriptor's `+4` "next" link (the same chain mechanism as the palm trunk,
  document 44) points at `0x440708` (cels 580 + variant, 584 + variant, 588) and `0x4406c0` (588): the
  red-banded bars are rotor blades; the Heli ground shadows are 579 (`0x440e90`, `0x440ed8`) and the
  rotor-spin shadow frames 589-605 (`0x440da8`, `0x440d60`).
- **`0x443740`, a 15-part, 50-corner object** built from cels 583/587 (blurred rotor discs), 608-624
  (pipes, hooks, panels, a dome), with its shadow 626. It is a rotor-carrying object that is not the
  Heli itself; the hook/pipe parts suggest the helicopter's winch or a further aircraft. Unresolved.
- **The capture flag**, `0x440448`: cel 1829 (flag, variant pair) with 1881 (a small base part; it was
  `marker.mine_icon.01`).
- Infantry (`0x44e928`: troopers 665-745 tan/green, dust puffs 755-756), rescue cages/crosses
  (`0x44d890`, `0x44dab0`), and building pieces `882-894` used outside the coastal decorations
  (`0x4513c0`, `0x451588`): the registry's names for these are consistent with the owners.

## Wrecks

The vehicle class `0x445438` (document 47) spawns class `0x4453e8` on death. Its update
(`FUN_0040c8f0`, decompiled in document 45's session) applies gravity, then swaps the drawn
descriptor to the type record's `+0x164` when it lands. Those descriptors:

| Type | `+0x164` | Parts |
| --- | --- | --- |
| Tank | `0x43ece8` | cel 274 (27-unit ground shadow, effect page), 275 (24x24 decal, +1 green), 277 (24x24 debris decal 2 units up, +1 green) |
| Jeep | `0x440218` | the same three cels |
| MSV | `0x43f628` | 412 (shadow), 413/414, 415/416 |
| Heli | `0x440fa0` | 606 (+1 green) |

Registry: these cels are now `effect.shadow.hard.wreck_*` and `vehicle.wreck.{small,large,heli}.*`
(they were `explosion_splash`, `explosion_large`, `debris_faint`, `spike_ball`). The Tank's group slots
3/4 (cels 170/171, 175/176) are *not* the wreck; their purpose is still untraced.

## Applied in the port

- `game/wreck_3d.gd`: a destroyed vehicle leaves the Tank wreck (shadow + two decals, tan or green by
  team) where it died; the falling/settling animation is not modelled. Verified by screenshot with a
  debug drop (`RF_DEBUG_WRECK=1`).
- `game/projectile_billboard_3d.gd`: the shell is now the original's art (cel 1075, 4x4 units, with
  its shadow 1076) instead of a coloured sphere; the height above ground is still a placeholder.

## Still open

- **Explosion frames** (1084-1089, `effect.explosion_large`, `effect.burst_*`): no draw descriptor uses
  them. They are reached through the animation-list tables at `0x44aa80` (4-dword entries whose two
  pointers are frame lists) and the tile-effect scripts of document 47, a different structure that is
  not decoded.
- The `0x443740` object; the hit flash; explosion damage to vehicles.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
