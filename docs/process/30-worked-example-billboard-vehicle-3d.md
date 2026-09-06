# 30. Worked example: the same frame-selection code, a different last step

[Document 29](29-worked-example-baked-terrain-3d.md) covered Phase 2 (real terrain art baked
onto the 3D scaffold's ground plane). This document covers Phase 3: a real vehicle, rendered
as a billboard `Sprite3D`, reusing `Vehicle._frame_for_heading()` — the exact quadrant-mirror
frame-selection logic [document 25](25-worked-example-turning-sprite-video.md) found and fixed
a real bug in — completely unchanged.

## Extract the presentation, not the logic

Phase 2 already established this project's pattern for this kind of migration: pull the
reusable piece out into its own small node rather than duplicating it (`terrain_tile_
renderer.gd`). Phase 3 needed something slightly different, though — `Vehicle` isn't just a
draw function, it's the actual owner of movement integration, input handling, and firing.
Duplicating *that* into a 3D-flavoured copy would be a real regression risk (two physics
implementations to keep in sync, not just two draw calls).

So `game/vehicle_billboard_3d.gd` doesn't reimplement anything. It holds a reference to a
completely real, completely unmodified `Vehicle` instance — still running its own
`_process()`, still responding to `RF_DEBUG_DRIVE`/`RF_DEBUG_HEADING`/`RF_DEBUG_FIRE` exactly
as it does in the flat 2D scene — and every frame calls `vehicle._frame_for_heading(vehicle.
heading_deg)` directly, the same private-by-convention method `Vehicle._draw()` itself calls.
The only thing that changes is the last step: instead of `draw_set_transform` + `draw_texture_
rect_region`, the result feeds a `Sprite3D`'s `region_rect`/`flip_h`/`flip_v` properties.
`Vehicle.visible = false` suppresses its own (now redundant) 2D draw output; Godot still calls
its `_process()` every frame regardless, since visibility only gates rendering, not
processing.

## Coordinate mapping falls out for free

Because `Vehicle.position` is already a plain 2D pixel coordinate in the same X-right/
Y-down convention `terrain_tile_renderer.gd` and the 3D scaffold's own camera-follow math
already use, `VehicleBillboard3D` needed no new coordinate conversion beyond Phase 1's
already-established `Vector3(x, height, y)` mapping. The camera-follow code in `terrain_view_
3d.gd` didn't change either — it already took a plain `Vector2` for "the point to look at";
it just now receives `vehicle.position` directly instead of a placeholder box's position.

## A legitimate worry, checked rather than assumed

Billboarding raises a real question, not just a hypothetical one: the vehicle art is
pre-rendered from one *fixed* viewing angle (45 degrees, section 1.10 point 6). If `Sprite3D`'s
billboard mode reoriented the sprite based on the *actual* direction from the vehicle to the
camera -- a "look-at" style billboard -- it would reintroduce exactly the position-dependent
hidden rotation [document 28](28-worked-example-3d-camera-scaffold.md) already found and fixed
once in the camera itself: the sprite would tilt slightly differently depending on where it
sits on screen, which would be wrong, since the source art assumes one constant angle no
matter where the object is relative to the frame.

Godot's `BILLBOARD_ENABLED` is documented to work differently -- it copies the camera's own
rotation basis onto the object directly, not a per-object vector toward the camera's current
position -- but "documented to" isn't this project's standard of evidence. Checked instead:
driving the vehicle to a heavily edge-clamped position (well off-centre on screen, past where
the camera's translation stops keeping it centred) and comparing its rendered sprite against
the same heading rendered dead-centre. Pixel-identical, no skew or distortion difference.
Since the camera's rotation is constant everywhere (Phase 1's whole point), the billboard's
orientation is provably constant too, with zero dependency on where the vehicle drifts on
screen -- confirmed, not assumed.

## Verification

- A static screenshot: the real hovercraft/tank art (the same sprite the flat 2D scene
  renders) appears at the correct spawn position, sitting on the same small road-corner
  structure tile the flat scene's screenshot already showed there.
- A 12-heading sweep (`RF_DEBUG_HEADING=0,30,60,...,330`, camera zoomed in via `RF_DEBUG_
  CAMERA_HEIGHT_PX`), matching the verification style [document 21](21-worked-example-vehicle-mirroring-bug.md)
  used for the original mirroring-bug fix: the billboard's silhouette changes correctly and
  smoothly across every heading, with no discontinuity at any quadrant boundary — the exact
  failure mode document 21 found and fixed is confirmed still fixed when driven through this
  new rendering path.
- A driven test (`RF_DEBUG_DRIVE=1`, a curving turn) with `RF_DEBUG_CAMERA_LOG=1`: real
  position numbers confirm the vehicle moves under its own real physics and the camera follows
  smoothly, over real terrain, with a real rotating vehicle sprite — all three rendering-layer
  phases (terrain, camera, vehicle) working together for the first time.

## What's still a placeholder

Firing isn't wired up in the 3D scene yet — `Vehicle.fired` has no listener here, so
`RF_DEBUG_FIRE` would compute cooldowns and print but nothing would appear. Projectiles,
target/pool markers, and the flag marker are Phase 4, following the exact same "extract the
presentation, keep the logic" pattern this phase and Phase 2 both used.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
