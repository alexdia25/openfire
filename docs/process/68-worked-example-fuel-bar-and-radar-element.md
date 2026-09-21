# 68. Worked example: the fuel bar and the radar window (HUD elements by kind)

**Question:** document 66 found the per-player panel and its four template slots, but no fuel or health gauge and no radar. Where are they? Scripts and field names are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the vehicle adds its own elements to the panel

Document 54 said "a gauge (`record +0x22c`) is redrawn from fuel". Searching for readers of the record's fields (`FindDispOps.java 0x401000 0x440000 "0x210]"`, and `"0x214]"`,
`"0x22c]"`) found all of them in one function around `0x40ba00` (the vehicle's set-up/update, disassembled with `DumpDisasm.java 40ba60 40bc30`). Its interesting lines:

```
0040ba9d  MOV EAX,[EBX+0x210]      ; record + 0x210 = the fuel the type starts with (Tank 400)
0040baa3  SHL EAX,0x10
0040bab2  MOV [EDI+0x14],EAX       ; state + 0x14 = the fuel, as 16.16
0040bab6  MOV EAX,[EBX+0x214]      ; record + 0x214 = 5
          ... PUSH 5 (a panel slot), PUSH EAX (a *kind*), PUSH &record+0x1fc, PUSH &state+0x14 ...
0040bac3  CALL 0x00412cd0
```

`FUN_00412cd0(panel, slot, kind, a, b, c)` (decompiled) is the **element factory** for the panel of document 66: it copies the callback `(&DAT_00446930)[kind]` into slot `slot` (six dwords
from panel `+0x14 + slot * 0x18`), stores the three parameters, calls the kind's init (`(&DAT_00446958)[kind]`) if there is one, and sets the slot's dirty bit. So **each vehicle type
adds elements when it is created**; the template's four slots are only the frame. `DumpDwords.java 0x446930 20` lists the kinds:

| kind | callback | init |
| --- | --- | --- |
| 1 | `0x4115f0` (one cel at an offset: the frame pieces of document 66) | none |
| 2, 3 | `0x411bb0`, `0x411c90` | `0x411b70` for 2 |
| 4, 5 | `0x411da0`, **`0x411f80`** | `0x411d70` |
| 6 | **`0x4122d0`** | `0x412170` |
| 7, 8, 9 | `0x4127b0`, `0x412960`, `0x412a00` | `0x412790` for 7 |

The Tank's record passes kind **5** for slot 5 (fuel) and kind **6** (from `record + 0x270`) for slot 9. Other types read their own kinds; the Heli adds a further slot 8 with kind 9.

## Step 2: kind 5 is a horizontal bar (`FUN_00411f80`, init `FUN_00411d70`)

The bar's parameters are a block inside the record, starting at `record + 0x1fc`; the Tank's values from the record dump (`0x4458c8...`):

| record | value | meaning (from how the callback uses `param + 0x14...0x30`) |
| --- | --- | --- |
| `+0x210` | 400 | the value that fills the bar (`+0x14`) |
| `+0x218`, `+0x21c` | 12, 15 | top and bottom row, relative to the panel (`+0x1c`, `+0x20`) |
| `+0x220`, `+0x224` | 88, 127 | left and right column (`+0x24`, `+0x28`) |
| `+0x228` | `0x9999` = 0.6 | pixels per tick the drawn fill moves toward the real value (`+0x2c`) |
| `+0x22c` | filled in by the init: `(127 - 88 + 1) / 400 = 0.1` | pixels per fuel unit (`+0x30`) |

`FUN_00411d70` is exactly that division (`((right - left) + 1) / max`), which is how the `+0x22c` seen in the disassembly (`IMUL EAX,ECX` with the whole-number fuel in ECX) gets to be
"pixels of bar for this much fuel". Hence, for the Tank: **a 40 x 4 bar at panel + (88, 12)**. The callback then:

1. moves its drawn fill toward the target (`FUN_0042cdd0(current, target, speed * dt)`), and re-marks itself dirty while it is still moving;
2. picks a colour from the fill in pixels `f` and the bar width `w`: `f >= 3w/8` colour 6; `f >= w/4` colour 4; `f >= w/8` colour 2; below that colour 0, and below `w/16` it alternates with colour 8
   every 32 clock ticks (`DAT_00480d38 & 0x20`): the bar goes from a full colour through warning colours to a flashing one; the colours are the 16-bit values at `0x446760 + colour * 2`
   (**not decoded**);
3. draws the filled part with a one-pixel cel (`celtable + 0x238b4`) stretched to the fill's size by `FUN_0041d4a0`, and the rest with an "empty" colour (`0x446758`).

The **health** display is not among these: the vehicle's hit points are not drawn as a bar at all in what was decoded so far (open: probably the other kinds, 2-4, 7-9).

## Step 3: kind 6 is the radar window (`FUN_004122d0`)

Its parameters (`record + 0x270...`, the Tank's dump at `0x445928`): position **(19, 11)**, size **32 x 32**, and cels `0x7bf` (1983), `0x7ab` (1963) and `0x7ac` (1964). What the callback does:

- it takes the tracked object (the player's vehicle, `slot + 0xc`) and computes a window of 32 x 32 cells of a **128 x 128 bitmap**, centred on the object: `(obj.x >> 21) - width / 2`,
  `(obj.y >> 21) - height / 2` (`>> 16` turns 16.16 into units and `>> 5` divides by 32 units: **one bitmap pixel per tile**; level 1 is 128 x 128 tiles), clipped to the bitmap;
- it draws that window (`FUN_0041d350` selects a sub-rectangle of the bitmap's cel) at the panel position; when the window is clipped by the map edge it first paints the background
  (`FUN_004121b0`) so the outside of the map is not garbage;
- it lays cel **1963** over it: by its picture (below) a white grid, the radar's graticule;
- if the tracked object is a Jeep (`record[0] == 1`) and it did something within the last 64 ticks (`clock - state + 0x4c`), it draws one of **16 arrow cels** (`celtable + 0x2052c`), chosen from
  the angle `FUN_00410b70(heading, slot + 0x14)`, at the window's centre. By the Jeep-only test and the angle argument this is **very probably the Jeep's direction arrow** that document 57 saw in the Jeep's state handler (the arrow cels themselves are not yet looked at, so this is not confirmed);
- cel **1964** (four corner brackets and edge ticks) is drawn as the cursor at the `slot + 0x24` counter, and an 8-step "ping" table (`slot + 0x28`, rectangles of bytes) animates when the object's
  `+0x5c` child (the player's marker) has a state (`+0x80`) between 0 and 7.

The bitmap itself is painted by `FUN_00412dc0` (called for a tile and its four neighbours whenever a tile changes; the end of `FUN_00432710` does it around the spawned flag) and the blips by `FUN_00413100`;
those are the next things to read.

## The cels, by appearance (not traced)

A contact sheet of the cels shows: 1963 a white grid on transparent, 1964 four corner brackets with edge arrowheads, 1943 a 144 x 56 metallic panel with a dark screen at the left and bars/icons at the right
(the panel's base drawing, next to 1940's 148 x 59 frame), 1927 and 1926 stone-like pieces (the odd cel at `0x203d8` is near these; still unresolved). The registry calls 1963/1964 "tint colour" cels; they are
probably radar overlay pieces (by the code above), to be re-labelled once the arrow cels and the panel base are confirmed.

## What is implied for the port

The panel is assembled per vehicle type from element kinds, not fixed: the fuel bar and radar exist for the Tank; the other types have their own records (the Jeep's and MSV's element parameters are in their records
at the same offsets, not yet read). A faithful port needs the element kinds 2-4 and 7-9 read, the palette colours at `0x446760`, and the radar painter.

**Next:** the radar painter `FUN_00412dc0` and the blip function `FUN_00413100`; the remaining kinds; the other types' panel blocks.
