# 67. Worked example: playing level 1 inside the real scene, and the ruin that grabs the flag

**Question:** is level 1 completable *in the scene* (not just in the headless test), and what does a player need on screen to do it? The run also found a real bug: the Jeep seemed to
get stuck on the finished building. Field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: an autoplay inside the scene

`game/debug_autoplay.gd` (env `RF_DEBUG_AUTOPLAY=1`, speed `RF_DEBUG_AUTOPLAY_SPEED`, banner shot `RF_DEBUG_AUTOPLAY_SHOT=<png>`) drives the same route as
`tools/tests/playthrough_rfmap001.gd` but one control update per frame, through the input actions a player uses, so the scene's own tile-state application, explosions and
win banner run. Result (headless run, 6x speed): `drive_to_building -> shoot_building -> shoot_ruin -> drive_home -> settle -> wait_flag -> drive_to_flag -> carry_home`, then
"match finished, winner 0". It is a debug tool, not part of the original.

## Step 2: the Jeep "stuck on the ruin": the tile callback nobody had implemented

The report: the Jeep gets stuck on the building in its final state. Reading the tile's own data (`coastal_shapes.json`, id 63): **four 6 x 6 posts** at (-10, -13), (12, -13), (-10, 5), (12, 5)
from the tile centre (z 0-5, layer 1, mask 255), so the interior is a 16 x 12 corridor open north and south; the Jeep's shape is 9 x 15. A Jeep can enter, but only by a
narrow line (`tools/tests/ruin_access.gd` prints the free cells for four headings: about 6 units of lateral slack). That is the traced geometry, so the port was right to block it.
The question is then *how the original expects the flag to be taken*. Document 54's table already says: the ruin's tile callback **`FUN_00432d80`** (decompiled again):

```c
if (*(int *)param_1[5] != 1) return 0;                    /* the mover's class is 1: a vehicle */
if (**(int **)param_1[0x18] == 1) {                       /* its type record says Jeep */
  for each of the two flag slots at 0x45ae48:             /* find a flag ... */
     flag = slot;  if (flag[7] == param_2 && flag[0xb] == 0) break;   /* ... whose grid cell is this tile and that has no carrier */
  flag[0x1a] = param_1;                                   /* remember the toucher */
  if (flag[0x1c] == 0 && flag[0xb] == 0) {                /* no "dropper" (+0x70), still free */
     if a child of param_1 is already a flag: return 0;   /* one flag per vehicle */
     FUN_004232d0(...); FUN_0042cc50(flag, param_1);      /* sound; attach the flag to the vehicle */
```

`flag[7]` (`+0x1c`) is the object's **grid-cell back pointer** (`FUN_0042c290` unlinks it from `piVar6[7]` on destroy, `FUN_0042c720` links it), and the callback receives the tile pointer as
its second argument (`FUN_0042bb10` calls `(*(local_c + 0x14))(mover, tile, id)`), so "this flag sits on the tile being touched". The callback returns 0, "not passable", so the posts still block.
**Meaning: a Jeep that touches any post of the ruin takes the flag; it never has to enter.** The port only had the flag's own contact box (`FUN_00432d00`), which sits in the middle
of the posts, so approaching a post left the Jeep stuck against it without the flag.

Applied: `MatchController._ruin_grab` (called from the `"0x432d80"` case of `_tile_blocks_vehicle`, returns "blocked" afterwards like the original). Checked with `ruin_access.gd`: driving a Jeep at
the ruin from north, east, west and south-south-east grabs the flag on contact with a post (about 40 ticks), and the level playthrough still passes.

## Step 3: a placeholder panel (port-only)

`game/placeholder_hud.gd` draws plain labels: the vehicle's name, hit points and fuel, an objective line (its wording is the port's, **not** an original message), the key list, and after the
win a banner with "press Enter to play again" (reloads the scene). Everything in it is a choice of this port, listed under "Untraced choices" in the next-steps doc; it is to be replaced
by the panel of [document 66](66-worked-example-the-hud-panel.md).

## Not done

The flag interface bits and the radar blip; the fuel and health displays of the original; the two-player panel layout; the announcer.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
