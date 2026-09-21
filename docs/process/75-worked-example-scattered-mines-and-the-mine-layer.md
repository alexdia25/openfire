# 75. Worked example: the mines lying about at the start, the MSV's mine layer, and radar bit 31

**Question:** document 60 traced the MSV's mines but noted a player-count test and left the level parameters open; document 69 left "tiles with bit 31 set" unexplained; document 73 found the level's `M` value.
What is `M`, when can the MSV lay mines at all, and what does bit 31 mean? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: bit 31 is "a mine is here"

`FUN_00409e30(x, y)` (the mine's constructor, document 60) decompiled again:

```c
if (FUN_0042f410(&pos) == 2) return 0;                       /* deep water: no mine */
mine = FUN_0042c290(0x4430c8, 0, x, y, 0, 0);
if (mine) { *(uint *)mine[7] |= 0x80000000;                  /* mine[7] = the tile the object stands on: set bit 31 */
            FUN_00412dc0(mine[7], 1); }                       /* repaint that tile's radar pixel */
```

and the radar painter (document 69) draws a coastal-id-free land tile with bit 31 in colour **0xc9** (a light purple). **So the radar shows mines**: every mine on land is a purple dot. The port now does this (`MatchController.mine_tiles`, `RadarView`).
That the bit is cleared when a mine explodes is assumed (`FUN_00409dd0` was not read for it): untraced.

## Step 2: `M`: mines scattered at the start (`FUN_0042a030`)

Document 73 found `M` in the level's `VHCL` chunk; the match start (`0x41ebd2`...) calls `FUN_0042a030(count)`:
`if (M != 0 && M != 0xff) count = M`; else, for **one player**, `if (M == 0xff && LEVL > 5) count = 4 * LEVL` (`0x41ec43-0x41ec68`); with two players `M` 0xff was forced to 0 by the parser, so none. `FUN_0042a030` (decompiled):

1. `DAT_00458d48..d50` = the home tile's x / y (`*DAT_0048c8b4 >> 21`, a pointer to the home position) minus and plus 2: a box.
2. **First list**: every tile with no coastal id, outside the 3 x 3 tiles around home, art bit 3 clear and art below `0x54`, and either art `0x49-0x53` (always) or a land art (0, 3, `0x34-0x48`) with a road-side neighbour (the tile above, below, left or right has art `0x49-0x59`).
3. It repeats `count` times: pick a random candidate (`FUN_0041d3d0`), place the mine at `x * 32 + rand(25) + 6, y * 32 + rand(25) + 6` units with `FUN_00409e30`, and cross the candidate off.
4. If mines are still owed, a **second list** (`FUN_0042a430`, decompiled: the same tests without the road-side rule) supplies them.

`M` in the 204 levels is 0 (none), 255 (default) or a count (RFMAP040: 25). Applied in `MatchController._place_start_mines`. Checked by `tools/tests/start_mines.gd`: RFMAP001 and 002 none (LEVL 0 and 1), RFMAP040 25 (24 tiles: two mines share one), RFMAP100
(LEVL 8) 32. **Untraced:** the random sequence (`FUN_0041d3d0`; the port seeds a generator with the level's tile seed), so the positions differ from the original's.

## Step 3: the MSV's layer is a two-player weapon

`FUN_0040d820` (document 60, step 2) begins `if ((keys & 0x60) != 0 && 1 < DAT_00442fbc)`, and `DAT_00442fbc` is the number of players (`CMP byte [0x442fbc], 2` at the two-player set-up, and the parser's `param_3 == 2`). In a **one-player game the MSV cannot lay mines**; in two-player the scattered mines are off and the
layer is on. The port had let the MSV lay mines in one-player play; it is now gated: `Vehicle.mine_layer_enabled` is `players > 1` (1 today), and `RF_DEBUG_MINES=1` forces it on for testing.

The layer's mines come from the player's byte `+0xbc` (a reserve): the creation code hands out `min(reserve, 10)` (document 73) and a docking MSV adds its unused mines back. **Where the reserve starts is not found** (the `+0xbc = 0` write I first took for it belongs to the camera's struct, `FUN_00416cb0`, not the player's).
Until the two-player mode exists the port gives the MSV its full 10 mines whenever the layer is enabled (untraced).

## Step 4: `unk4` and the pools

The parser's sixth value `unk4` (default 0xff, then `table[0x442fd8 + LEVL]`) goes to `FUN_00409ea0`, which builds two lists (one per team) of `min(unk4, 5)` records at `0x457f60` / `0x457fb0`, 32 bytes each. What the records are is untraced (a per-team pool of at most 5 of something).

## Not done

The reserve's real source; `unk4`'s pools; the mine's radar clearing; the original's random positions.

**Next:** the remaining open items in [the next-steps doc](NEXT_STEPS.md).
