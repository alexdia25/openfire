"""Reads every sound descriptor's level, pitch and priority out of RFIRE.BIN into tools/data/sound_cues.json (document 100).

A descriptor is 0x18 bytes (document 82); the sound engine reads it in FUN_00408170 (voice setup) and FUN_00407ec0 (levels):
  +0x08 byte  priority at the start   \\ the voice's PRIORITY (voice +0x1c/+0x20): FUN_00407ba0 sorts the voices by it and gives the top 20 a
  +0x09 byte  priority once faded     /  mixer channel; it is not a volume (document 82 called both "volume"). The first drops to the second after +0x0a ticks.
  +0x0a byte  ticks until the priority drops
  +0x0b byte  flags (bit 0x20: the looping stepper)
  +0x0c dword pitch: 0 = the sample's own rate, > 0 a rate in Hz, < 0 a fraction (16.16) of the sample's rate
  +0x10 dword LEVEL, 16.16 (0x10000 = 1.0): voice +0x44, which FUN_00407ec0 multiplies by the voice's gain (1.0 with no source object) into the channel level;
                the channel volume is then min(level / 3 - 2200, 0) hundredths of a dB (FUN_00407ec0 -> FUN_00423af0 type 1 -> IDirectSoundBuffer::SetVolume)
Usage: python extract_sound_levels.py
"""
import json
import os

import rfexe

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "sound_cues.json")
doc = json.load(open(PATH))
for cue_id, cue in doc["cues"].items():
    a = int(cue["addr"], 16)
    assert rfexe.cstr(rfexe.dword(rfexe.dword(a + 4))).lower().endswith(".sdt"), cue_id   # the resource's own file name: the row really is a descriptor
    cue["level"] = rfexe.dword(a + 0x10)
    cue["pitch"] = rfexe.dword(a + 0xc, signed=True)
    cue["priority"] = {"start": rfexe.byte(a + 8), "later": rfexe.byte(a + 9), "ticks": rfexe.byte(a + 10)}
    cue["flags"] = rfexe.byte(a + 11)
doc["_levels"] = "level / pitch / priority / flags per descriptor from RFIRE.BIN by tools/extract_sound_levels.py (document 100)"
with open(PATH, "w") as f:
    json.dump(doc, f, indent=1)
    f.write("\n")
for cue_id, cue in doc["cues"].items():
    print("%-16s level 0x%04x  %6.1f dB  pitch %d" % (cue_id, cue["level"], min(cue["level"] / 3 - 2200, 0) / 100, cue["pitch"]))
