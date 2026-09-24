# 89. Worked example: do the hatch doors open? No: the pad becomes a hole, and the vehicle also rises out of it

**Question:** the user, after document 81's sink, said "I don't see hatch doors opening or anything, I suspect we will need that." Document 81 left the question open with a lead: `FUN_0042ee50` calls `FUN_004161e0` / `FUN_00416300`, the same
pair document 65 had flagged. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the lead is a camera rig, not a door

`FUN_0042ee50` (decompiled, `DecompileMany.java 0x42ee50 0x42ef00`) is the first handler of the undock/lift object (class table `0x44db40`, `+0x1c` slot = `0x42ee50`; the dock class `0x44db90` has `0x42efc0` there instead):

```c
FUN_004161e0(obj->player, 0, obj, 0xa0000 /*10.0*/, 0x400000, 0xfa0000 /*250.0*/, 0, NULL);
FUN_00416100(obj->player, &obj->pos, 0xfa0000 /*250.0*/, 0x400000);
obj->handler = &LAB_0042eea0;
```

`FUN_00416100` (decompiled) writes `x, y, z` and one more value into **the player's view struct** (`0x48b5cc + player * 0x24c`, the camera struct of document 76). `FUN_004161e0` (`DisasmForce.java 0x4161e0 0x416340`) takes a slot from the table at
`0x458ad0` (`0x60` bytes each), copies a template from `0x448e90`, stores the target object (`+0x14`) and its position (`+0x20`), and registers itself with `FUN_00429670` at the camera struct (`0x48b618 + player * 0x24c`) with a comparison callback
`0x4160a0` (order by the byte at `+8`, a priority). Its handler `FUN_00416300` each tick copies the target's position into the camera struct's `+0x12c / +0x130 / +0x128` (x, y, z + offset) and `+0x134`, `+0x144`. **So the pair is a *camera rig*
("a view controller that follows an object"), not a door object and not a 2D overlay.** That also explains document 65's "object near the flag": the flag capture uses the same camera rig. What the rig's numbers (10.0, 24.0 or 64.0, 250.0) do to
the picture is **untraced**.

## Step 2: what the tile does, in full (the actual "hatch" mechanism)

Only two instructions in the whole code range write `| 0x5c` into a tile's art (`FindDispOps.java 0x401000 0x437000 "0x5c"`; the other hits are `CMP`s against the path separator `\` = `0x5c` in string code): `0x42f225` in `FUN_0042f110` (the dock, document 77) and
`0x42ef0a`, in the undock object's second handler. The whole life cycle, disassembled (`DisasmForce.java 0x42eea0 0x42efc0`):

```
0042eea0  CMP [0x458e38],0          ; was anything cleared off the pad?  (FUN_0042ec50 sets it to 1 when it destroys a class-10 object)
0042eeaa  JNZ skip
0042eeaf  MOV [ECX+0x18],0x42eef0   ; next handler
0042eec5..0042eee0  CALL FUN_004161e0(player, 0, obj, 0xa0000, 0x180000, table[0x4452c0][min(obj+0x6c,3)], 0, NULL)   ; a second camera rig

0042eef0  CMP [EAX+0x70],0          ; the "held" flag: the confirm script releases it (document 78, routine 0x417990)
0042eefb  JZ  go
          return 0                  ;   still held: wait
0042ef01  MOV ECX,[EAX+0x1c]        ; the pad tile
0042ef04  MOV EDX,[ECX]
0042ef07  AND EDX,0xffffffdc        ; clear bits 0-1 and 5
0042ef0a  OR  EDX,0x5c              ; art = 92
0042ef0d  MOV [ECX],EDX
0042ef0f  MOV [EAX+0x48],0xffe00000 ; z = -32
0042ef16  MOV [EAX+0x18],0x42ef20

0042ef20  z = [ESI+0x48]; if (z >= 0) { handler = 0; return 1; }
0042ef3d  z += dt * 19660           ; the multiply chain 9, 27, 109, 437, 3933, 3932, 19660: 0x4CCC, i.e. 0.3 units a tick
          if (z > 0) z = 0;         ; return 1
```

and `FUN_0042ec50` (decompiled), the update both lift classes share: while the handler is set it calls it (`iVar3 == 1` adds `dt` to `+0x68`); **when the handler is 0** it clears class-10 objects within 20 units, delivers a class-12 flag touching the
pad and removes class-0x11 objects in range, and then:

```c
*tile = ((0x5b - (team == 0)) ^ *tile) & 0x7f ^ *tile;   /* restore art 90 / 91 */
FUN_0040b1c0(player, &pos, heading, type);               /* create the real vehicle */
FUN_0042c0f0(obj);                                        /* remove the lift object */
```

Tile art **92** (the registry's `terrain.ground.blank.b`, "fully transparent tile, index-0 pixels only") is therefore the pad's *open* state: **the tile is swapped for a transparent one when the vehicle docks, stays transparent for the whole sink, the choice screen and the
confirm script, and is put back only after the new vehicle has risen out of it.** There is **no intermediate art** and **no door-leaf animation anywhere in this path**: the two-leaf look of cel 90/91 is just the art. The "hatch opens" effect is the pad *disappearing* to reveal a
hole with the vehicle inside it.

## Step 3: a mechanic document 77 got wrong: the undock is not "one step"

Document 77 (Step 4) wrote that the new vehicle "appears on the pad in one step". The handlers above say otherwise: after the confirm script releases the hold, the lift object **rises from z = -32 to 0 at the same 0.3 units a tick, `32 / 0.3 = 106.7` ticks
(about 1.8 seconds)**, drawing the chosen vehicle's model climbing out of the (transparent) pad, and only then is the real vehicle created and the tile restored. The confirm script (144 ticks, document 78) runs first and ends with the view's fade-in
(`0x4183e0`), so the rise is what the player watches once the view is back.

## Applied in the port

Nothing yet, on purpose: this document is the trace. The port's current behaviour, for comparison: no tile swap at all (the pad art stays opaque, so the docking vehicle sinks *through* an intact hatch: document 81's depth trick hides it behind the opaque ground plane), and the
undocked vehicle appears on the pad at full height the moment the script ends.

## Not done / untraced

- **What a transparent tile shows in the original.** The terrain is drawn tile by tile; index-0 pixels are skipped, so the hole shows whatever is behind (presumably black: the frame's clear colour), but the clear colour and draw order were not read.
- The camera rigs' parameters (`0xa0000`, `0x180000`, `0x400000`, `0xfa0000`, the `0x4452c0` table) and what they do to the view during the dock and the undock (Step 1).
- Whether `[0x458e38]` (set when the pad is cleared of class-10 objects) changes anything visible: it only decides whether the second camera rig is created.
- What the other `FUN_004161e0` callers (the flag capture, document 65) use it for.

**Next:** implementing it means a per-tile art override in the terrain renderer, a transparent pad tile during the dock, and the 107-tick rise on undock; see [the next-steps doc](NEXT_STEPS.md).
