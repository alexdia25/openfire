"""Extracts the vehicles' continuous engine sounds (document 97) into the pack: the wavs and audio/loops.json.

Traced from RFIRE.BIN (document 97; DumpDwords.java on the sound descriptors at 0x44b520 and the vehicle records at 0x4456b8 + type * 0x2e8):
  descriptors (0x18 bytes: label, resource, fade-in volume, sustain volume, fade ticks, flags, pitch, length, callback):
    0x44b520 Tread.SDT    volume 210 -> 100 over 10 ticks, callback 0x40ee60   (Tank and MSV: record +0x240)
    0x44b538 JeepIdle.SDT volume 210 -> 100 over 10 ticks, callback 0x40ee60   (started by the Jeep's state handler at 0x40d940)
    0x44b550 Heli.SDT     volume 210 -> 100 over 10 ticks, callback 0x40eeb0   (started by the rotor start-up, 0x40e8f5)
  callback 0x40ee60: pitch = record[+0x244] + ((record[+0x248] - record[+0x244]) * |speed| >> 16), applied with FUN_00423af0
  callback 0x40eeb0: pitch = 0xa3d + (0xa3d - resource[+0x10]) * rotor speed (state +0x84) >> 16
  records: Tank and MSV +0x244 = 0x4ef, +0x248 = 0x116a; Jeep 0x1b92, 0x3a0c
Sample rate of every .SDT is 11025 Hz (8-bit mono); the pitch values are in the same unit as a rate.
Writes tools/data/engine_loops.json; tools/build_pack.py folds each vehicle's loop into its definition
(vehicles/<id>/vehicle.json "sounds.engine_loop", PORTING_PLAN.md 2.7.2) and copies the three samples from build/sound.
The Heli's loop is also the sound cue "Heli" (0x44b550), so its entry names that cue: SoundManager never replays a
vehicle's own engine loop as a one-shot.
Usage: python extract_engine_loops.py
"""
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "engine_loops.json")

loops = {
    "tread": {"wav": "TREAD.wav", "descriptor": "0x44b520", "kind": "speed", "pitch_min": 0x4ef, "pitch_max": 0x116a},
    "jeep_idle": {"wav": "JEEPIDLE.wav", "descriptor": "0x44b538", "kind": "speed", "pitch_min": 0x1b92, "pitch_max": 0x3a0c},
    "heli": {"wav": "HELI.wav", "descriptor": "0x44b550", "cue": "Heli", "kind": "rotor", "pitch_base": 0xa3d, "resource_rate": 0},
}
for l in loops.values():
    l.update({"volume_attack": 210, "volume_sustain": 100, "attack_ticks": 10, "base_rate": 11025})
by_type = ["tread", "jeep_idle", "tread", "heli"]   # Tank, Jeep, MSV, Heli

with open(OUT, "w") as f:
    json.dump({"_source": "RFIRE.BIN descriptors 0x44b520 / 0x44b538 / 0x44b550, callbacks 0x40ee60 / 0x40eeb0; document 97",
               "loops": loops, "by_vehicle_type": by_type}, f, indent=1)
    f.write("\n")
print("wrote", sorted(loops), "to", OUT)
