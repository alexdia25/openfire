# 51. Worked example: how an explosion is drawn, and playing one

Document 50 left one blocker: how a clip's frame is chosen. It was not the generic part drawer at all.

## The draw callback

An "Expl" object's default descriptor block (`0x44bb40`, from its class descriptor `+0x14`) has no shape
of its own; its first word `0x42dd90` is a draw callback, `FUN_0042dd90`, and that function draws the
record's own parts (`record[8]` corners, `[9]` count, `[10]` parts, **6 ints each**). Reading it:

- `progress` is the object's `+0x64` (16.16); the update `FUN_0042dbe0` adds `record[5]` per tick and kills
  the object at `record[3]`. `n = progress >> 16`.
- A part is `[cel, flags, corner idx x 4]` with `flags = start | end << 8 | fade << 16 | variant << 24`
  (signed bytes). It is drawn while `start <= n <= end`, as **cel + (n - start)**, on the quad given by its
  four corner indices into the record's corner array, all corners scaled by `record[6]`.
- From `n >= fade` it fades: `alpha = 1 - (n - fade + 1) * (1 / (end - fade + 2))` (the reciprocal table at
  `0x48a080`, filled by `FUN_0041ae50` with `0x10000 / k`), handed to `FUN_00423060`, which quantises to the
  3DO's 16 translucency levels (`level = (alpha >> 12) - 1`: below 1 the part is hidden).
- The variant byte's low three bits pick among following parts by the object's serial: 1 and 4 a pair, 2
  four, 3 eight, 0 a single part; the group's other parts are skipped.

So document 49 misread the flags: byte 0 is the *start*, byte 1 the *end*, byte 2 the *fade start*. The
frame counts it derived were `end`, not a count; the clips it drew from the cels were right, and, checked
the other way, `end - start + 1` reproduces the clip lengths seen in the strips (1109: 14, 1123: 16).

## Timeline of a tile collapse

The record's script runs in step: `WAIT n` holds until `progress >= n`. For the candidate building
(`0x443f30`, rate 1/6): sound, wait 3 (18 ticks), glow descriptor, wait 4, `DRAW_LIST 4`, **`TILE_STATE`**.
`FUN_0042e6a0` returns immediately when a record was spawned, so the destroyed art and coastal id (22 -> 62,
document 44) appear when the script reaches `TILE_STATE` -- 24 ticks (0.38 s) after the hit, with the
explosion already burning -- not at the hit.

## Applied in the port

- `game/explosion_effect_3d.gd` plays any record: parts with frames by `start/end`, the fade above (the level
  to opacity mapping is `(level + 1) / 16`, an approximation: the blend words are hardware register values),
  variants, scale, duration/rate, and a minimal script runner that fires `tile_state`. `tools/build_pack.py`
  emits `effects/explosions.json` (frames resolved to sprite ids) and `Pack.get_destroy_effect()` /
  `get_explosion()` read it; `tools/extract_explosion_records.py` regenerates
  `tools/data/explosion_records.json` from Ghidra dumps.
- A destroyed pool target plays the record its coastal entry names and changes state at `TILE_STATE`; a
  projectile that hits a vehicle plays `0x444b68` and one that hits a target tile `0x444ac8` (surface 3 and 4
  of document 50) where it ended. Verified by screenshots on RFMAP001 tile (75,56): intact building,
  explosion starting, fireball, then the ruin.

## Not applied (untraced or out of scope)

- Sounds, the ground glow, neighbour tiles' `TILE_SET` / `TILE_DMG` ops, the damage box (mines), the tile's
  own position offset callback.
- Projectile impacts on land, water and pavement: a shot in the original ends when its height reaches the
  ground (`FUN_00414b10`), not at a fixed lifetime, and the port's shell still expires by lifetime, so where
  it would land is not yet defined.
- The muzzle flash: its record (`0x445138`) is spawned through `FUN_0042e0b0` with a vehicle-relative
  offset and heading whose handling is not traced.
- The z of an effect (drawn at the ground here).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
