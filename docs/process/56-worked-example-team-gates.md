# 56. Worked example: the "pick-up" is a gate

Document 55 left zone kind 3 (coastal ids 43 and 44) as "spawns a carried object". Following it shows the
object is not carried at all: it is a **team gate**.

## The object

`FUN_00432550`, run by the service code when a vehicle enters a kind-3 zone, requires the tile to still have
hit points and its variant bits (`tile word bits 14-15`) to equal the vehicle's player index. It then clears the
tile's decoration (the id, 43 or 44, is saved in the object) and spawns class 13 (`0x44e370`,
priority 50) with the vehicle attached. The class:

| Function | Role |
| --- | --- |
| `FUN_00432270` init | copies the 0x104-byte block (two chained draw descriptors and two solid bars) into the object; opening 0, target 15.0 |
| `FUN_004322f0` update | slides the bars, decides to close, ends the object |
| `FUN_004324f0` hit | a shell hitting the gate damages the *tile's* hit points (`FUN_0042e7f0`); when they run out the gate is removed |
| `FUN_00432460` destroy | puts the saved coastal id back on the tile; if the tile had lost its hit points it is destroyed (`FUN_0042e8c0`, 255) |

The update, per tick: the opening moves toward the target at 0.5 per tick (`FUN_0042cdd0`, step `dt << 15`);
the two bars sit at `-(16 + open)` and `+(16 + open)` along the gate's axis (x for id 43, y for id 44), each 17
long and 2 thick, z 0-16, layer 1, mask 255; **when fully open (15) and the attached vehicle's shape no longer
overlaps the 64 x 64 region around the gate** (`0x44cdb0`, z 0-24) the target becomes 0; while closing, if
`FUN_0042bd40` finds something in the way the gate reopens; once closed for more than 60 ticks the object is
removed. So a gate opens as an own-team vehicle enters its region (30 ticks, half a second), stays open while
the vehicle is within 32 units, and closes behind it, not on anything in the doorway. An enemy-coloured gate
(variant != player index) never wakes and stays a solid bar.

## Drawing

Each descriptor's draw hook (`FUN_0042e240`, `0x42e2b0`, `0x42e320`, `0x42e390`) rewrites, per frame, corners
9, 10, 13 and 14 along the axis to `+-(16 - floor(open))` -- the door leaf (16 wide, 3 thick, 16 tall) shrinks
into its post -- and switches the last part's cel from `0x359` (a grey light) to `0x35a` (a blue light) once
`floor(open) >= 1`. The panel cel `0x35b` has flag 8: the tile's variant adds 1 for the green team. Cels
853-860 were `prop.bar_thin`, `structure.building_wall`, `marker.rescue_cross` and `prop.panel_solid`; they are
now `structure.gate.*` (`tools/data/gates.json`, from `tools/extract_gates.py`).

## Applied in the port

`game/gate.gd` (the state machine above), `game/gate_view_3d.gd` (the two descriptors drawn with the moving
corners and the light swap), `MatchController` creating a gate when a vehicle of the tile's team is recorded in
a kind-3 zone, ticking it, blocking vehicles and shells with its bars (a shell hit damages the tile and, when
its hit points are gone, restores the tile and destroys it) and restoring the decoration on removal. Verified:
scripted (a tan tank creates the gate on a tan tile, 40 ticks later it is fully open, the tank passes through
the doorway but not 14 units off centre, the gate stays open while the tank is within the region, closes after
it leaves and the tile's id returns; a green-tile gate does not open for it) and by screenshots of RFMAP002 tile
(46,58): closed with the grey light, then open with the blue light and the leaves retracted.
`RF_DEBUG_GATE="x,y"` wakes a gate for the screenshot.

## Not done

The panels' render-mode bits (`0x100` / `0x200` select shading tables), the gate sounds (`0x44b610`,
`0x44b628`), the AI's use of gates, and what the enemy team's gates do for the enemy (their vehicles open their
own by the same rule; the placeholder AI never drives to one).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
