# 37. Worked example: the Tank was never a flat sprite

Chasing the user's "why is there never any visible tread" observation all the way through
found something bigger than a missing texture: `vehicle.hovercraft.rotation.tan.01-09`
(cels 218-226), the art this project has rendered as "the Tank" since Phase 4 step 2, isn't
the game's real Tank art at all. The real Tank is a genuine six-face 3D box, traced directly
out of RFIRE.BIN's own per-vehicle-type data.

## Two bugs first, found on the way

Before any of this, the user reported the tank's visible front always faced one screen
direction while pressing forward moved it 90 degrees away from that direction. Direct atlas
inspection of cel 218 confirmed it: the front-indicator nub in the raw, unrotated cel points
toward the bottom of the image, not the right edge, even though `vehicle.gd`'s own convention
says heading 0 means facing +X (screen right). `game/vehicle_billboard_3d.gd`'s
`GROUND_DECAL` rotation assumed the opposite -- an assumption checked only against a Phase 1
placeholder box's own rotation for internal consistency, never against what the real art
depicts. Comparing a straight (turn=0) driven run's real movement direction against the
rendered nub direction found the fix empirically: `rotation_degrees.y = -heading_deg + 90.0`.
Fixed and shipped before any of the rest of this was known.

## Finding the real Tank

None of the 9 rotation frames contain tread pixels at all -- confirmed at full zoom, every
frame. But `vehicle.hovercraft.track.01`/`.02` (cels 182/183) turned out to be a real,
completely unused tank-tread graphic -- wheels, sprocket, track links, tan and green -- sitting
in the registry the whole time. Nearby cels (167-214) were full of other unreferenced vehicle
parts: hull variants, a "turret_detail," "wheel_hub" pieces.

Tracing how a vehicle actually gets built and drawn took several steps, each correcting the
last:

1. **The tile-dispatch spawn handler** (`FUN_00413e00`, dispatch_idx 1) turned out to be a
   dead end for this purpose -- it only records a spawn position for later, it doesn't
   construct anything.
2. **The generic object constructor** (`FUN_0042d640`, document 31) copies an 11-slot shared
   vtable into a new per-instance record and stores it at the object's `+0x3c` -- but that
   vtable's only two real slots are the facing-table function (already known) and one other,
   neither a "draw" callback pointing at anything decoration-like.
3. **The real per-team vehicle spawn function**, found by searching for data cross-references
   to the recorded-spawn-position table (not a call-instruction search -- the same
   "literal-address xref" technique document 31 needed for the facing table): `FUN_0040b510`
   calls a generic `FUN_0042c290(type_descriptor, team, x, y, ...)`, the exact same function
   already known from document 26 to construct the flag marker with a *different*
   type-descriptor argument. `type_descriptor` here comes from a 4-entry table at
   `0x004452d8` -- one entry per vehicle type.
4. **Reading each entry's own name string** (a field 4 bytes into each 744-byte record)
   confirmed it directly: entry 0's name string is literally `"Tank"`.

## The real geometry

Entry 0's render descriptor lists **6 real parts**, each a flat `ART.CAR` cel plus **local 3D
corner coordinates** -- not screen-space offsets, actual object-space geometry:

| Part | Cel (tan/green) | Shape |
|---|---|---|
| Bottom | 167/168 | flat, at the base |
| Top | 172/173 | flat, at full height -- the detailed "hull-top" cel with headlight/hatch-like ports |
| Left tread | 182/183 | vertical side face |
| Right tread | 182/183 | vertical side face (mirrored) |
| Front detail | 187/188 | small vertical accent |
| Back detail | 187/188 | small vertical accent (slightly beveled in the original; approximated as flat here) |

The fixed-point-to-pixel scale factor (8/3) was confirmed, not assumed -- it reproduces every
face's own real sprite pixel dimensions (64x64, 64x16, 16x16) exactly from the raw corner
spans. Team colour is a flat +1 cel offset (167->168, 172->173, 182->183, 187->188) --
confirmed by direct visual comparison of each pair, not guessed from the offset math alone
(cel 188 was actually misclassified in the registry as `decoration.stripe_band.01`; corrected
to `vehicle.hovercraft.hull.21` after visually confirming it's the green rivet-detail
counterpart to 187).

This is a genuine box: two flat horizontal faces (bottom, top) five pixel-units apart in
height, and four vertical side faces standing between them. The "little triangles" and
"no visible tread" complaints, and the very first observation that started this whole
thread -- the tank showing different amounts of visible tread depending on camera
positioning -- are all the same fact: the original vehicle is real 3D geometry with height,
not a flat card at any orientation, so a tilted camera naturally reveals more or less of its
side faces depending on where it sits in frame. No hand-ported projection formula was needed
to reproduce this -- placing six real, correctly-sized quads at their real relative positions
and letting Godot's own camera project them does it, the exact same "let the real camera do
the foreshortening" approach this project already used for terrain and decorations.

## Implementation

`game/vehicle_box_3d.gd` (`VehicleBoxRender3D`) builds six `Sprite3D` children at the derived
local positions, each cropped to its own cel's region, and re-textures all six through the
+1 team-colour offset. It's now `game/terrain_view_3d.gd`'s default vehicle presentation;
`VehicleBillboard3D` (the flat-card approximation) is kept as a debug fallback
(`RF_DEBUG_VEHICLE_RENDER=billboard`) for comparison, not deleted.

The same kind of facing check the GROUND_DECAL fix needed came up again here, for a different
reason: the real box's tread faces sit offset along local X (the vehicle's width axis).
Driving straight and comparing the rendered orientation against the real movement direction
found the box needed the identical `+90` correction GROUND_DECAL did, confirming both fixes
share the same root convention rather than being two coincidentally-equal numbers.

## Result

A real, driven screenshot shows the Tank's tread clearly and continuously visible along
whichever side faces the camera, coherent through a full turn, in both team colours -- not
approximated, not a placeholder, the game's own real art in its own real arrangement.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
