# 93. Worked example: the level-1 building's stages, checked against the original's damage code

**Question:** the next-steps list said the building's second stage (ruin 62 -> finished ruin 63) was only partly traced ("document 45: not done"). Is anything still missing for what level 1 asks of the building? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

**Answer, up front:** nothing on the path level 1 takes. The stage was already traced (document 44) and applied; the "not done" line in document 45 was stale, and I repeated it in the ranking without checking the port. What this document adds is the one part of the damage function nobody had read closely, the per-hit branch, and why it does not fire for these buildings.

## The damage function, `FUN_0042e8c0`

Called with (damage in 16.16, position, the tile word, a table entry or 0). Decompiled (`DecompileMany.java 0x0042e8c0 0x0042e9c0`):

```c
piVar1 = param_4 ? param_4 : &DAT_00447030 + ((*tile & 0x3f80) >> 7) * 0x38;   // the coastal table entry of the tile's id
hp = *tile & 0xe000000;                                     // hit points: bits 25-27 of the tile word
if (hp != 0 && (dmg = damage - piVar1[8]) > 0) {           // armour
  if (piVar1[9] != 0) dmg = dmg * piVar1[9];                // multiplier
  if (piVar1[6] != 0) { dmg = (*piVar1[6])(...); goto done; }   // a custom handler
  dmg >>= 16; if (dmg < 1) dmg = 1;                         // whole hit points, at least 1
  hp >>= 25;
  if (hp <= dmg) { dmg = 1; *tile &= 0xf1ffffff; goto done; }   // out of hit points: clear them and destroy
  if (hp > 1 && hp - dmg < 2 && (piVar1[3] & 0xff8000) != 0)
      FUN_00434980(tile, piVar1);                           // ONE HIT POINT LEFT: throw debris (only if the entry asks for it)
  *tile = ... (hp - dmg) << 25 ...;                          // store the remaining hit points
}
done: if (dmg == 0) return -1;
      if (piVar1[7] == 0) FUN_0042e6a0(position, tile, piVar1);   // the state change: destroyed id, ground art, effect
      else (*piVar1[7])();                                       // the entry's own destroy handler (id 22: FUN_00432710, the target pool)
```

The three entries of the level-1 building (table `0x447030`, 0x38 bytes each; `DumpDwords.java` at `0x447500`, `0x447dc0`, `0x447df8`):

| id | address | `[3]` (debris flags) | `[4]` (art + hit points) | `[6]`, `[8]`, `[9]` | `[7]` (destroy handler) | means |
| --- | --- | --- | --- | --- | --- | --- |
| 22 | `0x447500` | 0 | `0x66d` = art 0x6d = 109, 6 hp | 0 | `0x432710` | intact building, 6 hp, target-pool handler |
| 62 | `0x447dc0` | 0 | `0x66e` = art 110, 6 hp | 0 | 0 | first ruin, 6 hp |
| 63 | `0x447df8` | 0 | `0x6f` = art 111, 0 hp | 0 | 0 | finished ruin, indestructible; its contact callback (`[5]` = `0x432d80`, another field) grabs the flag (document 67) |

So: no armour, no multiplier and no custom damage handler (a Tank shell's 1.0 removes 1 hit point, a Heli bomb's 4.0 removes 4); **the debris branch needs `entry[3] & 0xff8000` and all three entries have 0 there**, so a building takes 6 plain hits to become 62, 6 more to become 63, and shows no intermediate damage on the way. (`FUN_00434980` is used by other ids that ask for debris; it throws `[3]`-counted sprites of object `0x44eb38` around the tile. Not needed for level 1.)

## The port

`MatchController._damage_tile_amount` is the same function:

```gdscript
var hp: int = _tile_hp.get(t, _initial_tile_hp(t))   # bits 25-27, from the table entry ("hp": 6 for ids 22 and 62)
if hp <= 0:
	return false                                     # id 63: indestructible, the shell is still stopped
var dmg := maxi(int(damage), 1)                      # >> 16, at least 1
if hp > dmg:
	_tile_hp[t] = hp - dmg
	return false
...                                                  # out of hit points: the pool handler (id 22) or a plain state change, tile_destroyed.emit(t)
```

`tools/tests/playthrough_rfmap001.gd` shows the chain end to end: **the building becomes 62 after 126 ticks of shooting (the flag appears at once), the ruin becomes 63 after 120 more, then a Jeep takes the flag from the posts and drives it home** (`match finished true winner 0`).

## Not done / untraced

- **The debris branch** (`FUN_00434980`) is not modelled: nothing in level 1 uses it; the ids that ask for it (entries with `[3] & 0xff8000`) were not listed.
- **Which explosion plays at each stage** is traced in documents 50 and 51 (the record of the destroyed tile); not re-checked here.
- **The tile word's hit points after a crush** (`FUN_0042e8c0` is also called with damage from vehicles' weight): not compared line by line.

**Next:** [the next-steps doc](NEXT_STEPS.md).
