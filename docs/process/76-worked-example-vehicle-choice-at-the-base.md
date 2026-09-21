# 76. Worked example: choosing a vehicle at the base: the 2 x 2 grid, the stock rules, and what losing looks like

**Question:** document 73 found the stock counts and left "what the original does at its base to choose a vehicle" open, with the port using a cycling `V` key as a placeholder. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: two structs, not one

Chasing writers of `+0xbc` showed two structs that look alike. The **camera / view struct** (`0x48b270`, built by `FUN_00416cb0`) has a state handler at `+0xc0` and a fade value at `+0xbc` (16.16, 0 to 1). The **player structs**
(`0x48c880`, stride `0xd0`) hold the four stock bytes at `+0xb8..+0xbb`; the camera points at its player through `+0x68` (`_DAT_0048b528 = &DAT_0048c880`). The mine reserve of document 73 (`byte +0xbc` of the *player* struct)
is a different byte from the camera's fade value: document 75 corrects the earlier confusion.

## Step 2: the camera's state machine

The handlers, disassembled (`DisasmForce.java`) or decompiled:

| handler | what it does |
| --- | --- |
| `0x4183e0` | fade in: `+0xbc += dt * 0x...`, at 1.0 the state becomes `0x408d60` (playing) |
| `0x418390` | fade out; at 0 or below it calls `FUN_00418290` (enter the vehicle choice) |
| `FUN_00418290` | **enter the choice**: `+0xcc` (the cursor) = the first type 0-3 whose stock byte is not 0 (else 0); state `+0xc0 = FUN_00417ad0`; fade value 0; adds a panel element (slot 4 kind 3 = the choice display) and restores slot 2; `DAT_0048c734++` (the count of players choosing, which the announcer compares with the number of players for its "Bunker" line) |
| `FUN_00417ad0` | **the choice loop** (below) |
| `FUN_0040b700` | **create the vehicle**: copy the type's state template, `stock[type]--` unless 0 or 0xff (document 73), link the object to the player and the base pad (`pad + 0x3a = type`) |
| `FUN_00418440` | **lost** (all four stocks 0 when a vehicle is asked for): state `FUN_004184d0`, a 30-tick pause (`+0xc8 = clock + 0x1e`), then a fade (`FUN_00418510`) and state `0x418830` (the end-of-match screen, not read) |

## Step 3: the choice loop `FUN_00417ad0`

It reads the player's input word (bits `0x40000000` / `0x80000000` horizontal, `0x10000000` / `0x20000000` vertical, `0x8000000` confirm, `0x4000000` / `0x2000000` other buttons) and the table at **`0x4491c0`**, one `0x28`-byte entry per type:
eight dwords of 16.16 rectangle corners (the icon's and the frame's places on screen), a pointer (`+0x20`: the entry's drawing), and four bytes **`+0x24..+0x27` = the type reached by left, right, up, down**:

| type | left | right | up | down |
| --- | --- | --- | --- | --- |
| Tank 0 | 0 | 1 | 3 | 0 |
| Jeep 1 | 0 | 1 | 2 | 1 |
| MSV 2 | 3 | 2 | 2 | 1 |
| Heli 3 | 3 | 2 | 3 | 0 |

That is a **2 x 2 grid: Heli and MSV on the top row, Tank and Jeep below**. A move takes the neighbour; **if that type's stock is 0 the code tries the neighbour's other-axis neighbours** (up then down for a horizontal move, left then right for a vertical
one, taking the second only if the first is the target itself) and, if that type has none either, **the cursor stays**. Each change plays sound `0x44b640`. The confirm button, once the fade has reached 1.0, calls `FUN_0040b510` (which ends in `FUN_0040b700`) with the cursor's type, and sets
the view to follow the new vehicle. The other two buttons switch to state `0x4180d0` (untraced).

## Step 4: what the screen shows

Kind 3 of the panel elements (`FUN_00411c90`) and template slot 2 (document 66's `FUN_004116a0`) draw the choice: **the four mini icons** (cels 2163, 2161, 2164, 2162, `0x873 / 0x871 / 0x874 / 0x872` in type order, which also settles the earlier doubt about which silhouette is which), each with the count of vehicles left
in the red digit cels (`0x862 + n` = 2146 + n; a hundreds cel over 99), on the panel's blank frame (cel 1940).

## Applied in the port

`MatchController.switch_player_vehicle` (the `V` key, standing on the home tile) now docks (returns the vehicle to stock) and opens the grid; `select_move` (left, right, up, down = the arrows) and `confirm_selection` (Space or Enter) reproduce the cursor rules and the stock spending;
`game/vehicle_select_view.gd` draws the traced icons, digits and arrangement. Checked by `tools/tests/select_check.gd` (start cursor Tank; right to Jeep, up to MSV, left to Heli, down to Tank; with the MSV out of stock the moves reroute as the code does; the confirm spends one) and a screenshot.
The level playthrough and the autoplay now pick the Jeep through the grid and still win.

**Port-only:** the docking trigger (`V` on the home tile, the original docks when the vehicle drives onto the pad), the keys, no cancel, the frame, the 6x scale, the position, the digit shown for "unlimited" (255; the original's display is untraced), and the respawn after a death, which still takes stock without a choice.
**Not done:** the fade in and out, the sound `0x44b640`, the lost sequence's end screen, the confirm's second and third buttons, the choice on the panel's frame at the table's rectangles.

**Correction (document 78):** the four neighbour bytes are *up, down, left, right* and the screen is Heli, Tank on top, MSV, Jeep below; the port's grid was redrawn as the original's hangar picture there.

**Next:** [the next-steps doc](NEXT_STEPS.md).
