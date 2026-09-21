# 74. Worked example: how the bar colours are really drawn (the HUD's blit modes)

**Question:** document 70 read the words at `0x446760` / `0x446778` as 15-bit RGB "as a guess". Can the renderer confirm that? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: what the panel code writes into a cel record

Every drawing call of the panel (documents 66-72) copies a cel record with `FUN_00413c90` and then sets `+0x10` / `+0x14` (x, y) and **`+0x34`**, a small number: 6, 9, 10, 0xb, 0xe, 0xf. `+0x34` is the 14th dword of the 17-dword CCB, the field
the converter calls `PRE0` (`convert_car.py` names: Flags, NextPtr, SourcePtr, PLUTPtr, XPos, YPos, HDX, HDY, VDX, VDY, HDDX, HDDY, PIXC, **PRE0**, ...). The per-frame dispatcher `FUN_00418ef0` (document 32's family) switches on that field
(values 0-0x13); the HUD simply uses modes whose numbers the art never uses.

## Step 2: mode 10 is the bar

The bar's fill and empty part are drawn with cel `0x238b4` / 68 = **2141**, a 32 x 2 cel whose 64 source bytes are all 0 (`ART.CAR` at `0x1d0f0f`), its `+0xc` pointing at `0x446760 + colour * 2` (or `0x446758`, or `0x446778 + ...`). Case 10 of the dispatcher
(`DecompileMany.java 418ef0`):

```c
case 10:
   uVar1 = *(ushort *)(*(int *)(param_2 + 0xc) + 2);                       /* the WORD at PLUTPtr + 2 */
   ... set up the destination ...
   UVar6 = GetNearestPaletteIndex(DAT_00448ccc,
              ((uVar1 >> 2) & 0xf8) << 8 | ((uVar1 >> 7) & 0xf8) | (((uVar1 << 3) & 0xff)) << 16);   /* a COLORREF 0x00BBGGRR */
   FUN_00410600(dest, cel, (char)UVar6 + 10);                              /* fill the rectangle with that palette index */
```

So: **the word is 15-bit RGB, red in bits 10-14** (`(w >> 7) & 0xf8` is the COLORREF's low byte, red; `(w >> 2) & 0xf8` green; `(w << 3) & 0xf8` blue), the game asks Windows for the **nearest entry of its 256-colour palette**, adds the 10-slot offset of document 20 and fills
the rectangle with that index. The layout of the table (`{0, rgb555}` per entry, read at `+2`) is explained too: my earlier reading was right about the format, and the drawn colour is the *nearest palette colour*, not the exact word.

## Step 3: the real colours

`tools/build_pack.py` now does the same nearest-colour search over the runtime palette (slots 0-9 black, then the shared PLUT) and writes `fuel_rgb` / `ammo_rgb` into `packs/original_pc/hud/panels.json`. Fuel: full `(252, 188, 0)`, then `(252, 129, 0)`, `(253, 71, 0)`,
`(237, 0, 0)` and the flash colour `(136, 0, 0)`; empty part `(32, 32, 32)`. Ammunition: `(112, 108, 0)`, `(109, 55, 32)`, `(127, 21, 21)`, `(136, 0, 0)`. (The palette has few reds and browns, so the nearest match is coarse: an ammunition bar really is a dull olive.)
`game/hud_panel.gd` uses them. This removes the "unverified colour format" entry from the untraced list.

## The other modes seen (not needed yet)

Cases 9 and 6 draw a cel through the panel's own path (`FUN_00410600` with a per-cel byte), cases 0xb / 0xf (`FUN_00410780`) and 0xe (`FUN_00410290`) are further variants. The radar ping and the bracket cursor use some of them; not read.

**Next:** [document 75](75-worked-example-scattered-mines-and-the-mine-layer.md).
