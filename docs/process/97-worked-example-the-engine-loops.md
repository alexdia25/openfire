# 97. Worked example: the vehicles' continuous engine sounds

**Question:** every sound cue of document 82 is a one-shot in the port, but the original's Tank, Jeep and Heli make a continuous sound while they exist (the "drone" of the reference footage), whose pitch follows how fast they go. What are the sounds, when do they start, and how is their pitch set? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: three descriptors that the cue table's completion-callback column belongs to

Document 82's table of 0x18-byte descriptors (`+0` label, `+4` resource, `+8` fade-in volume, `+9` sustain volume, `+0xa` fade ticks, `+0xb` flags, `+0xc` pitch, `+0x10` length, `+0x14` callback) starts at `0x44b520`, not `0x44b550`: three rows before the one document 82 began with have a **callback** (`DumpDwords.java 0x44b520 30`):

```
0x44b520  label 0x44adcc  resource 0x44b1d4  bytes d2 64 0a 01  pitch 0x4ef   length 0xd55   callback 0x40ee60
0x44b538  label 0x44adc4  resource 0x44b260  bytes d2 64 0a 01  pitch 0x1b92  length 0xccc   callback 0x40ee60
0x44b550  label 0x44adbc  resource 0x44b20c  bytes d2 64 0a 01  pitch 0      length 0x10a3  callback 0x40eeb0
0x44b568  (0x44305c)      resource 0x44b458  bytes d2 96 14 21  pitch -1.0   length 0x1111  callback 0
```

The resources' filename pointers (`0x44afec`, `0x44af90`, `0x44afc8`, `0x44ae38`; strings decoded from `DumpDwords.java 0x44af40 80`) are **`Sound/Tread.SDT`, `Sound/JeepIdle.SDT`, `Sound/Heli.SDT`** and `Sound/Drone.SDT`. All are 11025 Hz 8-bit mono. So `0x44b550`, which document 82 (and documents 79 and 82's cue table) took for a "Heli chime" played once at the rotor start-up, is the **rotor's loop**. The volume bytes are `210` then `100`: loud for `+0xa` = 10 ticks (the attack), then the sustain level.

## Step 2: who starts them

`FindPointerRefsMulti.java 0044b520 0044b538 0044b550`:

