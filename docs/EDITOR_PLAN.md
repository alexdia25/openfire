# Vehicle and map editor — plan

*A plan, not a record of work done (2026-09-24).* It builds on [`PORTING_PLAN.md`](PORTING_PLAN.md)
section 2.7, the moddability design: layered packs and loose-frame art (steps 1-2, done), vehicle
definitions and behaviour modules (steps 3-5), map rosters and override files (step 6). The editor is
step 7. This document says what the editor does, what it needs from the earlier steps, and in what
order to build it.

**Scope.** View, visually edit, and create from scratch: **vehicles** (numbers, behaviour modules and
their parameters, parts and geometry, animated parts, weapons and fire directions, collision shape, HUD
and selector entries) and **maps** (terrain, decorations and buildings, spawn points, target pools,
rules, vehicle roster). **Out of scope:** drawing or editing pixels. Sprites are made in other tools; the
editor imports PNGs, assigns them to sprite ids and sets pivots (user direction, 2026-09-24).

## 1. Principles

1. **The editor edits pack data, never code.** Everything it can change is something `Pack` and
   `LevelData` already load. If a feature needs a code change to be editable, that change belongs in the
   runtime (as data plus a module), not in the editor.
2. **The workspace is a mod pack.** Opening the editor means opening (or creating) a pack directory
   whose `pack.json` names `original_pc` as its `base_pack`. Every edit is written into that mod layer
   only, per id (2.7.4). `packs/original_pc` is generated output and is never written to. Un-editing
   something removes its override and the base value shows through again.
3. **Preview with the real game code.** Viewports draw with the runtime's own renderers
   (`VehicleRender3D`, `TerrainTileRenderer`, `DecorationField3D`, ...), and "play test" runs the real
   `MatchController` on the edited stack. The editor contains no second copy of any game logic.
4. **Show provenance.** Every value is traced (with its document number), a port choice, visual only, or
   user-authored. The editor shows that badge next to the value and never presents a guess as traced
   (standing rule, see `docs/process/NEXT_STEPS.md`). The sources: registry `confidence`, `_untraced`
   notes in definitions, and a per-field `provenance` in module schemas (section 4.2).
5. **Mods must not redistribute original assets.** Exporting a mod writes only the mod layer: new or
   replaced sprites the user imported, plus data. Original art is referenced by sprite id through
   `base_pack`, never copied into the mod. This keeps shared mods legally clean in the same way the
   repo is (section 0 of the plan).
6. **Gameplay data is hashed.** Anything that changes gameplay (not art) goes into the pack's netplay
   identity (2.4.3 item 8). The editor shows whether a mod is art-only or changes gameplay.

## 2. Where it lives

A **separate main scene inside this Godot project** (`editor/`), built as ordinary Godot UI (`Control`
scenes, as section 2.6 requires for all UI), launched with `--editor` or from the main menu once that
exists. It is desktop-only: the web build has no writable filesystem (2.5.1), so the editor is not part
of the web export.

Why not a Godot editor plugin: modders shouldn't need Godot installed, and packs never go through
`res://` import, which is the only thing plugins make easy. A plugin could be added later on top of the
same code if it's ever wanted.

```
editor/
  editor_main.tscn        workspace picker, tabs: Vehicles | Maps | Assets | Validate
  workspace.gd            the open mod pack: layer stack, dirty ids, save, undo/redo
  pack_writer.gd          the inverse of Pack's loader: writes one layer's files, per id
  commands/               one undoable command class per kind of edit
  vehicle/                vehicle editor: tree, inspector, 3D viewport, gizmos, sandbox
  map/                    map editor: 2D grid view, 3D preview, tools, layers, rules
  assets/                 sprite browser, PNG import, pivot setter
  widgets/                typed field editors (fixed point, ticks, angles, sprite picker ...)
```

## 3. Shared foundation (needed by both editors)

