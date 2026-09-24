# 77. Worked example: docking and undocking at the base

**Question:** document 76 found the vehicle-choice grid but the port still reached it with a placeholder key. How does a vehicle *get* into the base and out again in the original? Scripts and field names are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the trigger, in the vehicle's per-tick handler (`FUN_0040b980`, its tail)

Document 73 found the stock increment at `0x42f1c3`; that code lives in `FUN_0042f110(vehicle)`, and `FindCallRel.java 42f110` lists its three callers: `0x40bfa6` (the common vehicle handler), `0x40e0ca` (the Jeep's own handler `FUN_0040e090`) and
`0x40ee46` (the Heli's landing). The first, disassembled (`DumpDisasm.java 40bf10 40bfc0`, and the lines before it), is the trigger. In words:

```
moving  = (speed != 0) or (heading changed);                       ; [ebp-8], from 0x40be58
if (moving) goto weapons;
tile   = the vehicle's grid cell;  art = *tile & 0x7f;
if (art != player.pad_art)   goto weapons;                         ; player struct +0x2c: 90 for player 0, 91 for player 1
dx = (x & 0x1f0000) - 0x100000;  dy = (y & 0x1f0000) - 0x100000;   ; the offset from the tile CENTRE, -16..15 units
tol = record[+0x254];
if (dx < -tol || dx > tol || dy < -tol || dy > tol)  goto weapons;
if (state.input & 0x920) {                                         ; any of the three fire buttons (bits 0x20, 0x100, 0x800)
    if (record[+0x258] != 0)  state[+0xc] = record[+0x258];        ; Jeep and Heli: their own routine (below)
    else if (type != 3)       FUN_0042f110(vehicle);               ; Tank, MSV: DOCK at once
} else  FUN_0040b400(player);                                      ; no button: the pad's glow animation (a palette rotation of the pad art)
return;                                                             ; the weapon dispatch is skipped
```

`record + 0x254` (the four records, `DumpDwords.java 0x4456b8 2980`): **Tank 4.0, Jeep 9.0, MSV 4.0, Heli 32.0** units. `record + 0x258`: Tank 0, **Jeep `0x40e090`**, MSV 0, **Heli `0x40eb00`**. The three button groups are the ones of document 60
(bits 5-7, 8-10 and 11-13 of the input word), and `0x920` is the first bit of each: **standing still on the pad centre and pressing any fire button docks**, and that press does not fire.

That trigger became `MatchController.can_dock` (the position test, called from every fire-button press regardless of vehicle type, since the tolerance table already covers all four) and `Vehicle._dock_pressed` (the "any fire button, skip the weapons" part):

```gdscript
# game/match_controller.gd -- the tile/tolerance test, independent of the button (so it can also drive the document 80 readiness indicator)
func can_dock(v: Vehicle) -> bool:
    if v != vehicle or v.moving or not v.alive or dock_state != 0 or selecting or undocking or match_finished:
        return false
    var t := _tile_of(v.position)
    if (level.get_art_id(t.x, t.y) & 0x7F) != HOME_ART_BASE + v.player_index():
        return false
    var centre := (Vector2(t) + Vector2(0.5, 0.5)) * pack.tile_size_px
    var d := v.position - centre
    var tol: float = DOCK_TOLERANCE[v.vehicle_type]   # [4.0, 9.0, 4.0, 32.0], the four record + 0x254 values
    return d.x >= -tol and d.x <= tol and d.y >= -tol and d.y <= tol

# game/vehicle.gd -- the "any of the three fire buttons, and skip the weapon dispatch this tick" half
func _dock_pressed() -> bool:
    if not dock_check.is_valid():
        return false
    var buttons := _wants_to_fire() or _wants_raised() or (vehicle_type == 2 and _wants_mine())
    if buttons and dock_check.call(self):
        dock_requested.emit()
        return true
    return false
```

## Step 2: what each type does before the dock

- **Tank, MSV:** `FUN_0042f110` at once.
- **Jeep** (`FUN_0040e090`, decompiled): `if the flag of the Jeep's own team is carried by it: sound 0x44b670 and FUN_00432600(team)` (the own flag goes home), then `FUN_0042f110`. Document 57 had found this as "the third button's own-flag return".
- **Heli:** an **automatic landing**, four routines (disassembled, `DisasmForce.java 40eb00 40ef00`):
  1. `0x40eb00` sets the drive function to `0x40eb40` and the state handler to `0x40eab0`;
  2. `0x40eb40` computes, per unit of height, the heading step to **135 degrees** (`0x180000`) and the x / y steps to the pad centre (each difference divided by `0x51e` through `FUN_00410b70`), and switches the drive function to `0x40ec30`;
  3. `0x40ec30` each tick lowers the height by `dt << 15` = **0.5 units a tick** and puts the position and heading on the line to the pad centre and heading in proportion to the height left; when the height is 0 the state handler becomes `0x40ecd0`;
  4. `0x40ecd0` spins the rotor down (`state +0x84` falls `0x666` = 0.025 a tick to 0.5), settles its angle, plays sound `0x44b808`, swaps the model to the folded one (`0x4460b8`) and hands over to `0x40ede0`, which lowers the gear value (`state +0x58`) and, at 0, calls `FUN_0042f110`.

The landing (stage 2-3 above) became `MatchController`'s `dock_state == 1` phase, sliding position and heading toward the pad by the same fraction as the falling height:

```gdscript
# game/match_controller.gd, _update_dock(), dock_state == 1 -- 0x40ec30's "per unit of height, one step toward the pad"
vehicle.z = maxf(vehicle.z - HELI_LAND_RATE * ticks, 0.0)     # HELI_LAND_RATE = 0.5, 0x40ec30's "dt << 15"
var f := vehicle.z / _land_z0
vehicle.position = _pad_centre + (_land_from - _pad_centre) * f
vehicle.heading_deg = fposmod(45.0 + wrapf(_land_heading_from - 45.0, -180.0, 180.0) * f, 360.0)   # the original's 135 degrees, minus 90 for this port's heading convention
if vehicle.z <= 0.0:
    vehicle.position = _pad_centre
    _do_dock()
```

The rotor spin-down, the folded model and the gear stage (stage 4) are not reproduced — see "Port-only or simplified" below.

## Step 3: the dock `FUN_0042f110` (decompiled) and the sinking

```c
centre = tile centre of the vehicle's cell;
if (type == 2) player.mine_reserve += state[+0x40];       /* an MSV's unused mines (player struct +0xbc) */
if (player.stock[type] != 0xff) player.stock[type]++;      /* one vehicle back */
dock = FUN_0042c290(0x44db90, player, centre.x, centre.y, 0, &{model = record[+0x148], type, heading, player});
FUN_0042c4d0(vehicle);                                     /* the vehicle object is removed */
*tile = (*tile & ~0x23) | 0x5c;   dock.handler = 0x42efc0;  dock.timer = 0x46 = 70 ticks;   sound 0x44b7d8;
```

The **dock object** (class `0x44db90`, class 5) draws the vehicle's own model (`record +0x148`, the draw descriptor of the earlier documents) and its handler `0x42efc0` **sinks it 0.3 units a tick** (`0x4ccc` per tick). Once its height is below **-16** the player's view
handler becomes `0x418390` (fade out); it goes on to -32 and, when its timer of 70 ticks has also run out, disappears. `0x418390` fades the view out and then calls `FUN_00418290`, which opens the choice grid (document 76). **Correction (document 81):** `FUN_0042efc0`
disassembled in full shows the object is destroyed only once it has BOTH reached -32 units AND the 70-tick timer has separately run out — since -32 at 0.3/tick takes about 107 ticks, the depth (not the 70-tick timer) is what actually decides, so the real sink is closer
to 1.7 seconds than the 1.2 this document first estimated; see document 81 for the corrected trace and its port code (the port's first pass here also just hid the vehicle instantly instead of animating the sink — also fixed there). The pad's art becomes `0x5c` (92) during it.

```gdscript
# game/match_controller.gd -- the return of stock (0x42f110's first two lines); the sink itself is document 81's, quoted there
func _do_dock() -> void:
    _return_stock(vehicle.vehicle_type)               # "if (stock != 0xff) stock++"
    if vehicle.vehicle_type == 2:
        mine_reserve += vehicle.ammo[1]                # an MSV's unused mines join the reserve
    _drop_carried_flags(vehicle)                       # PLACEHOLDER: the Jeep's own-flag return (below) is not modelled
    vehicle.frozen = true
    vehicle.speed = 0.0
    dock_state = 2
    _dock_timer = DOCK_SINK_TICKS
```

## Step 4: undocking

A confirm in the grid (document 76) runs `FUN_0040b510(player, type)`: it creates an object of class `0x44db40` (the same class 5) at the pad centre carrying the chosen model, heading `0x200000` (**180 degrees**; the Heli `0x180000`, 135), height -32. Its update
`FUN_0042ec50` has no per-frame handler (`+0x18 == 0`), so at once it restores the pad art (`0x5b - (team == 0)`, 90 / 91), creates the real vehicle with `FUN_0040b1c0(player, position, heading, type)` (class `0x445438`) and removes itself: **the new vehicle
appears on the pad in one step** (**correction, document 89:** not quite: the lift object first rises from z = -32 to 0 at 0.3 units a tick, about 107 ticks, out of a transparent pad tile, and only then is the real vehicle created and the pad art restored); the view runs the chosen entry's short script (`0x418040`: a list of steps, table `0x4491c0` `+0x20`), then fades in (`0x4183e0`). The creation function `FUN_0040b700` (document 76) spends the stock and gives the vehicle its full state: hit points, fuel, ammunition (document 72).
The same update also handles objects lying near the pad: class 10 objects within 20 units (`400` squared) are destroyed, a class 12 object (**a flag**) touching it is delivered (`FUN_00432600` for the pad's own team, `FUN_0040b370` = the capture of document 57 otherwise), and class 0x11 objects within range are removed with an effect.

```gdscript
# game/match_controller.gd -- the confirm's "creates the new vehicle on the pad at once" (FUN_0040b510 -> FUN_0040b1c0, document 76's stock-spend)
func confirm_selection() -> void:
    if not selecting or vehicle_stock[selection] == 0:
        return
    if select_anim != null and select_anim.fade < 1.0:      # FUN_00417ad0 only accepts a confirm once the fade has reached 1.0
        return
    _take_stock(selection)
    vehicle.set_vehicle_type(selection)   # a new vehicle object: full hit points, fuel and ammunition (document 72)
    vehicle.position = _pad_centre        # FUN_0040b1c0 creates it on the pad
    vehicle.heading_deg = 45.0 if selection == 3 else 90.0   # the original's 180 / 135 degrees, minus 90 for this port's heading convention
    vehicle.z = 0.0
    ...
    undocking = true
    select_anim.start_script(sel["scripts"][SCRIPT_NAMES[selection]])   # 0x418040's per-type script, document 78
```

## Applied in the port

- **Docking:** `Vehicle.dock_check` / `dock_requested` (skips the weapons for the tick), `MatchController.can_dock` (still, on the own pad, within 4 / 9 / 4 / 32 units of the tile centre), `_begin_dock` / `_do_dock` (stock back, an MSV's mines to `mine_reserve`, the vehicle frozen), `_update_dock`:
  the Heli's landing (0.5 a tick, position and heading to 135 degrees, the port's 45) and the sink (**corrected in document 81** to the traced two-condition depth/timer gate, ~107 ticks, with the vehicle visibly sinking rather than vanishing), then the grid opens. Undocking: `confirm_selection` puts the new vehicle on the pad centre, heading 180 degrees (Heli 135; the port's headings are the original's minus 90), full state.
- **The quick swap:** the `V` key is kept as a **port-only option** (`quick_swap_enabled`): dock without the sinking and open the grid. The original has no such thing; it is easy to switch off.
- Checked by `tools/tests/dock_check.gd`: a Tank 6 units off centre does not dock, at (2, 3) it does; the confirm places the new vehicle on the pad (Jeep, heading 90 in the port's terms) and spends a Jeep. The level playthrough still wins. (The tick counts printed there were superseded once document 81 corrected the sink duration; `tools/tests/dock_sink_check.gd` has the exact numbers now.)

**Port-only or simplified:** the sound, the pad art change and the glow, the fades, the dock object's drawing (the vehicle just disappears), the Heli's rotor / gear stages, the Jeep's own-flag return (the port has no own-team flag), the flag delivery and object clearing of the lift update,
and the view scripts. The respawn after a death still takes stock without a choice.

**Next:** [the next-steps doc](NEXT_STEPS.md).