- **Tank and MSV**: the vehicle records hold `0x44b520` at `+0x240` (`0x4458f8` and `0x445ec8`, `DumpDwords.java 0x4458f8 4`): the per-type "sound at creation" field of document 82 (`FUN_0040b980`'s panel-activation block, "not one of the 42 cues"): it is the Tread loop.
- **Jeep**: the record's `+0x240` is `JeepStart` (`0x44b910`, one-shot); the loop is started by the Jeep's state handler at `0x40d940` (`DisasmForce.java 0x40d940 0x40d990`):

```
0040d94d  CMP [ESI+0x60],EAX ; JA later      ; a timer after creation
0040d952  PUSH 1 ; PUSH EDI ; PUSH 0x44b538 ; PUSH 1 ; CALL 0x004232d0    ; enqueue JeepIdle, attached to the vehicle (kind 1)
0040d969  MOV [ESI+0xc],0x40d990              ; the Jeep's main state handler takes over
```

- **Heli**: `0x40e8f5` (inside the rotor start-up, the stage whose accumulator `[ESI+0x58]` passes `0x10000`, document 79): `PUSH 0x44b550 ; CALL 0x4232d0`.

The voice is attached to the vehicle object (`kind` 1), so it ends with the object.

## Step 3: the pitch callbacks

`DisasmForce.java 0x40ee60 0x40ef00` and `0x40eeb0 0x40ef00` (start the disassembly at the callback's own address, Ghidra never made them functions):

```
; 0x40ee60  (Tank, MSV, Jeep)
ECX = record[+0x244]; EBX = record[+0x248] - ECX;  EAX = |obj.speed (+0x54)|
pitch = ((EBX * EAX) >> 16) + ECX ;  voice[+0x40] = pitch ;  FUN_00423af0(handle, pitch, 2)    ; set the playing sound's rate
; 0x40eeb0  (Heli)
ECX = 0xa3d - resource[+0x10] ;  EDX = state[+0x84]  (the rotor speed, 4.0 in flight)
pitch = mul(ECX, EDX) + 0xa3d ;  voice[+0x40] = pitch ; FUN_00423af0(handle, pitch, 2)
```

The record fields (`DumpDwords.java 0x4458f8 4`, `0x445be0`, `0x445ec8`, `0x4461b0`): Tank and MSV `+0x244 = 0x4ef` (1263) and `+0x248 = 0x116a` (4458); Jeep `0x1b92` (7058) and `0x3a0c` (14860); the Heli's resource rate `+0x10` is 0. The pitch is a playback rate in the sample's own unit (the files are 11025 Hz): the Tread runs at 0.11 to 0.40 of its recorded speed (a low rumble, faster as the tank speeds up), the Jeep at 0.64 to 1.35, the rotor at 0.24 (stopped) up to 1.19 (flying, 2621 x 5 = 13105).

## Step 4: the volume, and what is not read

The descriptor's flag byte `0x01` leaves the voice on the object-distance stepper `FUN_004082b0` (decompiled): with a source object the volume is the linear falloff `clamp((424 - distance) / 384, 0, 1)` (`0x1a8`, `0x180`: full volume within 40 units, silent from 424), scaled by the master volume `[0x442ec8]`, once per listening view (`+0x38` and `+0x3c`, the two players' views). `FUN_00408450` is the same computation for the looping stepper (flag `0x20`, used by the `Drone` descriptor). For the player's own vehicle the distance to the view is near zero: full volume. `FUN_00407d40` (the per-frame voice manager: it sorts the active voices by volume and gives DirectSound buffers to the loudest, `DAT_0048ca40` of them) was read only for its shape.

**Not traced, so port choices** (marked in `game/engine_loop.gd` and `game/sound_manager.gd`): how the 0-255 volume bytes map onto a mixer level (the port uses `byte / 255`, linear); whether the whole sample loops or the descriptor's `length` field (`0xd55` = 3413, `0xccc`, `0x10a3`) is a loop window (the port loops the whole sample); the pan; the falloff for other vehicles (none exist in level 1); when the Tread starts exactly for a Tank (the port: while the vehicle exists, from its creation).

## Applied in the port

`tools/extract_engine_loops.py` copies `TREAD`, `JEEPIDLE` and `HELI` into the pack and writes `audio/loops.json` (pitches, volumes, the type mapping Tank/Jeep/MSV/Heli = tread, jeep_idle, tread, heli). `game/engine_loop.gd` holds the maths and `SoundManager` runs one looping player for the player's vehicle:

```gdscript
static func pitch_hz(l: Dictionary, speed_units_per_tick: float, rotor: float) -> float:
	if String(l.get("kind", "speed")) == "rotor":
		return float(l["pitch_base"]) + (float(l["pitch_base"]) - float(l.get("resource_rate", 0))) * rotor    # 0x40eeb0
	var lo := float(l["pitch_min"])
	var hi := float(l["pitch_max"])
	return lo + (hi - lo) * absf(speed_units_per_tick)                                                          # 0x40ee60
```
```gdscript
if v.vehicle_type == 3 and v.heli_spinup_stage == 1:
	return ""       # the Heli's voice starts when the blade acceleration ends (0x40e8f5)
...
_loop_player.pitch_scale = maxf(EngineLoop.pitch_scale(l, _vehicle.speed / Vehicle.TICK_HZ, _vehicle.rotor_speed_steps), 0.01)
```

The loop plays while the vehicle exists (alive, not docked in the base). The old one-shot "Heli" cue is no longer played (the loop replaces it). `tools/tests/engine_loop_check.gd` (15 checks): the pitches at rest and at speed for each type, the volume attack and sustain, the loop chosen for each type, silence while the Heli's blades accelerate, docked and destroyed. Runs in the real scene were made with the dummy audio driver, so the sound itself was not listened to.

## Not done / leads

- **`Drone.SDT`** (`0x44b568`, flag `0x21` looping, pitch relative `-1.0`) belongs to something else: `FUN_0040a7b0` spawns objects of a class at `0x443838` (up to a count in `DAT_00457f90`, four view-relative "lanes", a voice at their common position `DAT_00457f70`), and starts the drone voice when the first exists. That is a flying object the port does not have, plausibly the level's `M` count of document 73 ("what it spawns is untraced"). Worth tracing before the AI: it may be an enemy.
- Enemy and other vehicles' engines (the falloff above applies to them), the positional pan, the mixer's volume scale, the `length` loop window.
- The tread's start at creation is inferred from the record field, not from the handler.

**Next:** [the next-steps doc](NEXT_STEPS.md).
