# 57. Worked example: the flag, who can take it, and how a match ends

Document 26 found when the flag appears (a pool's targets are exhausted) and stopped there. This document
traces what the flag object does, which vehicles can take it, and the win condition.

## Only the Jeep can take the flag (confirmed)

The flag is class 12 (`0x44e3c0`, priority 201; init `FUN_004328c0`, update `FUN_00432920`, destroy
`FUN_004328f0`, object-collision callback `FUN_00432d00`). Three independent places restrict pick-up to
**vehicle type 1, the Jeep**:

1. `FUN_00432d00`, run when a vehicle's shape meets the flag's, requires the other object to be class 1 (a
   vehicle) with `record[0] == 1` (type index: 0 Tank, 1 Jeep, 2 MSV, 3 Heli).
2. `FUN_00432d80`, the callback of coastal id 63 (the ruins a destroyed building leaves, where the flag sits),
   attaches the flag to a vehicle that enters the tile under the same `record[0] == 1` test.
3. The deliberate grab/drop action `FUN_00432e40` is reached only from `FUN_0040e070`, which is the Jeep's
   *third weapon slot* handler (record `+0x184`, key bit `0x20`); no other type's record points at it. The
   Jeep's state handler (`FUN_0040d990`) also does the direction arrow and the capture check below; no other
   type runs it.

A vehicle can carry at most one flag (the callbacks refuse a vehicle that already carries either).

## The object

- Pool index: the flag belongs to pool `k` (the tile-variant bits of the candidate buildings: 0 = variant 0,
  1 = variant 1). It appears where the pool's last target fell (`FUN_00432710`, document 26), on the ruin tile.
- Shape (`0x440448`): a box (-3..5, -4..4), z 0-8, layer 1, mask 6: vehicles and shells touch it; a shell that
  reaches it just dies (its object-hit callback is null).
- Drawn (ground): a small plate (cel 1881) and the cloth (cel 1829 + variant: a 20 wide, 16 tall banner leaning
  toward the viewer). Drawn (carried, descriptor `0x440318`): two quads at 10.5 and 4.5-12.5 units (cels 1855 and
  1803 + variant). The cloth's two-frame flutter (every 15 ticks) is a separate child sprite (`0x4404b0` /
  `0x4404c0`) whose layout is not decoded. The registry's `marker.capture_flag.red/green.NN` are, by these
  parts, the tan and green *variants* of the cloth, not colours of one animation; left as they are.
- Carried: `FUN_00432920` places it at the carrier's position plus `(3.75, 6.75, -2)` (`0x440260`) turned by the
  carrier's heading (x to its right, y behind it), eases its own heading toward the carrier's, and swings it.
  Dropped (or never carried) it settles to the ground and records its last safe position (`0x459a20`).
- `flag+0x70` remembers the vehicle that dropped it: it cannot pick it up again until it has stopped touching
  the flag.

## Actions and the win

- **Touch** (Jeep, carrying nothing): the flag attaches (`FUN_0042cc50`) with a sound.
- **Action button** (Jeep, `FUN_00432e40`): for the vehicle's own pool first, then the other: a flag it carries
  is let go; a free flag that touches it is taken. (It can take its own team's flag as well as the enemy's.)
- **Capture** (`FUN_0040d990`, every tick): a Jeep that carries the *other* pool's flag and whose tile art is
  its own home art (`state+0x2c`: 90 for player 0, 91 for player 1, the bullseye tiles under the spawn points;
  checked against every level's spawn tile) calls `FUN_004225d0(player)`: it switches the game to its
  end-of-match handler (`0x4222a0`), starts a fade (`FUN_0042fdd0(0, 1000)`), records the **winner** in
  `DAT_00458d14` and sets the game-over flag. So a match is won by driving the enemy pool's flag home with a
  Jeep after destroying all of that pool's targets.
- A Jeep that dies while carrying leaves the flag where it is (the port drops it at the moment of death: the player respawns at once, and the check that ran only every frame let the flag ride the respawned Jeep home and win the match; fixed 2026-09-21).
  **Checked against the code (2026-09-21):** the flag is a *child* of its carrier (`flag+0x2c` = carrier, linked in the carrier's child list at
  `+0x30`, attached by `FUN_0042cc50`). The generic object destroy `FUN_0042c0f0` runs `while (children) FUN_0042cc50(child, 0)`, which clears
  `child+0x2c` and calls the class callbacks, so **the flag is detached at the instant its carrier is destroyed, where it hangs**; the flag's own
  update `FUN_00432920` then treats `+0x2c == 0` as dropped (falls to the ground, records its last safe position). The original has no instant
  respawn: that is a port placeholder (`_on_player_destroyed`), which is what made the bug. At the base, a Jeep carrying its *own* pool's flag
  and leaving its vehicle (`record +0x258` = `FUN_0040e090`) calls `FUN_00432600`: the flag is removed and a
  target is re-activated if any candidate is still intact (else it moves to a random candidate tile). Not
  modelled.

## Vehicle types and playing the Jeep

Because only the Jeep can capture, the port needs a playable Jeep. `tools/extract_vehicle_types.py` builds
`tools/data/vehicle_types.json` from the four type records: speed, reverse, acceleration, friction, turn rate,
armour, hit points, **fuel (Tank 400, Jeep 500, MSV 320, Heli 400)** and the collision polygon (Jeep 9 x 15,
MSV 15 x 23.25, Heli a pentagon), plus each type's draw parts. `Vehicle` now takes all of them from the pack by
type, and `game/vehicle_render_3d.gd` draws the Jeep from its descriptor (verified by screenshot: hull, the
driver, the windscreen). The Jeep's weapon is the lobbed missile of [document 61](61-worked-example-jeep-missile.md) (its "machine gun" `FUN_0040df00` -> `FUN_00415b00` is that missile), its
amphibious mode (`FUN_0040dfe0`, `state+0x84`) and its own drive handler (`FUN_0040db80`, which adds automatic
steering) are not traced; it uses the shared drive function.

The original chooses a vehicle at the base (`FUN_0040b400`, with per-type stock counts that are the level
header's untraced `A/H/J/M/T` values). As a **port-only convenience**, `V` cycles Tank and Jeep while standing
still on the player's home tile, `F` is the flag action, and `RF_VEHICLE=jeep` starts as a Jeep.

## Applied in the port

`MatchController` keeps `flags` (pool index -> `FlagMarker`, spawned when a pool goes silent as before), attaches
the flag to a touching Jeep, makes it follow at the traced offset, lets `F` drop or take it, and declares
`match_over(winner)` when a Jeep carrying the other pool's flag stands on its home art (vehicles freeze; a
placeholder banner shows the winner). Scripted check on RFMAP001: a Tank on the flag does nothing; after `V` at
the start tile the Jeep (1 hit point, 87.5 px/s, fuel 500) takes it, it follows at (-3.75, -6.75) for a
south-facing Jeep, drops on the action and cannot re-take it until it moves away, is taken again by the action,
and carrying it onto the home tile ends the match with the tan player winning.

## Not done

The flag's own art and flutter and the carried drawing (the port keeps the earlier flat decal, now following
the carrier); the direction arrow; the Jeep's gun and water mode; the base exit and own-flag return; the
score screen; the placeholder AI never seeks the flag; the flag's ground-settling and last-safe-position rule.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
