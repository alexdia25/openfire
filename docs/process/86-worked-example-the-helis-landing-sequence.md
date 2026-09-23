# 86. Worked example: the Heli's landing sequence — rotor spin-down and the gear stage

**Question:** document 77's automatic Heli landing (height falls, position/heading slide to the pad)
was ported, but the two stages after touchdown -- `FUN_0040ecd0` (rotor spin-down) and `FUN_0040ede0`
(the "gear stage") -- were flagged as not reproduced. This also blocked `Servo`, whose only known
candidate trigger was "settles its angle, plays sound 0x44b808" as a step of that sequence.

## Step 1: when does the spin-down actually start?

Disassembling the tail of the descent handler (`0x40ec30`-`0x40ecc0`) found the exact hand-off:

```
0040ec4f  MOV EAX,[0x00480d2c]        ; the per-tick delta global
0040ec54  MOV ECX,dword ptr [EDX+0x48]  ; remaining fall height
0040ec57  SHL EAX,0xf
0040ec5a  SUB ECX,EAX
0040ec5c  JNS 0x0040ec67               ; still falling -> keep going
0040ec5e  MOV dword ptr [ESI+0xc],0x40ecd0   ; done falling -> switch state to the rotor spin-down
```

So the rotor spin-down only starts once the vehicle has actually touched down, not during the fall --
confirming `game/match_controller.gd`'s existing `dock_state == 1` (the fall) should hand off to a new
stage exactly when `vehicle.z` reaches 0, not sooner.

## Step 2: the rotor spin-down (`FUN_0040ecd0`)

```
0040ecd8..cea  ; the same "delta * 1638" constant-building sequence as the start-up's own ramp-up
0040ecef  ADD EAX,dword ptr [ESI+0x84]   ; EAX = -delta*1638 + rotor_speed  (a decrement)
0040ecf5  MOV dword ptr [ESI+0x84],EAX
0040ecfb  CMP EAX,0x8000                 ; 0.5 in 16.16
0040ed00  JG  0x0040eda7                 ; still above the floor -> keep decrementing
0040ed06  MOV dword ptr [ESI+0x84],0x8000  ; clamp to the floor, not zero
   ... (an angle-alignment check on state+0x80, not reproduced -- see "Port choice" below)
0040ed6d  PUSH 0x1 / PUSH obj / PUSH 0x44b808 / PUSH 0x1
0040ed7a  CALL 0x004232d0                ; plays Servo
0040ed94  MOV dword ptr [ESI+0xc],0x40ede0   ; -> the gear stage
```

`1638/65536` is exactly `HELI_SPINUP_B_RATE`, the same rate document 79 already found ramping the
rotor *up* during start-up -- the spin-down runs it in reverse, down to a floor of 0.5 (not 0), and
plays **`Servo`** the moment it gets there. Document 77's original guess for `Servo` was right.

**Port choice, not traced:** the original also checks the rotor blade's own current angle
(`state+0x80`) is within a quarter-turn of a resting position before finishing -- picking a natural-
looking stop instead of freezing mid-spin. Nothing in this port's rendering distinguishes rotor
angles as "settled" vs not, so this exact-tick alignment is skipped; the port finishes as soon as the
speed floor is reached.

## Step 3: the gear stage (`FUN_0040ede0`)

```
0040ede1..ef  ; the same "delta * 1179" sequence as the start-up's own silent-phase timer
0040ee06  ADD dword ptr [EDI+0x58],EAX   ; state+0x58 -= delta*1179  (a decrement, this time)
0040ee11  CMP dword ptr [EDI+0x58],0x0
0040ee15  JGE 0x0040ee4e                 ; still counting down -> keep going
   ... (clears a slot pointer, calls FUN_0042f110 -- releases the vehicle to dock normally)
```

`1179/65536` is exactly `HELI_SPINUP_A_RATE`, document 79's start-up silent-phase rate, run in
reverse from 1.0 down to 0 -- the same duration (~56 ticks) as the equivalent start-up phase.

## Applied in the port (verified by test)

`game/vehicle.gd` gained `process_heli_landing_rotor()` / `process_heli_landing_gear()` (reusing the
existing `HELI_SPINUP_A_RATE`/`HELI_SPINUP_B_RATE` constants and `rotor_speed_steps` field --
`rotor_speed_steps` is drawn by `game/vehicle_render_3d.gd`'s existing mode-selection logic already,
document 85, so the blade visibly narrows through the same modes on the way down with no renderer
changes needed). `game/match_controller.gd`'s `_update_dock()` gained `dock_state` values 3 (rotor
spin-down) and 4 (gear stage) between the existing fall (1) and sink (2):

```gdscript
if dock_state == 3:
    if vehicle.process_heli_landing_rotor(delta):
        dock_state = 4
    return
if dock_state == 4:
    if vehicle.process_heli_landing_gear(delta):
        _do_dock()
    return
```

`tools/tests/heli_landing_check.gd` drives a full landing and confirms the state sequence
(`1, 3, 4, 2`), that the rotor starts spinning down from full speed (4.0) and reaches the traced
floor (0.5), and that `Servo` fires before the dock's own `Raise`. `tools/tests/dock_check.gd`'s
Heli case needed its own timeout raised (400 -> 800 ticks) now that a real landing takes noticeably
longer than the old instant dock -- confirmed still passing.

## Still open

The exact-angle-alignment tick (see "Port choice" above) and the "folded rotor model" phrase from
NEXT_STEPS' original description of this gap were not found as a separate visual state during
landing -- the rotor simply narrows through the same width modes document 85 already renders, all
the way to the floor. If the original really does show a visually distinct folded shape on the
ground (mode 4, the same one the start-up uses) rather than just a narrow spinning bar, that would
need its own trigger condition traced; nothing found in `FUN_0040ecd0`/`FUN_0040ede0` sets
`heli_spinup_stage` or otherwise requests mode 4 during landing.
