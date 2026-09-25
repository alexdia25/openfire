# 96. Worked example: the original's screen layout, and the "classic" and "modern" panel layouts

**Question:** documents 66 and 70 traced the player's panel but left its position and scale as "the port's": the port drew it 3x at the window's bottom left over a full-window game view. The user wants that kept as an option, **modern**, and the original's arrangement available as **classic**. What is the original's arrangement? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md). (This applies to the traced panel, not to the temporary placeholder labels.)

## Step 1: the reference footage

A frame of the reference video (`ffmpeg -ss 200 ... -frames:v 1`, 1440 x 1080, so 4:3) shows what the code below produces: the game view fills only the **top 63 percent** of the screen (rows 0-685 of 1080, about 152 of 240); below it runs a full-width strip: a metal rail along its top edge, camouflage wallpaper (green and brown blotches) to either side, and in the middle the vehicle's panel in its frame. The radar window lies at (106, 179) of a 320 x 240 screen.

## Step 2: the view and the panel positions in the code

`FUN_00409420` (one-player setup, decompiled `DecompileMany.java 0x00409420 0x00409a00`) creates the game view and, in its first branch (`DAT_0048c7dc == 0`), sizes it:

```c
FUN_0041d1d0(&DAT_00480d50, &DAT_0048ca30, &DAT_0048c7e0, 2, 0, 0, 0x140, 0x98);   // a view at (0, 0), 320 x 152
FUN_00416cb0(&DAT_0048b4c0, 0x48c7e0, 0, 0, 0x140, 0x98);                          // the camera's view rectangle: 320 x 152
...
FUN_00412ad0(1);      // the panel
FUN_00418290(0x48b4c0);   // the vehicle choice at the start (document 95)
```

`FUN_00412ad0(1)` (document 66) puts the one-player panel at `x = 0x570000, y = 0xa80000` in 16.16, that is **(87, 168)**; the panel's frame cel 1940 (148 x 59) is drawn at (-3, -2) from it (template slot 2), the base cel (144 x 56) at the panel's origin. The other branch (`DAT_0048c7dc != 0`) is a second layout for another screen size: a 357 x 169 view at x = 13 and the panel at (116, 185); what sets `DAT_0048c7dc` is **untraced** (it is only read: `FindPointerRefsMulti.java 0048c7dc` finds eight reads and no write).

## Step 3: the strip is an image

The strip below the view is not drawn from cels. The game's `ART` folder has `1PBSCRL.RFA` (29,240 bytes) and `1PBSCRH.RFA` (113,720): plain BMPs (`tools/convert_rfa.py`) of **320 x 88** and **640 x 176**, i.e. the bottom 88 rows of a 240-row screen, in its low and high resolutions (the same low/high choice as the victory ribbons of document 92). Converted (`tools/extract_hud_strip.py`), the image is the rail, the two camouflage panels and the frame, with a black window in the middle where the panel's base picture goes. Rows 152-239 plus the 320 x 152 view make the 240-row screen. (`2PBSCRL/H.RFA`, 92 rows, are the two-player strips, `2PMSCR.RFA` the two-player map screen: not extracted.)

## Applied in the port

`GameSettings.hud_layout` (`"modern"` by default, `"classic"`; `user://settings.cfg` `[hud] layout`; `RF_HUD=classic|modern` for one run; `H` toggles it live in a debug build) and `game/hud_layout.gd`:

```gdscript
const VIEW_SIZE := Vector2(320.0, 152.0)
const STRIP_TOP := 152.0
const PANEL_POS := Vector2(87.0, 168.0)        # FUN_00412ad0: 0x570000, 0xa80000
const FRAME_OFFSET := Vector2(-3.0, -2.0)      # template slot 2, cel 1940

static func classic_scale(viewport: Vector2) -> float:
	return minf(viewport.x / SCREEN.x, viewport.y / SCREEN.y)   # the largest 4:3 picture that fits
```

- **Classic:** the 320 x 240 picture is scaled to the largest 4:3 rectangle that fits the window and centred, black outside it (`game/classic_frame.gd` draws that and the strip image). The panel (`game/hud_panel.gd`, now with a variable scale) sits at (87, 168) of the picture at the picture's scale, with cel 1940 under its base. The 3D camera follows suit (`terrain_view_3d.gd`): its horizontal field of view is widened so the top 320 x 152 rectangle shows the same width of world as the modern layout shows across the whole window, and the camera is moved along the ground so the followed vehicle sits at that rectangle's centre:

```gdscript
return rad_to_deg(2.0 * atan(tan(deg_to_rad(CAMERA_HFOV_DEG) * 0.5) * vp.x / view.size.x))   # _layout_fov_deg
...
return Vector3(x, height_px, z + _layout_shift_z(height_px, tilt_deg))
```

- **Modern:** unchanged: the view fills the window, the panel is 3x, 12 px from the left and 198 px above the bottom.

Checked by screenshots at 1152 x 648 (pillarboxed) and 1024 x 768 (a 4:3 window is filled exactly): the panel, frame, rail and camouflage line up with the reference frame, the tank sits at the view rectangle's centre, the modern layout looks the same as before (side by side), and the swoop-in works in the classic view. `tools/tests/hud_layout_check.gd` checks the arithmetic (8 checks).

## Not done / untraced

- **Port choices in classic:** the picture is scaled to the window with the low-resolution strip (the original picks the high-resolution image by display mode); the world scale of the view (the camera's mapping of the original's height and pitch, document 90) is not the original's, so the classic view shows the same world width as the modern one per view width, not the original's exact coverage; letterboxing to 4:3 is the port's.
- **The second layout** (`DAT_0048c7dc != 0`: the 357 x 169 view, panel at (116, 185)) and the **two-player screens** (two panels at x = 14 and 165 or 47 and 198, the two-player strips) are not built.
- **Overlays in classic:** the hangar screen, the loss skull, the win ribbon and the fades are still drawn to the whole window, not to the 320 x 240 picture; the placeholder labels are drawn over the black surround.
- The panel's slide-in animation and the radar's grid, brackets and background (document 70) are still not drawn in either layout.

**Next:** [the next-steps doc](NEXT_STEPS.md).
