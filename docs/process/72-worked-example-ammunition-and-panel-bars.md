# 72. Worked example: ammunition: what each shot costs, how a rearm zone refills, and the ammo bars

**Question:** ammunition was traced piecemeal (documents 45, 55, 58, 60, 61, 63) and left out of the port on your instruction. Now that the panel exists (documents 68-71), how does each weapon spend
and regain rounds, and how is it shown? Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: where the numbers live

Each vehicle record has two weapon blocks (`+0x194` and `+0x1c8`, `0x34` bytes each) whose `+0x10` is the cooldown in ticks and `+0x14` the stock; the state block has, per slot `n`, four dwords at
`state + 0x24 + n * 0x10`: `+8` = the tick the slot is ready again, `+0xc` = the rounds left. `DumpDwords.java 0x4456b8 2980` (all four records) gives (`tools/extract_vehicle_types.py` now writes `ammo` and `weapon_cooldown_ticks`):

| vehicle | slot 0: stock / cooldown | slot 1: stock / cooldown |
| --- | --- | --- |
| Tank | 150 shells / 20 ticks | none |
| Jeep | 16 missiles / 30 | none |
| MSV | 100 rockets / 30 | 10 mines / 140 |
| Heli | 100 gun rounds / 15 | 50 bombs / 30 |

## Step 2: what a shot costs (the four fire handlers, decompiled again for this)

All four have the same shape (`FUN_0040d240` Tank, `FUN_0040d520` MSV, `FUN_0040df00` Jeep, `FUN_0040e600` Heli):

```c
if (ready > now) return;
if (ammo < 1) { FUN_004232d0(1, 0x44b988, ...);  ready = now + cooldown;  return; }   /* the empty click */
proj = <create the shot>;
if (proj) { ready = now + cooldown;  ammo -= 1;  FUN_00412cb0(panel, ...); }           /* redraw the bar */
```

**One round per projectile**, and only if the shot was actually created. Details: the Tank's raised gun uses the same slot 0; the MSV pays one rocket of a salvo of three each; when its stock reaches 0 during a salvo it clamps to 0
and starts the same reload as after the third rocket (state `+0x58 = -6.0`, i.e. 40 ticks); the mine layer (`FUN_0040d820`, document 60) needs `ammo > 0` as a *condition* (no click) and pays one mine.
The empty click's cooldown is the slot's own, so a held button clicks once per cooldown. The click sound `0x44b988` is not played by the port yet (the `empty_click` signal is there for the sound pass).

## Step 3: the refill (`FUN_0040c540`, the rearm zone, kind 2)

Already read in document 55: a vehicle standing still on a rearm zone (coastal 14) runs, each tick,

```c
for (slot = 0; slot < slots[type]; slot++) {                 /* slots: table at 0x4453c8 */
   gain = max(1, (dt << 15) >> 16);                          /* dt whole ticks: 1 per tick */
   ammo[slot] += gain;
   if (ammo[slot] < cap[slot]) break;                       /* still filling: stop here this tick */
   ammo[slot] = cap[slot];                                   /* full: the same tick's gain goes on to the next slot */
}
```
with the looping sound every 40 ticks (`0x44b670`). Numerically: **one round per tick per slot, slots one after another** (a Tank goes from 0 to 150 in 150 ticks = 2.4 s; the MSV fills its rockets, then its mines).

## Step 4: how the panel shows it (document 70's kinds)

Kind 4 (`FUN_00411da0`, Tank, MSV, Heli) is a bar like the fuel bar: the value is `state + 0x30 + ...` (the ammo dword), the fill is `width / stock` pixels per round, easing 0.6 px per tick, with the *ammunition* colour set at `0x446778`
and thresholds `1/16`, `1/4` and `3/16` of the bar (`f < w/4`: colour 2, or 0 below `w/16`; else colour 6, or 4 below `3 * (w >> 4)`). Kind 7 (`FUN_004127b0`, the Jeep) draws one missile pip cel per round: pip `i` (1 to 16) at
`(x[i], y[i])` from the tables `0x446798` / `0x4467e0`: two rows of eight, x = 62, 70 ... 118, y = 21.5 and 38.5, cel `0x20ac0` = **1968**; when the count falls it paints cel `0x7af` = 1967 over the pip (the panel is a persistent
picture, so it must erase), when it rises it draws the missile. Those two cels are now `ui.hud.pip_missile` / `ui.hud.pip_erase` in the registry (hand edit plus `AUDIT9`). Note the fuel bar's thresholds use `right - left` (39 for the Tank),
the fill `right - left + 1` (40); the port had used 40 for both, corrected.

## Applied in the port

`Vehicle.ammo` / `ammo_max` (from the pack), `_spend_ammo` in the four fire paths and the mine layer, `rearm()` called by the controller's zone update, `empty_click` signal, ammo reset on respawn and on a vehicle change;
`game/hud_panel.gd` draws the ammo bars and the Jeep's pips. Checked by `tools/tests/ammo_check.gd` (a held fire button for 6000 ticks: Tank 150 shots, Jeep 16, MSV 100, Heli 100, each then clicking; a Tank at 0 in a rearm zone reads 150 after
200 ticks), by the level playthrough (still won) and by screenshots of the four panels (bars part-empty, Jeep pips on the rack in two rows of eight).
**Placeholder, not traced:** the enemy placeholder vehicles fire without limit (`infinite_ammo`), since nothing rearms them. **Not done:** the click and rearm sounds; the pips' one-at-a-time animation; the vehicle-stock counts (template slot 2,
`FUN_004116a0`, document 66) that show how many vehicles of each type are left; the bar colours are still the unverified 15-bit reading.

**Next:** the vehicle stock (`FUN_0040b400`, the counts at `0x48c880 + player * 0xd0 + 0xb8`), then sounds.
