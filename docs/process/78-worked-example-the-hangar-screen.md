# 78. Worked example: the docked vehicle-choice screen (the hangar), its backdrop, its lift and the confirm script

**Question:** document 76 traced the choice logic but the port drew its own grid. What does the original actually show while a vehicle is docked, and how does confirming animate? Scripts and field names are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the draw function `FUN_00417d60` and its art

`FUN_00417d60(camera, team)` (decompiled, `DecompileMany.java 417d60 417500`) queues cels with `FUN_00413c90`. Every `DAT_0044964c + N` in it is a cel number times `0x44` (document 76's lesson: divide by 68, no shift). Translating:

| offset | cel | what (by its picture) |
| --- | --- | --- |
| `0x2272c` | **2075** (132 x 123) | the hangar: a blue lift shaft in the middle and four bays around it |
| `0x22c38 + (type * 2 + team) * 0x44` | **2094-2101** (64 x 32) | the eight vehicle pictures (tan, green) of Tank, Jeep, MSV, Heli |
| `0x227f8` | 2078 (32 x 27) | the dark opening of a bay (drawn under the cursor's picture) |
| `0x227b4` | 2077 (36 x 18) | a spotlight cone, drawn with a tint blend (`+0x30 = 0x1f801f80`) |
| `0x22b6c + ((clock >> 4) % 3) * 0x44` | 2091-2093 (35 x 2) | the pointer: two red ticks, three blinking frames |
| `0x22770`, `0x2283c` | 2076, 2079 (32 x 6) | the lift's cap, and its body stretched down to the bottom of the screen (`FUN_00436fb0`, a quad) |
| `0x22990`, `0x229d4`, `0x22a5c`, `0x22880` | 2084 / 2085-2086 / 2087-2089 / 2080-2083 | the backdrop: sky-and-ground strips, clouds, dirt |
| `0x22b28` | 2090 (144 x 144) | a metal frame: the **map window** (below) |

The hangar is centred (`x = (screen - 132) / 2`) and its y comes from `FUN_00417500`: **22**. The four bays' cel-relative positions are the table `0x4491c0` (document 76), whose eight dwords per type are now decoded: picture, pointer, spotlight and box positions
(Tank (85, 54), (87, 73), (85, 52), (87, 45); Jeep (85, 92) ...; MSV (13, 92) ...; Heli (13, 54) ...). The pictures are drawn at **half size** (`HDX` and `VDY` shifted right by one, 32 x 16), at position + (2, 3). A type with **no stock leaves its bay empty**.

## Step 2: a correction to document 76: the layout and the neighbour bytes

Putting the picture positions next to the neighbour bytes fixes the order I guessed: the bytes are **up, down, left, right** (Tank `[0, 1, 3, 0]` = up 0 (itself), down 1 (Jeep), left 3 (Heli), right 0), and the screen is

```
 Heli (13, 54)   Tank (85, 54)
 MSV  (13, 92)   Jeep (85, 92)
```

not the top row "Heli, MSV" of document 76. The input bits are `0x40000000` up, `0x80000000` down (the first block of the loop, which falls back to left / right), `0x10000000` left, `0x20000000` right (the second block, falling back to up / down).
`select_move`'s constants and the port's keys are now in that order.

## Step 3: the backdrop `FUN_00417500`, and why it looks the same every time

It runs while the flag `state + 0xe4` is above 0 (four frames, into the persistent frame buffers). Its random numbers come from the C runtime: `FUN_00437330(seed)` is `srand`, `FUN_0041d3d0(n)` is `((rand() & 0x7fff) * 2 * n) >> 16`, and MSVC's `rand`
is `state = state * 214013 + 2531011; return (state >> 16) & 0x7fff` (`game/crt_rand.gd`). The drawing order (320 x 240 screen, `x` in units):

1. `srand(0x1abfac + team)`; the middle strip cel 2084 (with hazard stripes) at (128, 0) and (128, 16); then to the left the strips at x = 64, 0, -64 and to the right at 192, 256, each pair (y 0 and 16) picking cel `2085 + rand(2)` twice;
2. clouds: x = 0, 64 ... 256 at y = 4, cel `2087 + rand(3)`;
3. dirt: for each column x = 0, 32 ... 288 **reseed with `0x1abfac + team + (x << 16)`**, then rows from y = 42 in steps of 32: cel `2080 + rand(4)`.

Everything is deterministic, so the port reproduces the same picture (`SelectorScreen._build_backdrop`). Anything outside the 320 x 240 rectangle (the strips at x = -64 and 320) is clipped by the screen edge.

## Step 4: the lift and the confirm script

State `+0xd0` is the lift's height (`d0`, 110 when the screen opens), `+0xd4` / `+0xd8` the chosen picture's sideways and vertical offsets (`d4`, `d8`), `+0xbc` the fade (0 to 1 at 0.07 a tick, so about 14 ticks). The cap is at `(hangar x + 51.5, hangar y + d0)`,
the body stretched from there to the bottom of the screen. A confirm (allowed only once the fade has reached 1.0) creates the vehicle at once (held: `vehicle + 0x70 = 1`) and switches to state `0x418040`, which walks the chosen type's **script**, a list of five-dword steps
`{routine, p1, p2, p3, continue}` (`entry + 0x20` of the table: Tank `0x449108`, Jeep `0x448fc0`, MSV `0x448f30`, Heli `0x449050`), calling each routine every tick until it answers "done". The routines (disassembled):

| routine | what it does |
| --- | --- |
| `0x417810` | plays a sound (`p1` picks the object from `0x449260`, `p2` a pitch factor, `p3` a length) and is done at once |
| `0x417a90` | the lift alone: `d0 -= p1 * dt` until it is at most `p2` |
| `0x417a40` | the picture slides: `d4 += p1 * dt` until it passes `p2` |
| `0x4179f0` | lift and picture rise together: `d0` and `d8` fall by `p1 * dt` until `d0 <= p2` |
| `0x417990` | both keep rising while the fade falls by `p2 * dt`; at 0 the vehicle is released (`vehicle + 0x70 = 0`) |
| `0x417900` | clears the panel's elements (slots 5-9 to kind 0, slot 4 to kind 2) |

`DumpDwords.java` on the four lists (with a small decoder) gives the scripts: **Tank** and **Heli** (the top-row types): sound, the *empty lift rises* to 72 (0.5 a tick), sound, **the picture slides onto it** (Tank left 35, Heli right 36), sound, clear the panel, rise together to 60, rise and fade.
**Jeep** and **MSV** (the lower row, level with the lift's start at 110): sound, slide (Jeep left 35, MSV right 36), sound, clear the panel, rise together to 80, rise and fade. About **144 ticks** for a Jeep (2.3 seconds); the fade-out is followed by the game view's own fade-in (`0x4183e0`, again 0.07 a tick).
The sound indices `0` / `1` are the two entries of `0x449260` (`0x44b7f0` and `0x44b7d8`); the audio pass will name them.

## Step 5: the panel under it, and the map window

The panel at the bottom (`(87, 168)` on this 320 x 240 layout, frame cel 1940, interior 1942) is the HUD panel's template slot 2, `FUN_004116a0` (document 66), for the cursor's type: the vehicle's mini icon at (21, 6), the count of vehicles left in the red digit cels at
(44, 8), the first weapon's icon at (21, 26) and its capacity (150, 16, 100, 100) beside it, and a second icon and count (Heli's 50 bombs; the MSV's mine reserve, only in two-player games). Digits are 8 units apart (6 after a "1"), a hundred is a "1" cel first. It disappears at the script's *clear panel* step.
Cel 1942 (the panel interior) is a picture of the **controls** (a game pad with the buttons labelled by icons): the same 124 x 50 cel the panel always draws.

The other buttons (`0x4000000`, `0x2000000` of the input word) go to state `0x4180d0`, which draws cel 2090 (the 144 x 144 metal frame) centred and, inside it at +8, **cel 1981 (the radar bitmap cel: the whole 128 x 128 level map)** in the player's colour: **the map window**; a button press returns to the choice loop.

## Applied in the port

`tools/extract_selector.py` -> `tools/data/selector.json` (positions, scripts, cel numbers), `build_pack.py` adds the sprite ids (`hud/selector.json`), `game/selector_anim.gd` runs the script, `game/crt_rand.gd`,
`game/selector_screen.gd` draws all of the above (backdrop, hangar, bays, cursor, lift, panel, map window, fade) on a 640 x 480 (2x) centred area, `MatchController` runs the fade-in, confirms only at fade 1.0, runs the script (`undocking`) and then the view's fade-in.
Checked by screenshots (the whole screen at the start, three moments of a Jeep's confirm, the map window), `select_check.gd`, `dock_check.gd` (the script takes 144 ticks), the level playthrough and the debug autoplay (both now wait for the script).

**Port-only or approximated:** the 2x scale and centring, `M` for the map (the original's other buttons), the spotlight's tint (an additive layer), the frame's window position, the display of "unlimited" stock (255 shown as 99), and the sounds (skipped: the sound pass). **Not done:** the panel's own slide-in and
the `d0` platform not being shown under the confirmed vehicle beyond the picture, and the counts panel's second icon for the MSV (two players only).

**Next:** the docking animations ([document 79](79-worked-example-docking-animations.md)).
