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
Usage: python extract_engine_loops.py [pack_dir]      (game install from RF_GAME_DIR, default C:/Users/Alex/Documents/returnfire)
"""
import json
import os
import shutil
import sys

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

loops = {
    "tread": {"wav": "TREAD.wav", "descriptor": "0x44b520", "kind": "speed", "pitch_min": 0x4ef, "pitch_max": 0x116a},
    "jeep_idle": {"wav": "JEEPIDLE.wav", "descriptor": "0x44b538", "kind": "speed", "pitch_min": 0x1b92, "pitch_max": 0x3a0c},
    "heli": {"wav": "HELI.wav", "descriptor": "0x44b550", "kind": "rotor", "pitch_base": 0xa3d, "resource_rate": 0},
}
for l in loops.values():
    l.update({"volume_attack": 210, "volume_sustain": 100, "attack_ticks": 10, "base_rate": 11025})
by_type = ["tread", "jeep_idle", "tread", "heli"]   # Tank, Jeep, MSV, Heli

audio_dir = os.path.join(PACK_DIR, "audio")
os.makedirs(audio_dir, exist_ok=True)
for l in loops.values():
    src = os.path.join(GAME_DIR, "SOUND", l["wav"].replace(".wav", ".SDT"))
    shutil.copyfile(src, os.path.join(audio_dir, l["wav"]))   # an .SDT is a plain RIFF/WAVE file (convert_sdt.py)
with open(os.path.join(audio_dir, "loops.json"), "w") as f:
    json.dump({"_source": "RFIRE.BIN descriptors 0x44b520 / 0x44b538 / 0x44b550, callbacks 0x40ee60 / 0x40eeb0; document 97", "loops": loops, "by_vehicle_type": by_type}, f, indent=2)
print("wrote", sorted(loops), "to", audio_dir)
