# 33. Worked example: finishing the rendering migration means extracting the game, not just the picture

[Document 30](30-worked-example-billboard-vehicle-3d.md) and
[document 32](32-worked-example-ground-decal-prototype.md) got the vehicle rendering right in
3D. What was left of the rendering-migration plan — Phase 4 — was everything else that moves
or matters during a match: projectiles, the candidate-pool target markers, and the flag that
spawns once a pool goes silent. Doing this properly surfaced a problem the first three phases
had managed to avoid: `game/terrain_view.gd`'s *gameplay* logic, not just its drawing, had
never been separated from that one file.

## The problem Phase 4 couldn't route around

Phases 2 and 3 each extracted one piece of *drawing* code into a shared node
(`TerrainTileRenderer`, then the `Vehicle`/`VehicleBillboard3D` pairing) precisely so the flat
2D scene and the new 3D scene could reuse it unchanged. But the actual rules governing a
match — which vehicle spawns where, what happens when a projectile reaches a target, when a
pool goes silent and a flag appears — still lived entirely inside `terrain_view.gd`'s own
`_ready()`/`_process()`/`_draw()`, written directly against that one scene. Porting Phase 4
by copying that logic into `terrain_view_3d.gd` a second time would have worked today and
been exactly the kind of two-copies-that-can-silently-diverge risk this project has a standing
cautionary tale about (`classify_bulk.py`'s own unfixed auto-numbering bug).

So Phase 4 started with an extraction Phases 2/3 didn't need: a new `game/match_controller.gd`,
a plain rendering-agnostic `Node`, absorbed vehicle/enemy spawning, projectile spawn-on-fire,
`TargetPool` hit-testing, and the flag-spawn trigger — all of it unchanged from what
`terrain_view.gd` already did, just moved. It spawns real gameplay nodes as children of
whatever `world` node its caller passes in, and emits signals (`projectile_spawned`,
`flag_spawned`, `target_hit`) when it does, rather than assuming anyone drawing a specific way.
`terrain_view.gd` shrank to: create a `MatchController`, let each spawned node draw itself
directly (exactly as before), done. Both scenes now run the literal same class for match
rules — not two copies that happen to agree today.

## Pairing nodes, not new logic

With the rules extracted, Phase 4's actual 3D work followed the pattern Phase 3 already
proved out: a real, unmodified, invisible logic node paired with a 3D presentation node.

- **`ProjectileBillboard3D`** pairs with a real `Projectile` (unchanged movement/lifetime
  logic) and shows a small flat-coloured sphere — honestly a placeholder, matching
  `Projectile._draw()`'s own circle. No confirmed in-flight-projectile art has turned up in the
  asset registry, so there's no real texture to reuse here the way `VehicleBillboard3D` reuses
  `Vehicle._frame_for_heading()`.
- **`FlagMarker3D`** pairs with a real `FlagMarker` and reuses document 32's winning
  `GROUND_DECAL` technique — a flat, unbillboarded quad lying in the ground plane, showing the
  real `marker.capture_flag.<team>` animation frames. Unlike the vehicle, the flag never turns,
  so unlike `VehicleBillboard3D` there's no per-frame yaw to apply here at all.

Both connect to `MatchController`'s new signals rather than being polled: `terrain_view_3d.gd`
creates one the instant a projectile is fired or a flag spawns, and each frees itself when its
paired logic node does.

## The one piece with no gameplay node to pair with

The candidate-pool target markers and spawn-point circles were never drawn by a dedicated
gameplay node in the first place — they were just inline `_draw()` calls reading
`TargetPool` state directly. There was nothing to pair a billboard with. So this piece got
Phase 2's treatment instead of Phase 3's: the drawing itself was extracted into a reusable
`game/debug_marker_renderer.gd` (the same move `TerrainTileRenderer` made for tiles), and
`game/debug_marker_overlay_3d.gd` bakes it onto a second, transparent `SubViewport`-backed
plane sitting just above the real terrain ground plane. Unlike the terrain bake (rendered once,
since tile art never changes after load), this overlay's `SubViewport` re-renders every frame,
since target state changes as the match plays out.

## Verification

A driven run (`RF_DEBUG_DRIVE=1 RF_DEBUG_FIRE=1`, the same hooks every prior phase used) in the
3D scene confirms all of it working together, not just compiling:

- The tan spawn-marker circle and the pool's magenta target square both foreshorten correctly
  under the tilted camera, exactly the way the terrain itself does — proof the overlay bake is
  going through the same real camera projection as everything else in the scene, not a flat
  screen-space overlay pasted on top.
- A projectile sphere is visible in flight, tracking the real `Projectile` node's position.
- Once the pool's one candidate is destroyed and its budget is exhausted, the real green
  capture-flag animation appears at the correct world position, lying flat and
  perspective-projected the same way the vehicle does.

The same driven run against the *flat* 2D scene, after the `MatchController` extraction,
prints the identical sequence of fired/destroyed/flag-spawned events it always has — the
extraction changed where the logic lives, not what it does.

## What this actually finishes, and what it doesn't

This was the rendering-migration plan's last phase. With it done, `game/terrain_view.gd`/
`.tscn` has nothing left it does that the 3D scene can't — which is exactly the precondition
the "Superseded rule" (recorded when the user retired the "keep the flat 2D scene fully
working" rule, the same day) set for retiring it as a whole. That retirement — deleting or
marking the file superseded, matching `tools/rfcel.py`'s own precedent — is a deliberate,
separate follow-up, not bundled into this change.

Still explicitly not here: split-screen/4-player, and anything past the flag-spawn *trigger*
(pickup, carrying, a home-base check, declaring a match won or lost) — `MatchController` only
ever implemented the trigger, the same honest boundary the flat 2D scene always had.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
