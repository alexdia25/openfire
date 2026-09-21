# 66. Worked example: the original's HUD panel (first pass)

**Question:** the port has no interface. Before building one, find out what the original draws and where it is driven from. This is a *first
pass*: the panel skeleton and its weapon-count element are traced; fuel/health gauges, the radar and the announcer are only located.
Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: how the panel is built (`FUN_00412ad0`)

Document 65 found two interface writers: `_DAT_0048c77c |= 0x100/0x200` (flag bits) and `FUN_00413100(flag, 0x4404b0, ...)` (a radar blip). Working outward from the
first one, `FUN_00412cb0(panel, bits)` was the writer of a "dirty" mask, and the function that consumes such masks is `FUN_00412be0`. Decompiling
`FUN_00412ad0` (the builder, `DecompileMany.java 412ad0 412be0 412cb0`):

```c
puVar2 = &DAT_00446828;            /* the template */
puVar3 = &DAT_0048c320;            /* the live panel, player 0 */
for (iVar1 = 0x42; iVar1 != 0; iVar1--) *puVar3++ = *puVar2++;   /* copy 0x42 dwords = 0x108 bytes */
...
if (param_1 == 1) {                /* one player */
  if (DAT_0048c7dc == 0) { _DAT_0048c328 = 0x570000; DAT_0048c32c = 0xa80000; }   /* x = 87, y = 168 */
  else                   { _DAT_0048c328 = 0x740000; DAT_0048c32c = 0xb90000; }   /* x = 116, y = 185 */
} else {                           /* two players: a second copy at 0x48c428 */
  player 0: x = 14 (0xe0000), player 1: x = 165 (0xa50000), both at y = 162 (0xa20000)     /* DAT_0048c7dc == 0 */
  or x = 47 (0x2f0000) and 198 (0xc60000) at y = 182 (0xb60000)                              /* the other layout */
}
```

So the panel is a **`0x108`-byte struct per player** (`0x48c320`, stride `0x108`), built by copying one template, with position in 16.16 at `+8` (x) and `+0xc` (y).
`DAT_0048c7dc` chooses between two layouts (the same panel for two screen sizes: 87 + 148 = 235 fits a 320-wide screen centred; the other is offset by (29, 17)).
The one-player position is centred because cel 1940 (below) is **148 x 59**.

## Step 2: the template at `0x446828` and the dirty-bit loop

`DumpDwords.java 0x446828 66` prints the template; only its first 30 dwords are non-zero:

| dwords | meaning |
| --- | --- |
| `+0`, `+4` = `0xf`, `0xf` | dirty masks: "everything dirty" (bits 1, 2, 4, 8) at creation |
| `+8`, `+0xc`, `+0x10` = `0x1a0000`, `0xac0000`, `0xe30000` | x, y, and a third value (overwritten by the builder from the height of a cel) |
| six-dword **element slots** from `+0x14`: `{callback, chain, param0, param1, param2, ...}` | slot n handles dirty bit `1 << n` |

Slots (from the dump):

| bit | callback | chain (bits it dirties in turn) | parameters |
| --- | --- | --- | --- |
| 1 | `0x411650` | `0xe` (2, 4, 8) | none |
| 2 | `0x4115f0` | 0 | cel `0x794` = **1940**, offset (-3, -2) |
| 4 | `0x4116a0` | 0 | element kind 0 (index into the vehicle icons) |
| 8 | `0x4115f0` | 0 | cel `0x795` = 1941, offset (13, 3) |

`FUN_00412be0` (decompiled above): for each player it takes the dirty mask, walks bits low to high, calls `callback(panel, slot, bit)` for each set bit whose callback
is not null, and ORs the slot's *chain* into the mask, so **redrawing bit 1 redraws 2, 4 and 8 as well**. A panel is therefore "draw everything again when anything
changes"; `FUN_00412cb0` is what game code calls to say "this part changed".

## Step 3: what each callback draws (`DisasmForce.java 4115f0 4116a0`)

The two small callbacks are not decompiled by Ghidra (data-only entry points, cheat sheet). Their disassembly, translated:

