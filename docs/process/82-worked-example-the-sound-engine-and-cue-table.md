# 82. Worked example: the sound engine, and a full cue -> file table

**Question:** documents 44-81 accumulated about forty "sound `0xNNNNNN`" addresses (the empty click, the gate sounds, the
compass ding, the dock lift, ...) with no idea what any of them actually play, and no sound plays in the port at all.
Sound is next on [the next-steps doc](NEXT_STEPS.md). Two things were needed before wiring up a single cue: how the
engine turns one of those addresses into an actual `.wav`, and what file each of the addresses already on record
resolves to.

## Part A: the engine, address by address

### Step 1: the enqueue call every doc has already been quoting

Every "sound `0xNNNNNN`" comment across documents 44-81 is a call of the same function, e.g. document 72's empty
click: `FUN_004232d0(1, 0x44b988, ...)`. Decompiled (`DecompileMany.java 4232d0 423400`):

```c
int * __cdecl FUN_004232d0(int param_1,int param_2,int param_3,int param_4)
{
  int *piVar1;
  while( true ) {
    piVar1 = FUN_00429510((int *)&DAT_0048ca50);   // pop a free node
    if (piVar1 != (int *)0x0) break;
    FUN_00423770(DAT_00442ea8);                     // pool empty: wait/yield
  }
  piVar1[2] = param_1;   // command type
  piVar1[3] = param_2;   // the descriptor address, e.g. 0x44b988
  piVar1[4] = param_3;   // a "source" object, for positional audio
  FUN_004295b0(0x48ca60,piVar1);   // push onto the work queue
  ...
  return piVar1;
}
```

This is a generic command queue, not something sound-specific: `param_1` is a command type, dispatched later by a
jump table. Its consumer, `FUN_004085a0` (found by scanning raw bytes for references to the two queue globals with
`FindPointerRefsMulti.java 48ca60 48ca50`):

```c
undefined4 FUN_004085a0(void)
{
  while( true ) {
    piVar1 = FUN_00429510((int *)&DAT_0048ca60);   // pop a queued command
    if (piVar1 == (int *)0x0) break;
    if (piVar1[2] != 0) {
      iVar2 = (*(code *)(&PTR_LAB_00442ed8)[piVar1[2]])(piVar1);   // dispatch by type
      piVar1[5] = iVar2;
    }
    FUN_00429570((int *)&DAT_0048ca50,piVar1);   // return the node to the free pool
  }
}
```

`DumpDwords.java 442ed8 12` gives the jump table; type 1 (what every "sound" call in this project has used so far)
is `FUN_00408600`:

```c
// FUN_00408600 (disassembly -- Ghidra won't decompile it, DisasmForce.java 4085f0 408700)
ESI = param_1                       // the queued node
EAX = [ESI + 0x10]                  // piVar1[4]: the "source" object
ECX = [ESI + 0xc]                   // piVar1[3]: the descriptor address
CALL FUN_00408170(ECX, EAX)         // FUN_00408170(descriptor, source)
if (EAX != 0) [ESI + 8] = [EAX + 0x14]
```

### Step 2: `FUN_00408170`, the descriptor struct, and where a filename finally shows up

```c
int * __cdecl FUN_00408170(int param_1,int param_2)   // param_1 = descriptor addr, param_2 = source object
{
  iVar4 = *(int *)(param_1 + 4);              // the RESOURCE this descriptor plays
  if (*(int *)(iVar4 + 8) < 1) return 0;       // resource not loaded
  piVar2 = FUN_004294f0(&DAT_0048cac0);        // allocate a voice
  piVar2[4] = param_1;
  piVar2[7] = *(byte *)(param_1 + 8);          // fade-in volume
  piVar2[8] = *(byte *)(param_1 + 9);          // fade-out/sustain volume
  piVar2[6] = *(byte *)(param_1 + 10) + DAT_0048ca48;   // fade deadline = now + byte(+0xa)
  ... bit 0x20 of byte(+0xb) picks the stepper (one-shot vs looping) ...
  iVar1 = *(int *)(param_1 + 0xc);             // pitch: 0 = resource default, >0 = explicit, <0 = relative
  piVar2[0x10] = iVar1 (or the resource's own rate if 0, or a negative-scaled rate if <0);
  piVar2[0x11] = *(int *)(param_1 + 0x10);     // length / loop-count override
  FUN_00408050(piVar2, param_2);               // untraced: presumably positional volume/pan from param_2's position
  (*(code *)piVar2[0x12])(piVar2);             // first step
  FUN_00429670(&DAT_0048cab0, piVar2, FUN_00407b60);   // added to the active-voices list
  if (piVar2[0xc] != 0 && *(code**)(param_1 + 0x14) != 0) (**(code**)(param_1 + 0x14))(piVar2);
  return piVar2;
}
```

