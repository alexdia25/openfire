# 43. Worked example: the camera was a placeholder, and the tank's size was never traced

The user supplied three Win95 screenshots of the real game at the same spot on RFMAP001 (the
L-shaped road, garden plots and building site next to the spawn) and asked to "work on the scale
of the tank, etc." Our own render of that spot matched the scene, so the comparison was valid.

## What was measured

- Flat top-down (Camera2D, zoom 2) render: the grey road band is 47 screen px = **~24 world px**
  thick. The cel art itself confirms it: the pavement is painted inset within its 32x32 tile, with
  sand at the tile edges. So the road is narrower than one tile by design.
- The Tank box was built 64 px wide, from the hull-top cel's 64x64 texture (document 37's "8/3
  scale reproduces each face's sprite dimensions"). That matched proportions *between* parts, but
  the original stretches every cel to whatever its 3D projection gives, so **absolute size was
  never pinned by the texture size**. The result was a tank ~2.7x wider than the road; the
  reference shots show it about road width.

## What was changed

1. **Camera** (`game/terrain_view_3d.gd`): height 260 / Godot's default 75-degree FOV were
   placeholders (the file header said so). The plan already had a traced value: the perspective
   focal length is exactly 300.0 in native 320-px-wide units (section 1.10 point 6) -> horizontal
   FOV 2*atan(160/300) = 56.63 degrees. A camera 300 units from the target (height 300/sqrt(2) =
   212.13 at the traced 45-degree tilt) spans exactly 320 world px across the screen, i.e. the 1:1
   native scale the reference shots were taken at (~10 tiles across). The FOV is traced; that it
   maps 1:1 to the original's on-screen scale is inferred from the reference shots.
2. **Tank scale** (`game/vehicle_box_3d.gd`): `VEHICLE_SCALE = 0.4`, **an estimate, not a trace**
   (tank ~26 native px long in the reference vs 65 built; road ~24 px). Check by screenshot at
   spawn: hull now about road width, palm canopies ~1.5-2x tank width, as in reference shot 1.
   Trees were left alone. Enemy vehicles share `VehicleBoxRender3D`, so they scale too; no gameplay
   hit radius depends on vehicle size yet.

## Registry fix found along the way

Cels 73-79, 81-83, 88, 89 were labelled `terrain.structure.rooftop_red.*` but are grey pavement;
renamed `terrain.ground.pavement.01-12`. Cel 87 (wooden planks) -> `terrain.ground.wood_planks.04`.
Hand-edited (not via `main()`), noted in `classify_batch1.py`, pack rebuilt, screenshot identical.
Not done: cels 52-55 are labelled water/forest_water but look like plain sand in the atlas; unverified.

## Trees (same day, follow-up) -- SUPERSEDED by document 44

The 0.5 palm scale and 0.4 tank scale below were estimates; document 44 replaces both with values
traced from RFIRE.BIN (tank 0.375, palm geometry from real corners). Kept as the story of how the
estimate arose.

Measured against the reference at the calibrated camera: palm canopy ~36 native px wide / ~38
tall here vs ~18 / ~21 in the reference shots; small ground bushes already matched (~half the
tank's width in both). `PALM_SCALE = 0.5` in `game/decoration_field_3d.gd` now scales only the
palm compositions (trunk card, canopy cards, trunk height, ring spread); ground-level decorations
stay at 1.0. Again **an estimate, not traced** (decoration corner data was never decoded, document
35). After: palm canopy ~0.8x tank width vs ~0.65x in reference shot 1 -- close, not exact.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