- **`0x4115f0`** (bits 2 and 8): `if (global 0x448d20 != 0 && slot.cel != 0x795) { s = FUN_00413c90(celtable + cel * 0x44); s.x = panel.x + slot.dx; s.y = panel.y + slot.dy;
  s.field_0x34 = (s.field_0x34 == 3) ? 15 : 14; }`. `FUN_00413c90` is the sprite-submission call from document 5 (it queues a copy of the cel's record and returns the copy).
  So it **draws one cel at an offset from the panel, and skips the cel `0x795`**, which is an empty 32 x 32 tint cel: slot 8 is an intentionally blank placeholder. Slot 2 draws cel
  **1940, the panel frame** (148 x 59; the registry called it `vehicle.weapon_rifle.01`, a mislabel: it is the metallic frame with the feather, now noted here, not yet re-registered).
- **`0x411650`** (bit 1): draws the cel at record offset `0x203d8` of the cel table (index about 1927; it is not a whole multiple of `0x44`, so the exact cel is **untraced**) at
  (panel x + 9, panel y + 2) with `flags |= 0x20`: another part of the frame.
- **`0x4116a0`** (bit 4, decompiled): the **weapon-count panel**. It builds two small tables of cel numbers on the stack: vehicle icons `local_18 = {0x873, 0x871, 0x874, 0x872}` =
  cels **2163, 2161, 2164, 2162** for the type index 0..3, and, per type, the two weapon icons (`0x870 / 0x86c`, `0x86d`, `0x870 / 0x86e`, `0x86f`, cels 2160, 2156-2159) and
  a table of constants (`0x96`, `0x10`, `100`, `100`, `0x32`) that are used as counts for some slots (their meaning is **untraced**). It draws the vehicle icon at panel + (6, 1), then a **two-digit count of the first weapon**
  (byte `0x48c880 + player * 0xd0 + 0xb8 + type`), a second icon and count below it, and for some types a third at the right. Digits are cels `0x862 + n` = **2146 + n** (a 16 x 16
  red digit set), drawn by `FUN_00411b10`, one digit at a time, with a special narrower advance after a "1" (`- 2`), and a hundreds cel (`0x23a4c`) when the count reaches 100.

A contact sheet of these cels (rendered from the registry) shows what they look like: 2146-2155 red digits 0-9; then, **by appearance only** (not traced), 2156 a grenade-like icon, 2157 a blue
missile, 2158 a round mine-like disc, 2159 a red-and-yellow rocket, 2160 a small bullet; 2161-2164 four small vehicle silhouettes (Jeep-like, Heli, Tank, MSV-like: consistent with the
icon table indexed by vehicle type, whose order Tank, Jeep, MSV, Heli would want 2163, 2161, 2164, 2162, so the silhouettes' identities are still to be confirmed against the type index).

**Correction (document 71):** `0x203d8` is cel 1942 (the panel interior); the offsets are `cel * 0x44` with no shift.

## What this tells the port

- **There is no fuel or health gauge in this panel.** Fuel has a gauge at record `+0x22c` (document 54: "a gauge is redrawn from it"), so it is drawn by another object; the health display is
  not yet located. The per-player panel is: frame, the vehicle's mini icon, and its weapon counts.
- Ammo is deliberately not modelled yet (user's decision), so the weapon counts have nothing to show.
- The interface reacts to game events through the dirty bits and to `_DAT_0048c77c` (flag exists = `0x100`, flag carried by the enemy = `0x200`): the **announcer** `FUN_0040f3c0`
  turns bits of that word into voice lines from a table at `0x4463b8`.
- The **radar** is a bitmap repainted by `FUN_00412dc0` (called around tiles when they change, see the end of `FUN_00432710`) with markers written by `FUN_00413100`.

## Not done (traced later)

The cel at `0x203d8`; the fuel gauge and the health readout; the radar bitmap layout and blips (incl. the flag's blinking blip, descriptors `0x4404b0` / `0x4404c0`); the Jeep's direction
arrow; the announcer table `0x4463b8` and the bits driving it; what `DAT_00448d20` is (a "display enabled" global). Until then the port draws a **placeholder** panel
([document 67](67-worked-example-autoplay-placeholder-hud-and-ruin-grab.md)).

**Next:** [document 67](67-worked-example-autoplay-placeholder-hud-and-ruin-grab.md).
