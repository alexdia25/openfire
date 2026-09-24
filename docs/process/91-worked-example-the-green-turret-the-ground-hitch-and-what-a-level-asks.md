# 91. Worked example: the green Tank's turret, the tile-change hitch, the Heli's two buttons, and what a level asks of you

Four user reports after playing through several levels with the dev level switcher. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## 1. "The turret on the green tank is drawn tan"

The green Tank's hull was green and its turret tan. `game/vehicle_box_3d.gd`'s `TURRET_PARTS` listed the same sprite for both teams (`turret.top.01`, `.side.01`, `.back.01`, `.front.01`), on the strength of an old note that the "+1" cels were "not part of a confirmed team pair". The turret's descriptor is `0x43e9b8` (document 39); its part table starts at
`0x43e7c0` (`DumpDwords.java 0x43e7c0 72`, eight dwords a part: cel, flags, ...):

```
000000b1 00000008 ...   ; cel 177  flags 8   (turret top)
000000c0 00000008 ...   ; cel 192  flags 8   (side)        x2
000000c5 00000008 ...   ; cel 197  flags 8   (back)
000000cf 00000008 ...   ; cel 207  flags 8   (front)
000000ca 00000008 ...   ; cel 202  flags 8   (barrel)      x2
000000d4 00000008 ...   ; cel 212  flags 8   (muzzle ring)
```

Flags bit 3 means "add the team variant" (cheat sheet, section 2: a part's `flags`), so team 1 draws **cel + 1**: 178, 193, 198, 208 (and 203, 213). Extracting those cels shows a green turret top, side, back and front; the registry had them as `vehicle.tank.hull.08/13/15/19`, after an old pixel test called them "blue-dominant". Renamed
`vehicle.tank.turret.{top,side,back,front}.02` in the registry (`AUDIT12` in `classify_batch2.py`), the pack rebuilt, and the green slot of each `TURRET_PARTS` entry now names the `.02` sprite:

```gdscript
{"sprites": ["vehicle.tank.turret.top.01", "vehicle.tank.turret.top.02", "vehicle.tank.p177.yellow"], "_cel": 177, ...}   # [tan, green, flash]
```

Checked by before/after screenshots on level 204 (the tan turret on a green hull, then a green one).

## 2. "A big hitch in the frame rate whenever we run over something or blow something up"

Timed in the real scene: a normal frame is about 6 ms; the frame after any tile change was **73 ms**. Both crushing (`tile_crushed`) and destroying (`tile_destroyed`) end in `_apply_tile_destroyed`, which called `TerrainTileRenderer.queue_redraw()` and set the ground viewport to render once more: the whole 128 x 128 tile map (a 4096-pixel texture, about 16,000 tiles, and since document 89 an underlay
rectangle each as well) was redrawn for one changed tile. The decoration refresh in the same function costs about 5 ms and was left alone.

The fix (`game/terrain_tile_renderer.gd`, `terrain_view_3d.gd`): the viewport keeps its contents (`CLEAR_MODE_NEVER`) and `mark_tile(tile)` redraws only that tile. Two layers draw in order, an underlay that *replaces* the tile's pixels (a `blend_disabled` canvas shader, so the pad's transparent hole can be written back as transparent) and then the art. One trap: a redraw **replaces** the layer's draw commands, so the "draw everything" and dirty lists may only be cleared after a frame has rendered them (`RenderingServer.frame_post_draw`); clearing them at the end of `_draw` left a partial command list when a tile changed before the first render, and the map came out blank (found with a screenshot).

```gdscript
func mark_tile(tile: Vector2i) -> void:
	if not _full and not _dirty.has(tile):
		_dirty.append(tile)
	_under.queue_redraw()
	_art.queue_redraw()
```

Measured after: a tile change takes an ordinary frame (3-8 ms, no spike); a screenshot of the same dock frame differs from the pre-change one in 152 pixels of 746,000; the pad hole, its restore after the undock rise, and an arbitrary tile change (that tile differs, a far tile does not) all behave.

## 3. "Can we confirm the helicopter's second fire?"

Tested with a script (Heli in flight, each weapon slot, each button held for 200 ticks): both buttons fire both weapons. Slot 0 (the gun): Space fires type 7 at **39.4 degrees down**, `Z` fires it level; slot 1 (the bomb, selected with the third button `X`): both fire type 6, level. That is what the trace says (document 63, `FUN_0040e600`): the two buttons pass different fourth arguments, and the pitch is only substituted for the gun
(`if (type == 7 && param4 != 0) param4 = 0x71c71`), so a bomb's only difference between the buttons is the 0.5-step toe-in. The code has not changed since document 63 (checked with `git log -S`). If a difference used to be visible for the bomb, it is not in the traced logic; a recording of the original would show which. Not changed.

## 4. "Do different levels have different objectives? I don't see a flag on every map"

From the 204 `level.json` files: every level has the same two-pool structure (`candidate_pools` `a` and `b`) and the flag appears only where **the last target of a pool falls** (document 26), so no level shows a flag at the start. What differs is the size and the number of teams:
- **100 one-player levels** (`1PLAYER`, `mode_byte` 1, one spawn): pool `a` (the player's own) is always empty, pool `b` (the enemy's) has 1 to 160 targets (median 5; 17 levels have a single target); the flag spawns once `b` is cleared.
- **104 two-player levels** (`2PLAYER`, two spawns): both pools are the same size (1 to 56, median 4); each pool spawns its flag when its own targets are cleared (which side may take it is document 57's flag rules; the port only plays one side).
- Difficulty (`LEVL`, 0 to 8), the vehicle stock and the mine count also vary per level (documents 73, 75).

So the objective is the same (clear the enemy's targets, take the flag home) on every level the port can read; only the amount of work differs. **Untraced:** whether any level has a different win condition (nothing in the level chunks names one) and how a one-player game plays a two-player level (the port plays one side of it, without an opponent).

**Next:** [the next-steps doc](NEXT_STEPS.md).