- **Workspace and layered save.** It opens a mod directory and loads the stack through
  `Pack.load_from()`. It tracks which ids the user touched, and `pack_writer.gd` writes only those into
  the mod's own `sprites/sprites.json`, `vehicles/<id>/vehicle.json`, `levels/...`, etc. Each value has a
  "revert to base" action that writes `null` or drops the key.
- **Undo/redo.** Every edit is a command object (`do()` / `undo()`, merged while a slider is dragged),
  on one stack per open document.
- **Hot reload.** After a save, the stack reloads in place (2.4.4 already asks for this) so play test and
  the viewports pick it up without restarting.
- **Asset browser.** Every sprite id in the stack, grouped by the registry's object folders
  (`vehicle/tank`, `structure/...`), searchable, with the registry's confidence and note. It shows which
  layer provides each sprite and where the sprite is used (vehicle parts, tiles, decorations, HUD).
- **Sprite import (not editing).** Drop in a PNG and choose "replace sprite X" (writes a loose frame into
  the mod, 2.7.5) or "new sprite" (you name the id). Set the pivot by clicking on the image. Team variants
  and the hit-flash variant are separate sprites that you assign; nothing is auto-generated. (A "tint a
  flash variant" helper could come later, but it would be a port convenience and labelled as one.)
- **Validation panel.** Live `validate_pack` checks (the Python validator's rules ported to GDScript or
  shared as data), plus the map and vehicle rules in sections 4.6 and 5.6. Clicking an error jumps to the
  thing that caused it.
- **Typed fields.** The original's units are awkward, so every numeric field has a unit-aware widget:
  16.16 fixed point shown as a decimal, per-tick values shown with per-second equivalents (the tick is
  16 ms), headings in 5.625-degree steps *and* degrees, sizes in world units (a tile is 32). The file
  always stores the definition's own unit; the widget only converts for display.

## 4. Vehicle editor

### 4.1 Layout

- **Left: vehicle list and definition tree.** The four originals (`rf.tank`, `rf.jeep`, `rf.msv`,
  `rf.heli`) plus the mod's own. Under each vehicle: `stats`, `shape`, `drive`, `aim`, `inputs`,
  `weapons[]`, `water`, `events`, `render`, `hud_panel`, `selector`, `wreck`, the same sections as the
  2.7.2 definition.
- **Centre: 3D viewport.** The vehicle is drawn by the general descriptor renderer (after step 5 the
  Tank uses it too), on a turntable with an orbit camera, a team toggle (tan or green) and a hit-flash
  toggle. The overlays can each be switched on or off:
  - the collision polygon and its z range, as a translucent prism
  - weapon mounts and muzzles as markers, with arrows for each fire direction and pitch (e.g. the Tank's
    level and raised shots, the Heli's toed-in down guns); an arrow's length reflects the projectile
    type's speed
  - part outlines, and part numbers matching the descriptor's order
  - the pivot of any part that animates
- **Right: inspector** for whatever is selected in the tree or the viewport.
- **Bottom: channel scrubbers.** One slider per channel the vehicle's modules publish (`aim.yaw`,
  `aim.pitch`, `rotor.speed`, `weapon0.salvo_index`, `swim`, `distance`, ...). Dragging one poses the
  vehicle without driving it: turn the Tank's turret, spin the Heli's rotor through its modes, empty the
  MSV's canister rack. A "play" toggle runs the channels on their real update rules instead.

### 4.2 Behaviour modules and their schemas (the requirement this puts on step 4)

The inspector cannot hand-code a form for every module, so **every behaviour module must publish a
parameter schema**, and step 4 should be built with this in mind:

```jsonc
// one entry per module, e.g. the "rotor" drive model
{ "module": "rotor", "slot": "drive", "doc": "Heli flight (FUN_0040e0e0, document 63)",
  "params": {
    "strafe_speed": { "type": "float", "unit": "units/tick", "default": 0.8,  "provenance": "traced:63" },
    "bank_steps":   { "type": "float", "unit": "steps",      "default": 3.0,  "provenance": "traced:63" },
    "ceiling":      { "type": "float", "unit": "units",      "default": 50.0, "provenance": "traced:63" } },
  "channels": ["rotor.speed", "bank", "pitch"],
  "events":   ["on_create", "on_land"] }
```

- **Slot pickers** (`drive.model`, `aim.model`, `weapons[n].handler`, `water.model`, `special`) list the
  modules registered for that slot. Choosing one fills in its defaults; the old parameters are kept aside
  so switching back doesn't lose them.
- **Inputs** show the three buttons of the original (`+0x17c..+0x190`) as a small matrix of button to
  weapon slot or action, including "raised" variants. This is where the secondary action is set.
- **Events and sequences** (e.g. the Heli's start-up and landing) are an ordered list of steps: play a
  sound (with a cue picker that can preview the sound), run a sequence module, wait some ticks.
- Adding a *new kind* of behaviour means adding a module in the engine (a code change, per the 2.7
  design). The editor only lists and configures existing modules; it never takes script input.

### 4.3 Visual part and geometry editing (depends on step 5)

- **Parts.** Select a part in the viewport or the part list. Change its sprite (the three ids tan, green
  and flash, picked from the asset browser). Drag its four corners with a gizmo, or type them in; there
  is optional snapping to the definition's own grid (quarter units, the original's 16.16 values rounded).
  Add, delete, duplicate and reorder parts (order is draw order).
- **Animated parts** bind to a channel: *rotate about pivot by* (turret, rotor), *pick sprite by* (the
  Jeep's wheel strip, the MSV's canisters: a list of sprite ids indexed by the channel), or *move corners
  by* (the MSV rack's slide). The binding editor shows the scrubber from 4.1 so the result is visible
  straight away.
- **Collision shape.** A top-down 2D view of the polygon with draggable points, plus z-min/z-max fields
  and layer/mask checkboxes. The traced Tank shape (`0x43e8f8`, document 53) is shown as the reference
  whenever the vehicle is based on it.
- **Mounts and muzzles** are draggable markers in the viewport. Their pitch and toe-in are set with arc
  handles; the numbers stay in the inspector.

### 4.4 Sandbox and test drive

A small built-in test map (flat ground, water, a road strip, a wall, some targets, a home pad) that runs
the real `Vehicle` and `MatchController` on the edited definition, with overlays showing speed against
cap, turn rate, fuel burn, ammo, cooldowns and collision contacts, and a key display of the three buttons.
"Drive on map ..." starts the same thing on any real level instead.

### 4.5 Creating a vehicle from scratch

- **New from template:** copy one of the four originals under a new id (`mymod.hovertank`). This is the
  expected path, because it starts from a working, traced set of modules and numbers.
- **New blank:** pick a module for each slot from its defaults, choose sprites for a minimal part set
  (the editor offers a one-quad top part and a box of six quads as starting geometry), then set stats.
- The new vehicle appears in the roster editor (5.5), with an optional HUD panel layout (copied from a
  template) and a selector picture and icon.

### 4.6 Vehicle validation

Checks that every sprite id exists; that every module named is registered and every required parameter
is set and in range; that the collision polygon is convex and non-empty; that every weapon names a
projectile type that exists; and that every channel a render binding uses is published by one of the
vehicle's modules. Warnings for values outside anything the four originals use (not errors: a modder may
want them). Where a field is traced, the panel says so if the value moved away from the traced value.

## 5. Map editor

### 5.1 What a map is (and the one real constraint)

A converted map (`levels/<ID>/`) is `art.bin`, a width x height grid of art ids (0-111, 128 x 128 in all
204 original levels), plus `level.json`: `decorations` (per cell: `coastal_id` and a team `variant`,
which the pack resolves to buildings, trees, gates, pads, and collision, damage and water behaviour),
`spawn_points` (team 0 always; team 1 in the 104 two-player maps), `candidate_pools` a / b (building or
target candidates; one is picked at random per pool), `vehicle_params` (stock T/J/A/H and M), `levl_value`,
and `tile_seed`.

**In the original, each cell is one raw tile value**, expanded by a fixed table (`PRIMARY_TABLE`, used by
`tools/convert_rfm.py`) into art id, coastal id and variant, with four special values meaning spawn or
candidate markers. The port's format already splits those fields apart. So:

- **Original-compatible mode** (the default when editing an original map): the tile palette is the
  original's raw tile table, so every cell stays a combination the 1996 game could have produced.
- **Free mode** (new maps, or on request): art, decoration and variant are painted independently. This
  can create combinations the original never had; the editor marks the map as "extended" (it could
  never be written back as an `.RFM`, which the port doesn't need to do anyway).
- Known gap: the terrain under an original spawn or candidate marker isn't recoverable from the file
  (`convert_rfm.py`'s note). The editor shows those cells with the converter's fallback art and a badge.

### 5.2 Views

- **2D grid view (main editing view):** a top-down, one-sprite-per-cell drawing using the tileset, with
  decoration icons on top. It is fast at 128 x 128 and supports zoom, pan, a grid, a coordinate readout
  and a hover inspector.
- **3D preview:** the real `terrain_view_3d` renderers, with a free camera or the game camera, updated
  on each edit (or on demand for very large edits). This is where the jitter of decorations
  (`tile_seed`) and the real building heights are visible.
- **Radar minimap** (the real `RadarView`), used to navigate.

### 5.3 Layers and tools

Layers, each shown and locked independently: **terrain** (art ids), **decorations and buildings**
(coastal id + variant), **markers** (spawns, pool A, pool B), and **overlays** that are read-only
(collision shapes, water class 0/1/2 from the water tables, destructible hit points, road speed tiles).

Tools: paint, rectangle, flood fill, line, eyedropper, select / move / copy / paste, and stamps
(multi-cell patterns saved from a selection, e.g. a base layout or a stretch of coast). The palettes are
the tileset (grouped by `terrain_class`: ground, coast, ...) and the decoration types (grouped by what
they spawn: building, tree, gate, pad, flag), each with a preview picture. For team-owned objects there
is a variant toggle (tan or green). Coasts are painted by hand from the coast tiles to begin with; an
auto-coast brush needs the coast-to-water rules traced first (see 5.7).

### 5.4 Rules and metadata panel

Name, author, the difficulty/level number (`levl_value`, 0-8), mines (`M`, or derived from `levl_value`
when unset, document 75), one or two players (whether a team-1 spawn exists), and `tile_seed` (with
"re-roll" and "keep original"). Unrecognised original chunks (`EDTN`, ...) are kept and shown read-only.

### 5.5 Vehicle roster

This is the per-map override from 2.7.3. By default the list shows the pack's roster (`rf.tank`,
`rf.jeep`, `rf.msv`, `rf.heli`) with stock from the map's `vehicle_params`. The editor can change the
stock, remove a vehicle, or add one of the mod's vehicles with its own stock, and has "reset to default".
The selector screen has four bays today, so a roster of more (or fewer) than four needs the selector
layout made data-driven as well. That is flagged as a dependency, not something to solve in the editor.

### 5.6 Saving: patches for original maps, full files for new maps

- **Editing an original map** writes `levels/<ID>/level.override.json` in the mod: the roster override,
  rule changes, and a **cell patch list** (`[{x, y, art, coastal, variant}]`, plus marker additions and
  removals). This is small, easy to review, and survives re-running the converter. When a patch gets
  large, the editor offers "fork as a new map" instead.
- **New map / fork** writes a complete `levels/<NEWID>/level.json` and `art.bin` into the mod, the same
  format the converter produces, so `LevelData` loads it without changes.
- **Map validation.** Exactly one team-0 spawn; a team-1 spawn only in two-player maps; at least one pool-B
  candidate (every original has one); spawns on a home-pad tile; markers inside the map; every decoration
  id known to the pack; the team-0 base reachable by at least one roster vehicle (a flood fill using the
  collision and water overlays; a warning, not an error). Rules that come from traced behaviour cite
  their document (e.g. the flag-spawn condition, document 26); rules the editor made up are labelled as
  editor checks.

### 5.7 Creating a map from scratch

New map: choose a size (128 x 128 by default; other sizes allowed but marked "extended" until the port
confirms nothing assumes 128), a base tile to fill with, and one or two players. The editor places
starter home pads and spawns from a stamp library built from the original maps' own base layouts, so a
new map is playable immediately and play test works from the first minute.

## 6. What the editor needs from the plan 2.7 steps, and new runtime pieces

| Needed | From | Used by |
|---|---|---|
| Layered packs, per-id overrides | 2.7 step 1 (done) | everything |
| Loose-frame sprites, no cel arithmetic | 2.7 step 2 (done) | sprite import, part sprites |
| Vehicle definitions (`vehicle.json`) | 2.7 step 3 | vehicle tree, inspector |
| Behaviour modules **with parameter schemas and published channels** | 2.7 step 4 (schemas are a new requirement, 4.2) | inspector, scrubbers |
| Render descriptors bound to channels; Tank on the general renderer | 2.7 step 5 | part editing, animated parts |
| Rosters, `level.override.json` | 2.7 step 6 | roster panel, map saving |
| `pack_writer.gd` (inverse of `Pack`'s loader) | new | saving |
| `LevelData` save and patch apply | new | map saving |
| Hot reload of the pack stack | new (2.4.4) | viewports, play test |
| Data-driven selector layout (more or fewer than four bays) | new, found by this plan | rosters of other sizes |
| A raw-tile-table export of `PRIMARY_TABLE` into the pack | new | original-compatible palette |

## 7. Build order

Each phase ends with something usable, and later phases only add to it.

- **E0. Foundation** (can start now): workspace, `pack_writer.gd`, undo/redo, asset browser, sprite
  import, validation panel. *Result:* re-skin any sprite in a mod without touching JSON by hand.
- **E1. Read-only viewers** (can start now): the map viewer (2D and 3D, layers, overlays, radar) and the
  vehicle viewer (turntable, overlays, today's `vehicle_types.json` numbers shown read-only). *Result:*
  inspect any original map or vehicle, with provenance.
- **E2. Map editing** (needs step 6 for rosters and overrides; terrain, decorations and markers can come
  earlier by writing forked maps): tools, palettes, rules panel, patch and fork saving, play test.
  *Result:* edit or create maps.
- **E3. Vehicle numbers and behaviour** (needs steps 3-4): inspector with schemas, slot pickers,
  inputs matrix, events, sandbox test drive, new-from-template. *Result:* retune or recombine vehicles.
- **E4. Vehicle visuals** (needs step 5): part and corner gizmos, channel bindings, collision and mount
  editing, blank vehicles. *Result:* build a new vehicle's look and animation in the editor.
- **E5. Polish**: stamps library, roster sizes other than four (after the selector is data-driven),
  mod export (mod layer only, never original assets), a netplay "gameplay-changing" indicator, and
  docs for modders.

E0 and E1 don't depend on anything unfinished, and E1 is a useful check on steps 3-6: if a field
can't be shown clearly read-only, it will be harder still to edit.

## 8. Open questions and risks

- **Untraced map mechanics** limit what the editor can promise: coast-to-water rules (auto-coast),
  what `mode_byte` does beyond the player count, and the submarine's object class (cels 630-654;
  see `docs/process/NEXT_STEPS.md`), which may turn out to be a placeable map object.
- **Module granularity.** If step 4 ends up with coarse modules (one per original vehicle), the editor
  can only swap whole vehicles' behaviour. The schemas should aim for the slot granularity of the
  original record (drive, aim, each weapon slot, water, special) so mixing works.
- **128 x 128 assumptions** in the runtime (radar, camera limits, jitter table) need checking before
  other sizes leave "extended".
- **More or fewer than four vehicles** touches the selector, the HUD panel and `SELECT_NEIGHBOURS`; a real
  dependency for the roster editor (5.5).
- **Gameplay hashing** (principle 6) needs a defined canonical form of the gameplay data, likely
  sorted JSON of every non-art table in the resolved stack.
