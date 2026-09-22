# 81. Worked example: yes, the dock animates — the vehicle visibly sinks

**Question:** the user asked, after document 80's dock-readiness work, whether the dock is supposed to animate at all — the port just made the vehicle vanish the instant it docked. Scripts and field names are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: re-reading the sink handler properly

Document 77 already named the dock object's sink handler (`FUN_0042efc0`) and its rate ("0.3 units a tick") from a first pass, but hadn't disassembled it in full. Reading the whole thing (`DisasmForce.java 42efc0 42f080`):

```
0042efd2  MOV EAX,[ECX+0x48]            ; EAX = the dock object's own z (height)
0042efd5  CMP EAX,0xfff00000            ; -16.0 in 16.16
0042efda  JGE 0x0042f054                ; z >= -16: skip the fade-start, go straight to the ordinary sink step
0042efdc  MOV EAX,[ECX+0x5c]            ; z < -16, and this runs only once (the state handler is about to change):
0042efdf  TEST EAX,EAX
0042efe1  JZ 0x0042eff0
0042efe3  MOV EAX,[EAX+0x14]
0042efe6  MOV [EAX+0xc0],0x418390       ;   the CAMERA's state handler becomes 0x418390 -- document 77's fade-out
0042eff0  MOV [ECX+0x18],0x42f0a0       ; this object's own handler becomes 0x42f0a0 (a steady-state version) from here on
... (a multiply-by-19660 chain, i.e. 0x4CCC, exactly document 77's 0.3/tick) ...
0042f015  ADD EDX,[ECX+0x48]            ; z += -0.3
0042f018  MOV [ECX+0x48],EDX
0042f01b  SUB [ECX+0x68],dt             ; the 70-tick timer -= dt
0042f023  JNS 0042f02c ELSE [ECX+0x68]=0
0042f02c  CMP EDX,0xffe00000            ; -32.0
0042f032  JG 0x0042f04f                 ; z > -32: return, not done yet
0042f034  CMP [ECX+0x68],0
0042f038  JG 0x0042f04f                 ; z <= -32 but the timer hasn't run out either: STILL return, not done
0042f03a  MOV [ECX+0x48],0xffe00000     ; both conditions true: clamp z to exactly -32
0042f041  PUSH ECX
0042f042  CALL 0x0042c4d0               ; and destroy the dock object
```

**Two conditions, not one, and the object is a real, continuously-drawn thing the whole time.** It sinks at a constant 0x4CCC/65536 = 0.3 units a tick from the moment it's created; once it passes -16 the *view* starts fading out (document 77's fade, now
correctly tied to the sink instead of firing on its own); the object is destroyed only once it has reached -32 **and** the unrelated 70-tick timer (`state + 0x68`) has separately run out. Since -32 at 0.3/tick takes `32 / 0.3 ≈ 106.7` ticks — longer than the
70-tick timer — **the depth is what actually decides**, not the 70 ticks document 77's first pass assumed as the sole duration.

## Applied in the port

The port had `vehicle.docked = true` set the instant docking began, hiding the model immediately, with only an invisible 70-tick countdown behind it. Now the vehicle's own `z` sinks exactly as traced, stays visible while it does, and is hidden only once both
conditions are met:

```gdscript
# before: instantly invisible, nothing animates
func _do_dock() -> void:
    ...
    vehicle.docked = true      # the renderer hides anything docked
    dock_state = 2
    _dock_timer = DOCK_SINK_TICKS   # a single 70-tick wait, with nothing moving during it

# after: the traced two-condition sink (game/match_controller.gd)
const DOCK_SINK_RATE := 0x4CCC / 65536.0    # 0042f015's multiply-by-19660 chain
const DOCK_FADE_DEPTH := -16.0
const DOCK_MIN_DEPTH := -32.0

# in _update_dock(), dock_state == 2:
vehicle.z -= DOCK_SINK_RATE * ticks              # 0042f018: z += -0.3/tick
_dock_timer = maxf(_dock_timer - ticks, 0.0)     # 0042f01b/0042f023: the timer, clamped at 0
if vehicle.z <= DOCK_FADE_DEPTH:
    view_fade = maxf(view_fade - SelectorAnim.FADE_PER_TICK * ticks, 0.0)   # 0042efe6's one-time fade-out, done continuously instead
if vehicle.z <= DOCK_MIN_DEPTH and _dock_timer <= 0.0:                      # 0042f032/0042f038: BOTH conditions
    vehicle.z = DOCK_MIN_DEPTH
    vehicle.docked = true                        # only now does the renderer hide it
    dock_state = 0
    _open_selection()
```

No change was needed to the 3D renderer at all: `VehicleRender3D`/`VehicleBoxRender3D` already position a vehicle at `GROUND_CLEARANCE_PX + vehicle.z`, and the terrain is an ordinary opaque plane at `y = 0`, so a large negative `z` simply puts the model
behind the ground plane from the camera's point of view — normal depth testing does the rest. A screenshot sequence (ticks 40, 55, 70, 90, 106) shows the tank progressively disappearing into its hatch and confirms the numbers: the fade starts at tick 54
(traced: `16 / 0.3 ≈ 53.3`) and the object is gone by tick 107 (traced: `32 / 0.3 ≈ 106.7`), both reproduced exactly by `tools/tests/dock_sink_check.gd`.

## Not done

The dock object's own drawing is a stand-in (the port keeps rendering the *live* vehicle model as it sinks, rather than spawning a separate class-5 dock object carrying a copy of it, per document 77) — for a single vehicle that distinction has no visible
effect, but it would matter once two vehicles can be present at once. The camera-flag bit `FUN_0040b400` sets at the very end of its own routine (`document 80`) is still not chased.

**Flagged by the user, not yet traced: do the hatch doors visually open?** The pad art (document 80) is a two-leaf door design, but the only tile-art change found anywhere in the dock/undock path is an *instant* swap to the blank art id 92
(`(*tile & ~0x23) | 0x5c`, one instruction, no intermediate frames) — nothing traced shows a multi-step "opening" sequence. A quick look at `FUN_0042ee50` (called from the dock object's own set-up alongside the model, `record + 0x14c`/`0x150`-ish territory)
found it calls `FUN_004161e0`/`FUN_00416300` — the **same pair of functions** an untraced note elsewhere (document 65, "the object spawned by `FUN_004161e0` near the flag") already flagged as unidentified. Its parameters look like a 2D screen-space overlay
element (a template copied from a small fixed-size table, a handler, on-screen position floats), which reads more like a floating icon/callout than a physical door — but this is **not confirmed either way**, and per the trace-don't-guess rule this must be
traced properly (not assumed) before anything is built for it. Recorded in `docs/process/NEXT_STEPS.md`'s "Untraced choices".

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
