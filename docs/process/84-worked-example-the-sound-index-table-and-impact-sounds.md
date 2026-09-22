# 84. Worked example: the table at 0x44b9a0 is the whole engine's sound index, not a small pool

**Question:** document 82 resolved every sound-cue address to a real file, but left the table at `0x44b9a0` labelled
a small, oddly-mixed "indexed pool" (Button, GateMove, GateClose, GClick, a few unresolved ambience entries) that
didn't look like the "explosion variant pool" document 50 originally called it. Meanwhile document 50 had already
traced every explosion/impact record's script into `tools/data/explosion_records.json`, including a `SOUND n` opcode
whose `n` was recorded as a plain integer (2, 28-37, ...) and never resolved to an actual sound.

## The table is bigger than it looked

A fresh, larger dump (`DumpDwords.java 0x44b9a0 40`, i.e. 40 dwords instead of the 10 read for document 82) shows the
table does not stop at 10 entries — it keeps going, one pointer per descriptor row, in exactly the same order as the
descriptor table itself:

```
index  0   1        2        3        4        5        6         7          8       9      10    11       ...
addr  0x44b580  598  0x44b5b0  5c8  5e0  5f8  0x44b610  0x44b628  0x44b640  0x44b658  0x44b670  0x44b688  ...
name  Button    ?    SmallBoom  ?    ?    ?   GateMove  GateClose  GClick   Reload*   Ding      FuelWarn  ...
```

**This is not a special-purpose pool at all — it is the engine's one canonical, contiguous sound index**, the same
array `FUN_004232d0` calls index into whenever a script says "play sound `n`", covering the *entire* descriptor table
document 82 already resolved (index 0 = `Button` through at least index 39 = `DumbDirect`). Document 50's "table at
0x44b9a0" comment was correct about the mechanism, just misleading about the scope — every scripted object in the
game (explosions, gates, mines, whatever else has a byte-coded script) shares this one array.

## Cross-referencing it against `explosion_records.json` resolves every hit sound for free

With the index table in hand, every `SOUND n` opcode already extracted becomes a lookup, not a guess:

| Record | Script | Index -> address -> label | Resolves to |
|---|---|---|---|
| `0x444740` (ground, shell-like) | `SOUND 37` | `0x44b8f8` = SmDirt Hit | `Sound/DirtHit.SDT` |
| `0x444840` (ground) | `SOUND 36` | `0x44b8e0` = Dirt Hit | `Sound/MissileU.SDT` (document 82's surprise) |
| `0x4445b8` (water, shell-like) | `SOUND 29` | `0x44b838` = SmSplash | `Sound/Splash.SDT` |
| `0x4445e8` (water) | `SOUND 28` | `0x44b820` = Splash | `Sound/Splash.SDT` |
| `0x444968` (pavement, shell-like) | `SOUND 35` | `0x44b8c8` = SmConcrete Hit | `Sound/Concrete.SDT` |
| `0x444a30` (pavement) | `SOUND 34` | `0x44b8b0` = Concrete Hit | `Sound/MissileU.SDT` |
| `0x444b68` (vehicle hit) | `REPEAT 4` / `SOUND 30,31,32,33` | MetalHit1-4 | `Sound/MetalHi.SDT` (all four) |
| `0x444ac8` (tile/gate hit) | `SOUND 2` | `0x44b5b0` = **SmallBoom** (new, document 82 left this address unresolved) | `Sound/Boom.SDT` |

Every single one lines up exactly with what the cue's own debug label already implied (a ground hit plays a dirt
sound, a water hit plays a splash, ...) — a satisfying confirmation that document 82's file resolutions were correct,
via a completely independent path (script opcodes, not manual address-by-address dumping). The one previously
unresolved address this closes out is `0x44b5b0`, index 2 in the table: its name pointer is `"SmallBoom"` (the same
short-label table document 82 read the others from) and its resource resolves to `Sound/Boom.SDT` — `BOOM.wav`.

`0x444b68` (a shot hitting a vehicle) plays a `REPEAT 4` block cycling through all four `MetalHit` variants over the
explosion object's multi-tick lifetime — not a single choice. The port's hit sound is one discrete event per
collision, not a scripted multi-tick object, so it can't reproduce the repeat; it picks one of the four uniformly at
random instead (a marked port choice, not a rediscovery of the original's actual selection rule, which is simply
"all four, one per script tick").

## Applied in the port

`MatchController` already has an `impact_effect(record_addr, position)` signal (Phase-4-era, used for visual
effects) whose `record_addr` values are exactly the addresses in the table above — no new plumbing needed, just a
lookup:

```gdscript
const IMPACT_SOUND_CUES := {
	"0x444740": "SmDirtHit", "0x444840": "DirtHit",
	"0x4445b8": "SmSplash", "0x4445e8": "Splash",
	"0x444968": "SmConcreteHit", "0x444a30": "ConcreteHit",
	"0x444ac8": "SmallBoom",
}
const IMPACT_SOUND_CUES_RANDOM := {
	"0x444b68": ["MetalHit1", "MetalHit2", "MetalHit3", "MetalHit4"],
}

func _on_impact_effect_sound(record_addr: String, _position: Vector2) -> void:
	if vehicle == null:
		return
	if IMPACT_SOUND_CUES.has(record_addr):
		vehicle.sound_cue.emit(IMPACT_SOUND_CUES[record_addr])
	elif IMPACT_SOUND_CUES_RANDOM.has(record_addr):
		var choices: Array = IMPACT_SOUND_CUES_RANDOM[record_addr]
		vehicle.sound_cue.emit(choices[randi() % choices.size()])
```

connected once in `setup()`: `impact_effect.connect(_on_impact_effect_sound)`. Checked by
`tools/tests/impact_sound_check.gd`: every one of the eight record addresses above resolves to the expected cue (or,
for the vehicle-hit case, one of the four expected cues).

Two more cues from document 82's remaining list were also wired this session, independent of this table: the Tank's
cannon fire (`Cannon`, `game/vehicle.gd Vehicle._fire()`'s `vehicle_type == 0` branch) and the MSV's mine-layer throw
(`ThrowGrenade1_a/b/c`, `MatchController._on_mine_dropped()`, one of the three picked at random — the original's
actual selection rule between the three identically-labelled "Throw Grenade1" descriptors was not found, another
marked port choice). 27 of the 41 traced cues are now wired to a real trigger.

**Not done:** the remaining ~14 traced-but-unwired cues (`tools/data/sound_cues.json`'s `applied: false` entries);
`FuelWarn`, `Button` (mine blink), `PanelUp`, `ManCrush`, `Laugh`, `JeepStart`, the debug-menu-only `TestSnd L/R`,
`PreRaise`, and `Servo` (the Heli's landing rotor spin-down, which the port doesn't model at all yet). The five
remaining unresolved indices in the sound-index table's low end (1, 3, 4, 5 — the separate looping/ambience
sub-block document 82 already flagged) are still not decoded.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
