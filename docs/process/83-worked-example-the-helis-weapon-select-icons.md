# 83. Worked example: the Heli's weapon-select icons (kind 9)

**Question:** watching real Windows 95 gameplay footage, the user noticed the original lights up the currently-selected
weapon and dims the other one on the panel -- something the port's HUD panel (documents 66-72) never drew. Document 70
had already flagged the gap without chasing it: "kind 9 (Heli slot 8)" was in its "Not done" list, Heli-only, with no
idea what it actually draws.

## Step 1: the callback, disassembled

Document 68's element-kind table gives kind 9's callback: `0x412a00`. Ghidra never disassembled it (reached only
through the data table, like several callbacks in this project), so `DisasmForce.java 412a00 412ad0`:

```asm
00412a00  CMP dword ptr [0x00448d20],0x0     ; the "display enabled" global (document 66)
00412a0c  JZ 00412ac6                        ; -> return if off
00412a12  MOV EAX,[EBP+0xc]                  ; EAX = slot (panel, slot) callback convention
00412a15  MOV EAX,[EAX+0x8]                  ; EAX = the pointer stored in the slot's param 'a'
00412a18  TEST EAX,EAX
00412a1a  JZ 00412a35                        ; no object -> both icons dim
00412a1c  TEST byte ptr [EAX+3],0x10         ; test bit 0x10 of the byte at (that pointer)+3
00412a20  JZ 00412a29
00412a22  MOV EAX,0x7b9                      ; bit set:   icon A = cel 1977 (bomb, lit)
00412a27  JMP 00412a3a
00412a29  MOV EAX,0x7ba                      ; bit clear: icon A = cel 1978 (bomb, dim)
00412a2e  MOV ESI,0x7bb                      ;            icon B = cel 1979 (gun, lit)
00412a33  JMP 00412a3f
00412a35  MOV EAX,0x7ba                      ; null:      icon A = cel 1978 (bomb, dim)
00412a3a  MOV ESI,0x7bc                      ; (bit-set fallthrough, and the null case): icon B = cel 1980 (gun, dim)
... spawns a draw object for cel EAX at panel + (91, 20), then one for cel ESI at panel + (36, 36) ...
```

**Icon A** (panel-relative (91, 20)) is cel 1977 when the tested bit is set, else 1978. **Icon B** ((36, 36)) is 1979
when the bit is clear, else 1980 (both 1980 also on the null path). Four cels, drawn in a mutually-exclusive lit/dim
pair per icon.

## Step 2: whose bit, and where the pointer comes from

The kind-9 slot is only added for the Heli (`CMP dword ptr [EBX],0x3; JNZ ...` guards the whole block in the panel
setup function, `DumpDisasm.java 40ba00 40bb00`, call site `0x40bae3`). Reading the pushed arguments (cdecl,
right-to-left) of that one call: `FUN_00412cd0(panel, slot=8, kind=9, a=&ESI[0xc], b=0, c=0)` -- so the callback's
`[slot+8]` (read above as `EAX`) is the raw address `ESI+0xc`, and the tested byte at `(EAX)+3` is **`ESI+0xf`**: the
fourth byte of the dword at `ESI+0xc`, i.e. bit `0x10000000` of that dword. `ESI` here is the live vehicle object
being created (the same object `FUN_00412cd0`'s kind-6 radar call passes directly as its own `a` argument a few
lines earlier in the same function).

That is **exactly** the weapon-select flag document 63 already found and named, just never connected to the panel:

```c
// FUN_0040e600 (the Heli's fire handler, document 63)
slot = (obj[+0xc] & 0x10000000) >> 28;   // which weapon: 0 gun, 1 bomb
```
```c
// FUN_0040e7a0 (the third button)
obj[+0xc] ^= 0x8000000;   // NOTE: this toggles a *different* bit (0x8000000, the mount alternator) --
                          // the weapon toggle itself was traced only as "toggles bit 28" in document 63's prose;
                          // rereading FUN_0040e7a0 confirms it (obj[+0xc] ^= 0x10000000, the same bit kind 9 reads)
```

So: bit set = bomb selected (slot 1), bit clear = gun selected (slot 0) -- one flag, read by the fire handler to
choose ammo/projectile type, toggled by the third button, and now also read by the panel to choose which icon is lit.

## Step 3: confirming the cels against the real art

Cels 1977-1980 were misclassified by the original bulk pass (`ui.icon.exit_sign.01`, `.boost.01`, `.armor.01`,
`.pause.01` -- plausible-looking guesses for generic olive UI icons, never checked against what triggers them).
Cropped and viewed directly: **1977 and 1978 are the same rocket-like silhouette**, bright red/yellow vs a flat dark
grey -- the bomb icon, lit and dim. **1979 and 1980 are the same twin-vertical-bar silhouette**, bright vs dark grey --
the twin-mounted gun (document 63's guns fire from alternating left/right mounts, so a twin-bar icon fits). The
registry is hand-corrected (`packs/registry/asset_ids.json`, `tools/registry/classify_batch2.py`'s `put()` record) to
`ui.hud.heli_weapon.{bomb,gun}_{lit,dim}`.

## Applied in the port

`tools/data/hud_panels.json` gained a `weapon_select` block (positions and the four cel ids); `tools/build_pack.py`
resolves the cels to sprite ids the same way it already does for the compass and pips. `Vehicle` gained a small public
accessor next to the existing `toggle_heli_slot()` (no new state -- `_heli_slot` already *is* the traced flag):

```gdscript
## Which weapon is currently selected (0 gun, 1 bomb) -- obj+0xc bit 0x10000000 in the original
## (FUN_0040e600/FUN_0040e7a0, document 63), also read by the panel's weapon-select icons (document 83).
func heli_weapon_slot() -> int:
	return _heli_slot
```

`game/hud_panel.gd` builds the two icons only for the Heli (`if t == 3`) and swaps their texture every frame:

```gdscript
if _weapon_select_bomb != null:
	var ids: Dictionary = mc.pack.hud_panels["weapon_select"]["sprite_ids"]
	var bomb_selected := v.heli_weapon_slot() == 1
	_weapon_select_bomb.texture = _atlas(String(ids["bomb_lit" if bomb_selected else "bomb_dim"]))
	_weapon_select_gun.texture = _atlas(String(ids["gun_dim" if bomb_selected else "gun_lit"]))
```

Checked by `tools/tests/weapon_select_check.gd`: the Heli's panel gets both icons at the traced positions (273, 60)
and (108, 108) *(post-3x-scale)*, showing `bomb_dim`/`gun_lit` by default and swapping to `bomb_lit`/`gun_dim` after
`toggle_heli_slot()`; a Tank's panel gets neither. A real screenshot (`RF_VEHICLE=heli`) shows the twin-bar gun icon
lit in its traced spot; the dim bomb icon is -- correctly -- hard to make out against the panel's own grey, which is
the point of "dim".

**Not done:** the exact `FUN_00412cd0` z/depth adjustments the disassembly showed (`[eax+0x18] -= 0xe353`,
`[eax+0x24] -= 0xccc`) are draw-order/priority values with no 2D-UI equivalent needed here, and are not reproduced.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
