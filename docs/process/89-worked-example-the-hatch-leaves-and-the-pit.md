# 89. Worked example: yes, the hatch opens: two leaves slide apart, and the pad is a pit model with a swoop-in camera

**Question:** the user, after document 81's sink, said "I don't see hatch doors opening or anything, I suspect we will need that", and later "I do think the hatch door opens, as we can see in footage." Document 81 left a lead: `FUN_0042ee50` calls
`FUN_004161e0` / `FUN_00416300`. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

**A correction to this document's own first version.** The first version of this document (same day) concluded "no door animation exists; the pad just becomes a hole". That was wrong. It rested on one thing: the only writers of the tile's art id. It never read the lift
object's *drawing* code, and it had not looked at the footage. The user was right. What follows is the corrected trace; Steps 1-2 are still true, Step 3 and 4 are the part that was missing.

## Step 1: the footage (reference video, undock at the start of level 1)

Frames from the user's recording (`Silent Software - Return Fire - 1996 [63fXImW5szI].mkv`, sampled locally, never committed) right after the hangar screen's fade-out show, in order: the game view opens on a **tiny, distant pad and the camera swoops in** (the pad grows about
four times while the panel's gauges fill); the vehicle sits inside the pad on a stepped grey platform in a brown pit, its **lid open**, hazard-stripe border and rim around it; it rises and drives off; the pad is left showing the **closed lid**: two grey plates with a
centre seam and a clasp (the art of cel 90/91). The video has four hangar screens (game start, level 2 start, and two respawns after a death, each with the skull before it) and **no docking**, so the lowering itself was not seen in this footage.

## Step 2: the "lead" is a camera rig (this is the swoop-in)

`FUN_0042ee50` (decompiled, `DecompileMany.java 0x42ee50 0x42ef00`) is the first handler of the undock/lift object (class table `0x44db40`, slot `+0x1c`; the dock class `0x44db90` has `0x42efc0` there):

```c
FUN_004161e0(obj->player, 0, obj, 0xa0000 /*10.0*/, 0x400000, 0xfa0000 /*250.0*/, 0, NULL);
FUN_00416100(obj->player, &obj->pos, 0xfa0000 /*250.0*/, 0x400000);
obj->handler = &LAB_0042eea0;
```

`FUN_00416100` (decompiled) writes `x, y, z` and one more value into **the player's camera struct** (`0x48b5cc + player * 0x24c`). `FUN_004161e0` (`DisasmForce.java 0x4161e0 0x416340`) takes a slot from the table at `0x458ad0` (`0x60` bytes each), copies a template from
`0x448e90`, stores the target object (`+0x14`) and registers itself with `FUN_00429670` in the camera struct (`0x48b618 + player * 0x24c`) with a priority-comparison callback `0x4160a0`; its handler `FUN_00416300` copies the target's position into the camera struct's
`+0x12c / +0x130 / +0x128` and `+0x134`, `+0x144` every tick. **So this pair is a camera rig ("follow this object from height 250"), and it is what produces the swoop-in seen in Step 1** (the numbers 10.0, 24.0 / 64.0, 250.0 are its parameters; how they map to the visible zoom is
**untraced**). It is also why document 65 found the same pair near the flag: the flag capture uses a camera rig too.

## Step 3: the life cycle of the tile and the lift object

Only two instructions in the code range write `| 0x5c` into a tile's art (`FindDispOps.java 0x401000 0x437000 "0x5c"`; the other hits are `CMP`s against the path separator `\` = `0x5c` in string code): `0x42f225` in `FUN_0042f110` (the dock, document 77) and `0x42ef0a`, in the
undock object's second handler (`DisasmForce.java 0x42eea0 0x42efc0`):

```
0042eef0  CMP [EAX+0x70],0          ; the "held" flag: the confirm script releases it (document 78, routine 0x417990)
0042eefb  JZ  go                    ;   still held: return 0 and wait
0042ef01  MOV ECX,[EAX+0x1c]        ; the pad tile
0042ef07  AND EDX,0xffffffdc        ; clear bits 0-1 and 5
0042ef0a  OR  EDX,0x5c              ; art = 92 (the pit's surround)
0042ef0f  MOV [EAX+0x48],0xffe00000 ; z = -32
0042ef16  MOV [EAX+0x18],0x42ef20

0042ef20  z = [ESI+0x48]; if (z >= 0) { handler = 0; return 1; }
0042ef3d  z += dt * 19660           ; multiply chain 9, 27, 109, 437, 3933, 3932, 19660 = 0x4CCC, 0.3 units a tick
          if (z > 0) z = 0;         ; return 1
```

`FUN_0042ec50` (decompiled), the update both lift classes share, calls the handler; a handler answer of **1 adds `dt` to `+0x68`** (the object's age); when the handler is 0 it clears class-10 objects within 20 units, delivers a class-12 flag touching the pad, removes class-0x11
objects in range, then restores the tile (`(0x5b - (team == 0))`, art 90 / 91), creates the real vehicle (`FUN_0040b1c0`) and removes itself. So on **undock**: hold, release, the object rises from -32 to 0 at 0.3 a tick (about **107 ticks**), the tile is art 92 throughout, then
the pad art returns. (Document 77 said the vehicle "appears in one step"; it does not.) On **dock** (`FUN_0042f110`) the tile goes to art 92 at once and the dock object sinks.

## Step 4: what the object draws, and the leaves (the part the first version missed)

The class's drawing descriptor is `0x44dab0` (class table slot `+0x14`), and its `+4` pointer chains descriptors: `0x44dab0` (draw callback `0x42ebb0`) -> `0x44d8f8` (`0x42eae0`) -> `0x44d890` (`0x42ea10`). `DumpDwords.java` on the tables and `DisasmForce.java 0x42e9c0 0x42ec50`:

- **`0x44dab0`, the pit**: 12 corners at `0x44d940` = a 28 x 28 shaft (x, y = +-14) from z = 0 down to **-31**, and 5 parts (`0x44d9d0`): cels `0x33b`, `0x33c`, `0x33a`, `0x33a` (827, 828, 826, 826: four wall panels, drawn darker with depth: 826 lightest, 828 darkest) and `0x33f` (831, a 32 x 4 hazard strip on the front edge at y -15..-12).
- **`0x44d8f8`, the vehicle**: draw callback `0x42eae0` copies the model descriptor stored at `obj + 0x60` (from the create call) and draws it at `obj + 0x40/0x44/0x48` (+ the small offsets `+0x58/+0x59`); its own one-part table (`0x44d8d8`) is **cel `0x33d`**, flag 8 (team variant): cel 829 tan / 830 green, a 32 x 30 plate with the central seam and clasp.
- **`0x44d890`, the leaves** (callback `0x42ea10`), decoded:

```
0042ea16  ESI = draw object;  EAX = [ [ESI+0x2c] + 0x68 ]          ; the object's +0x68 ("age")
0042ea21..0042ea32  the chain 9, 27, 109, 437, 3933, 3932, 19660    ; EBX = 19660 * age  =  0.3 * age  (16.16)
0042ea35  CMP EBX,0x120000 ; JGE skip                              ; offset >= 18.0: draw no leaves
0042ea3d  EDI = [ESI+0x10]                                         ; the draw object's x
          [ESI+0x10] = EDI - EBX - 0x50000 ; parts = 0x44d830 ; FUN_0041b250   ; LEFT leaf, cel 0x336 (822/823)
          [ESI+0x10] = EDI + EBX + 0x50000 ; parts = 0x44d850 ; FUN_0041b250   ; RIGHT leaf, cel 0x338 (824/825)
          [ESI+0x10] = EDI                 ; parts = 0x44d870 ; FUN_0041b250   ; centre strip, cel 0x33f
```

The corner sets for the leaves (`0x44d7d0`) are a 16 x 31 rectangle (x -8..8, y -15..16): **each leaf is half of the lid**. Cels 822-825 (16 x 32) are exactly those halves, and looking at them shows the two interlocking clasp halves and the brown / green floor: tan left 822, green left 823, tan right 824,
green right 825. **The registry had them as `marker.rescue_cross.80-83`; fixed** (see "Applied"). So, in words: **the two leaves are drawn `0.3 * age + 5` units to each side of the centre, and are not drawn at all once `0.3 * age >= 18`, i.e. `age >= 60` ticks.**

What `age` (`+0x68`) is differs by class, and that is what decides the direction:

- **Undock** (`0x44db40`): `+0x68` starts at 0 (`0x42ebf0`, the create routine, stores 0) and counts **up** by `dt` whenever a handler answers 1: the rising handler `0x42ef20` does. So the leaves start **closed** (offset 5), **slide apart** for 60 ticks, then vanish (fully retracted) while the vehicle keeps rising for another ~47 ticks. This matches the footage.
- **Dock** (`0x44db90`): `FUN_0042f110` sets `+0x68 = 0x46 = 70`, the sink handlers (`0x42efc0`, `0x42f0a0`, all answer 0, so the update never adds to it) **count it down** to 0. So the leaves are **not drawn for the first 10 ticks** (`0.3 * age >= 18`: retracted, the pit is open), then **slide together** from 23 to 5 units over the last 60 ticks of the 70, and stay closed over the vehicle while it finishes sinking. This is **read from the code, not seen in the footage** (there is no docking in it).

## Applied in the port

**Tile 92 is not blank (a correction found while building this).** The registry called it `terrain.ground.blank.b`, "fully transparent"; extracting its pixels shows **168 opaque pixels: a yellow-and-black hazard border down the left and right edges and along the bottom, with a transparent centre** (the top edge is the lift object's own strip, cel 831). That is the pit's surround, and it is why the footage shows a hazard border around the open pit. Renamed `structure.hangar_pit_surround` (registry and `AUDIT11`).
Cels 822-831 were renamed too (Step 4). The pack was rebuilt with `tools/build_pack.py`.

The port now does the pit, the lid and the rise (checked by `tools/tests/pad_hatch_check.gd` and screenshots of the real scene against the footage); every number is the traced one:

```gdscript
# game/match_controller.gd -- the pad tile and the lift object's age (FUN_0042f110 0x42f225, 0x42ef0a, FUN_0042ec50)
const PAD_HOLE_ART := 0x5c
func _set_pad_open(open: bool) -> void:
	pad_open = open
	var t := _tile_of(_pad_centre)
	level.set_art_id(t.x, t.y, PAD_HOLE_ART if open else HOME_ART_BASE + vehicle.player_index())   # 0x5c / 0x5b - (team == 0)
	pad_art_changed.emit(t)

# dock: _do_dock() sets pad_age = 70 and opens the pad; the sink branch of _update_dock() mirrors the counted-down timer
pad_age = _dock_timer

# undock: when the confirm script ends, the hold is released (0x42eef0) and the object rises (0x42ef20)
func _begin_pad_rise() -> void:
	_set_pad_open(true)
	pad_age = 0.0
	pad_rising = true
	vehicle.z = PAD_RISE_START                                    # 0xffe00000 = -32
# in _update_dock():
if pad_rising:
	vehicle.z = minf(vehicle.z + DOCK_SINK_RATE * ticks, 0.0)      # z += 19660 * dt
	pad_age += ticks                                              # FUN_0042ec50: +0x68 += dt when the handler answers 1
	if vehicle.z >= 0.0:
		pad_rising = false
		vehicle.frozen = false
		_set_pad_open(false)                                      # the destructor path restores art 90 / 91

# FUN_0042ea10's leaf offset: EBX = 19660 * age; skip when EBX >= 0x120000; leaves at EDI -/+ (EBX + 0x50000)
func pad_leaf_offset() -> float:
	if not pad_open:
		return -1.0
	var off := DOCK_SINK_RATE * pad_age
	return -1.0 if off >= PAD_LEAF_HIDE else off + PAD_LEAF_START
```

`game/hangar_pit_3d.gd` draws the pit (the four walls, the strip, the plate at the object's height, the two leaves at `+-pad_leaf_offset()`) from sprite ids; `TerrainTileRenderer` gives every tile except the pit surround an opaque underlay so the ground texture, now baked on a transparent viewport with an alpha-scissor material, has a real hole only there (`HOLE_SPRITE_ID`); `terrain_view_3d.gd` redraws the ground on `pad_art_changed`.
Measured: the leaves appear at tick 10 at offset 23 and reach 5 at tick 70 while docking; on undock they start at 5, are hidden from tick 60, and the rise takes 106 ticks.

## Not done / untraced

- **The camera swoop-in** of Step 2 (the rig's parameters `0xa0000`, `0x180000`, `0x400000`, `0xfa0000`, the `0x4452c0` table, and the zoom curve seen in the footage) is not implemented.
- **Port choices, untraced:** the pit's object space is taken as the world's axes (the undock object turns 180 degrees; the walls are fixed at the ground rather than moving with the object's height); a 2-unit ring between the walls and the tile edge shows the background; the leaf shift is in world x.
- **The dock direction** (leaves closing over the sinking vehicle) is read from code and reproduced, but there is no docking in the reference footage to compare against.
- What `[0x458e38]` (set when the pad is cleared of class-10 objects) changes; the other `FUN_004161e0` callers; the unknown fields of the chain descriptors and the table at `0x44da70`.
- Pre-existing, not from this work: the confirm script logs `Condition "p_position > length"` once (a sound-side error, present before these changes).

**Next:** [the next-steps doc](NEXT_STEPS.md).
