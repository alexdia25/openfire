# 69. Worked example: how the radar bitmap is painted, and the flag's radar blip

**Question:** document 68 found that the radar element shows a 32 x 32 window of a 128 x 128 bitmap. What is in the bitmap, and what are the blips document 65 met? Scripts and field names are in
the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the painter `FUN_00412dc0(tile, 1)`

Decompiled (`DecompileMany.java 412dc0 413100 4121b0`); one call sets one pixel of the bitmap (`DAT_0044965c`, one byte per tile: the pixel index is the tile's index in the level's tile array):

```c
uVar2 = (*tile & 0x3f80) >> 7;                        /* the tile's coastal id (bits 7-13) */
if (uVar2 != 0) {
   c = *(int *)(&DAT_00447064 + uVar2 * 0x38);        /* a dword of the coastal entry (entry + 0x34) */
   if (c == 0)                 pixel = 0x87;          /* the entry has no colour: land */
   else if ((*tile & 0xc000))  pixel = c >> 16;       /* a tile with pool/team bits: the high half */
   else                        pixel = (byte) c;      /* otherwise the low byte */
} else if (FUN_0042f6d0(tile) != 0)  pixel = 0x91;    /* plain terrain that is water */
  else if (*tile & 0x80000000)       pixel = 0xc9;    /* a flagged land tile (bit 31: not yet read) */
  else                               pixel = 0x87;    /* land */
```

So the radar shows **land 0x87, water 0x91, a flagged tile class 0xc9, and colours per coastal id**. Reading the dwords at `0x447064 + id * 0x38` (`DumpDwords.java 0x447064 1000`), only these ids have a colour:

| ids | low byte / high half |
| --- | --- |
| 22, 62 (the building and its first ruin) | `0xcc` / `0x67` |
| 45, 46, 54-60 | `0xd3` / `0x70` |
| 49, 50, 68 | `0xcf` / `0x6c` |

All other ids (palms, rocks, bushes, the ruin 63 ...) have 0 and show as land. The pool bits (`0xc000`) pick which half: the two teams' buildings have two colours. `FUN_00432710` (document 26's flag spawn)
calls the painter on the four neighbours of the tile it changes (the end of the function), and tile changes re-paint in the same way.

## Step 2: the blips `FUN_00413100(object, descriptor, priority)` and `FUN_004121b0`

`FUN_00413100` first drains a pool (`0x458970`), first *restoring* the bitmap under a previous blip by re-running the painter's logic over its point list, then links a new blip
record (object, descriptor, priority) into a list (`0x458980`). `FUN_004121b0` (called by the radar element when the window is clipped) walks that list and, for every blip whose object is still where it
was, plots each of the descriptor's points at `object.pos >> 21` (the tile) plus the point's offset, with `FUN_004198a0(colour, x, y)`, using byte 3 of the point for team 1's objects and byte 2 for the others.

A descriptor is `{count, pointer to count * 4 bytes (dx, dy, colour_team_0, colour_team_1)}`. The flag's two descriptors (document 65: swapped every 15 ticks):

- `0x4404b0`: **8 points** at `0x440490`: (0, 0), (0, 1), (0, -1), (0, -2) and (1, -1), (1, -2), (2, -1), (2, -2): a **4-pixel pole and a 2 x 2 pennant**, colours **`0x45`** (tan flag) and **`0x67`** (green flag);
- `0x4404c0`: **0 points**: the off state. The flag therefore **blinks on the radar**, on and off every 15 ticks (0.24 s).

## Step 3: the palette (already traced in document 20, applied here)

The radar bitmap is not a separate surface: `FUN_00424a00` (disassembled with `DumpDisasm.java 424a00 424ad0`) points the *source pixel pointer* of six ordinary cels (record `celtable + 0x20e34`, 68 bytes each, width
and height `0x80`, flags `|= 0x70`) at the bitmap (`DAT_0044965c`); the radar element's cel `0x7bf` = 1983 is one of them. It is drawn like any 8-bit cel, so the shared palette rule of document 20 applies:
**runtime palette entry `k` = shared PLUT entry `k - 10`** (PLUT at `0x282CC` of ART.CAR). The colours:

| index | RGB | use |
| --- | --- | --- |
| `0x87` | (18, 78, 131) | land |
| `0x91` | (4, 97, 152) | water |
| `0xc9` | (151, 129, 209) | flagged tile (bit 31) |
| `0x45` / `0x67` | (252, 129, 0) / (126, 255, 94) | tan / green flag blip |
| `0xcc` / `0x67` | (240, 209, 195) / (126, 255, 94) | building (ids 22, 62), team 0 / team 1 |
| `0xd3` / `0x70` | (188, 138, 95) / (61, 153, 14) | ids 45, 46, 54-60 |
| `0xcf` / `0x6c` | (225, 174, 140) / (119, 220, 48) | ids 49, 50, 68 |

So the radar is a **blue map, darker land on a lighter sea, with the team buildings in tan / green**. (Land darker than water surprised me too; the numbers are what the code and the palette give.)

## Applied in the port

`tools/extract_radar.py` -> `tools/data/radar.json` (indices, in the repo), `tools/build_pack.py` adds the RGB from the user's own ART.CAR into `packs/original_pc/hud/radar.json` (not committed), `game/radar_view.gd` draws
the 32 x 32 window with those rules and the blinking flag blip (checked by a screenshot: the island in the two blues, a green flag blip). **Not reproduced**: the grid (cel 1963), the bracket cursor (1964), the Jeep's arrow, tiles with bit 31 set,
the background outside the map (drawn black), the frame; the 4 px per tile scale and the position are the port's.

## What the port can already take

The structure is fully known: a 128 x 128 map of one class per tile (land, water, flagged tile, coastal-id colour, with a variant split by team), a 32 x 32 window centred on the player's tile with the grid cel over it, a blinking 4 + 4 pixel flag
blip, and the Jeep's arrow. 

**Next:** the remaining element kinds (2-4, 7-9: the health readout), the Jeep arrow cels, bit 31 of the tile word, then the announcer.