So every descriptor is a fixed 0x18-byte row:

| offset | field | meaning |
|---|---|---|
| `+0x00` | `name_ptr` | a debug label string (the level-editor sound-test menu, document 31) -- descriptive only |
| `+0x04` | `resource_ptr` | the loaded sample: `+0x08` = sample count (must be >=1 or the play is dropped), `+0x10` = base playback rate |
| `+0x08` | byte | fade-in volume |
| `+0x09` | byte | fade-out/sustain volume |
| `+0x0a` | byte | fade ticks (added to the current tick to make a deadline) |
| `+0x0b` | byte | flags (bit `0x20` selects the looping stepper) |
| `+0x0c` | dword | pitch (0 = resource default, >0 = explicit override, <0 = relative multiplier) |
| `+0x10` | dword | length / loop-count override |
| `+0x14` | dword | completion callback (nullable) |

`FUN_00408170` reads `resource_ptr` (`+4`), and the resource struct's own `+0` is a **filename string pointer**
straight into a table of `"Sound/<Name>.SDT"` C strings (found by searching raw bytes for the ASCII `.SDT`,
`FindBytes.java 2e534454`, then reading the hit region with `DumpStringAt.java`) -- for example the empty click's
resource at `0x0044b4e4` holds `0x0044ade8`, which is the string `"Sound/OutAmmo.SDT"`. That file is exactly
`build/sound/OUTAMMO.wav` (document 2's SDT->wav conversion): the whole chain, from a "sound `0xNNNNNN`" address a
past document only guessed at, to a real file on disk, is now traced end to end.

**Untraced/not applied by this document:** `FUN_00408050` (presumably positional volume/pan by the source object's
distance, never read); the fade-in/fade-out envelope (`+8`/`+9`/`+0xa` bytes) and the looping stepper (`+0xb` bit
`0x20`); the announcer's 18 voice lines (document 71, table at `0x4463b8`) are a **wholly separate mechanism** with
no matching audio file found anywhere -- they are not sound-cue descriptors and are not covered by this table.

## Part B: resolving every address earlier documents already recorded

Every "sound `0xNNNNNN`" comment in documents 44-81 turned out to be a row in exactly this table (base `~0x0044b500`,
rows every `0x18` bytes). Dumping the whole block (`DumpDwords.java 44b610 240`, plus the `resource_ptr -> filename`
step above) resolves all of them at once:

| addr | label | file | wav | prior doc(s) |
|---|---|---|---|---|
| `0x44b550` | heli | Sound/Heli.SDT | **HELI.wav** | 79 (Heli spin-up) -- **applied** |
| `0x44b580` | Button | Sound/Button.SDT | BUTTON.wav | 50-51 (mine blink) |
| `0x44b610` | GateMove | Sound/GateMove.SDT | GATEMOVE.wav | 56 |
| `0x44b628` | GateClose | Sound/Click.SDT | CLICK.wav | 56 |
| `0x44b640` | GClick | Sound/Click.SDT | CLICK.wav | 76 (cursor move) |
| `0x44b658` | "Reload" | Sound/Servo.SDT | SERVO.wav | 72 -- **label is misleading, see note below** |
| `0x44b670` | Ding | Sound/Ding.SDT | DING.wav | 72, 77 |
| `0x44b688` | FuelWarn | Sound/FuelWarn.SDT | FUELWARN.wav | 55 |
| `0x44b6a0` | PanelUp | Sound/Click.SDT | CLICK.wav | -- |
| `0x44b6b8` | BushCrush | Sound/BushCrus.SDT | BUSHCRUS.wav | 54 |
| `0x44b6d0` | ExplLarge | Sound/ExplLar.SDT | EXPLLAR.wav | 50-51 |
| `0x44b6e8` | ExplDebris | Sound/ExplDeb.SDT | EXPLDEB.wav | 50-51 |
| `0x44b700` | ExplLow | Sound/ExplLow.SDT | EXPLLOW.wav | 44, 50-51 |
| `0x44b718` | ManCrush | Sound/ManCrush.SDT | MANCRUSH.wav | -- |
| `0x44b730` | Cannon | Sound/Cannon.SDT | CANNON.wav | 63-64 |
| `0x44b748`/`760`/`778` | "Throw Grenade1" x3 | Sound/Throw1/2/3.SDT | THROW1/2/3.wav | 60-61 |
| `0x44b790` | Laugh | Sound/Laugh.SDT | LAUGH.wav | -- |
| `0x44b7a8`/`7c0` | "TestSnd L/R" | Sound/Click.SDT | CLICK.wav | 31 (debug menu only) |
| `0x44b7d8` | Raise | Sound/Raise.SDT | RAISE.wav | 77-78 |
| `0x44b7f0` | PreRaise | Sound/PreRais.SDT | PRERAIS.wav | 77-78 |
| `0x44b808` | Servo | Sound/Servo.SDT | SERVO.wav | 77 (Heli rotor-down) |
| `0x44b820`/`838` | Splash / SmSplash | Sound/Splash.SDT | SPLASH.wav | 62 |
| `0x44b850`-`898` | MetalHit1-4 | Sound/MetalHi.SDT | METALHI.wav | 45, 47 |
| `0x44b8b0` | "Concrete Hit" | **Sound/MissileU.SDT** | MISSILEU.wav | 45 -- **see note below** |
| `0x44b8c8` | SmConcrete Hit | Sound/Concrete.SDT | CONCRETE.wav | 45 |
| `0x44b8e0` | "Dirt Hit" | **Sound/MissileU.SDT** | MISSILEU.wav | 45 -- **see note below** |
| `0x44b8f8` | SmDirt Hit | Sound/DirtHit.SDT | DIRTHIT.wav | 45 |
| `0x44b910` | JeepStart | Sound/JeepStar.SDT | JEEPSTAR.wav | -- |
| `0x44b928` | DumbDirect | Sound/Beacon.SDT | BEACON.wav | 71 (compass ding) |
| `0x44b940`/`958` | TireIn / TireOut | Sound/Tirein/Tireout.SDT | TIREIN/TIREOUT.wav | 62 |
| `0x44b970` | HeliClick | Sound/Click.SDT | CLICK.wav | 63 |
| `0x44b988` | OutAmmo | Sound/OutAmmo.SDT | OUTAMMO.wav | 61, 63, 72, 79 -- **applied** |

The full table, with every raw address (`resource_addr` too) and per-cue notes, is `tools/data/sound_cues.json` --
that file, not this one, is the thing to re-check before wiring up any specific cue later.

**Two results worth flagging rather than smoothing over (trace-don't-guess):**
- The row labelled `"Reload"` does **not** point at `Sound/Reload.SDT`. Its resource pointer resolves to
  `Sound/Servo.SDT`, the same file the `Servo` row (Heli rotor spin-down, document 77) uses. Checked twice against a
  fresh dump, not a transcription slip. The real `Sound/Reload.SDT` (`RELOAD.wav`) is not referenced by any
  descriptor in this block at all -- it must live in the separate, still-undecoded sub-block below `0x44b550` (see
  "Not applied" below), or somewhere this document didn't look.
- The "full-size" `"Concrete Hit"` and `"Dirt Hit"` rows share one resource and both resolve to `Sound/MissileU.SDT`
  -- only their `"Sm"` (small) counterparts use the sample the label would suggest. Read at face value rather than
  corrected to match expectation: a bigger structure/ground hit apparently reuses the missile-impact sample, and
  only the smaller hit gets a dedicated texture.

Also resolved: `0x44b9a0`, cited by documents 50 and 60 as "the table", is a plain array of ten of the addresses
above (`0x44b580, 0x44b598, ..., 0x44b658`) -- an explosion/impact sound variant pool, not a descriptor itself.

## Applied in the port

Two cues had an exact trigger point already marked in the code, from before this document existed:

**The empty click** (document 72's `FUN_004232d0(1, 0x44b988, ...)`, `game/vehicle.gd`'s existing `empty_click`
signal):

```gdscript
# game/vehicle.gd, Vehicle._spend_ammo()
if ammo[slot] < 1:
    empty_click.emit()
    sound_cue.emit("OutAmmo")
    return false
```

**The Heli spin-up chime** (document 79's `FUN_0040e8c0 -> FUN_0040e930`, "sound 0x44b550 here, once the sound pass
exists" -- the exact hook was already commented in, just waiting for a file):

```gdscript
# game/vehicle.gd, Vehicle._process_heli_spinup()
if _heli_spinup_progress >= 1.0:
    heli_spinup_stage = 2
    sound_cue.emit("Heli")   # FUN_0040e8c0 -> FUN_0040e930, sound 0x44b550 (document 82)
```

`Vehicle` gained one new generic signal rather than one per cue, so future sessions wiring up the other ~35 traced
rows don't need a new signal each time:

```gdscript
## Fired at a traced sound-cue trigger point (document 82); `id` is a key of
## tools/data/sound_cues.json / packs/*/audio/audio.json, e.g. "OutAmmo", "Heli".
signal sound_cue(id: String)
```

The pack/presentation split this project already uses everywhere else (a gameplay node emits a signal, a
presentation node reacts -- `MatchController`'s `gate_created`, `Vehicle`'s `shot`, etc.) carries over to sound
unchanged: `Vehicle` never touches an `AudioStreamPlayer` itself.

**`tools/build_pack.py`** copies the already-converted `build/sound/*.wav` files into the pack and writes
`audio/audio.json` (`PORTING_PLAN.md` section 2.4.2's `id -> {file, category, priority}` schema) straight from
`tools/data/sound_cues.json`:

```python
# tools/build_pack.py
for cue_id, cue in sound_cues.items():
    wav = cue["wav"]
    src = os.path.join(args.build_sound_dir, wav)
    if not os.path.exists(src):
        continue
    if wav not in copied:
        shutil.copyfile(src, os.path.join(audio_dir, wav))
        copied.add(wav)
    audio_json[cue_id] = {"file": wav, "category": "sfx", "priority": 0}
```

**`game/pack.gd`** loads that manifest the same way it loads every other pack file (raw `FileAccess`/`JSON`, never
`res://`'s import pipeline):

```gdscript
var audio_path := dir.path_join("audio/audio.json")
if FileAccess.file_exists(audio_path):
    var adoc: Variant = _read_json(audio_path)
    if adoc is Dictionary:
        audio = adoc

func get_sound_path(cue_id: String) -> String:
    var entry := get_sound(cue_id)
    if entry.is_empty():
        return ""
    return pack_dir.path_join("audio").path_join(String(entry.get("file", "")))
```

**`game/sound_manager.gd`** (new) is the presentation-side listener: a small `AudioStreamPlayer` pool that loads
each `.wav` on first use with `AudioStreamWAV.load_from_file()` (again bypassing `res://` import, matching
`Pack.gd`'s raw `Image.load()` for sprites) and connects to a `Vehicle`'s `sound_cue` signal:

```gdscript
func connect_vehicle(v: Vehicle) -> void:
    v.sound_cue.connect(play)

func play(cue_id: String) -> void:
    var stream := _stream_for(cue_id)
    if stream == null:
        return
    var player := _free_player()
    player.stream = stream
    player.play()
```

`game/terrain_view_3d.gd` instantiates one `SoundManager`, gives it the loaded `Pack`, and connects it to the
player's `Vehicle` right where the scene already wires up the billboard and HUD:

```gdscript
_sound = SoundManager.new()
add_child(_sound)
_sound.setup(pack)
if controller.vehicle != null:
    ...
    _sound.connect_vehicle(controller.vehicle)
```

## Not applied

Positional volume/pan (`FUN_00408050`), fade envelopes, looping cues, and the separate sub-block of descriptors
below `0x44b550` that have a non-null completion callback (read as self-restarting ambience -- engine drone, tread,
jeep idle -- rather than one-shots; the callback bodies at `0x0040ee60`/`0x0040eeb0` were not decompiled). Of the
~38 one-shot rows resolved in Part B, only `heli` and `OutAmmo` are wired to a gameplay trigger; the rest are traced
(file, and in most cases a candidate trigger point) in `tools/data/sound_cues.json` but not yet connected to
anything, mirroring how document 71 left the announcer's table "recorded... for the audio pass" rather than
half-wired. The announcer's voice lines themselves remain entirely unresolved -- no matching audio file has been
found for any of the 18 lines.

**Next:** wire up more of the traced-but-not-applied rows (`tools/data/sound_cues.json`'s `applied: false` entries
each note a candidate trigger point) once their exact call site is traced, the same way `heli`/`OutAmmo` already
had a marked hook waiting. Back to [the next-steps doc](NEXT_STEPS.md).
