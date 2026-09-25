"""Extracts the four victory jingles (TITLE\\WIN1.STM, WIN2.STM, WIN3.STM, WIN.STM on the CD image) into the pack's music/ folder (document 101).

The .STM files are an AVI-derived stream container (document 101): a 0x1000-byte header (the name "winN.avi Audio #1", a WAVEFORMATEX at +0x98: PCM, 2 channels, 22050 Hz, 16 bits;
the total number of audio frames at +0x2c), then 0x10000-byte blocks. Each block starts with a 0x20-byte header whose dwords at +8 and +12 are the byte offset of the block's audio
inside the block and its length in 4-byte frames; the rest of the block is a Cinepak video stream (the win sequence only blits the ribbon bitmap and pumps the stream; whether it draws the video is untraced). The audio of all blocks in order is the sound.
Which file the game plays is read from RFIRE.BIN: the level's LEVL (0-8) picks a tier through the byte table at 0x44e120, the tier a file name through the pointer table at 0x44e110
(FUN_00430620, FUN_00430b10).
Needs the ISO (RF_ISO, default RF_GAME_DIR/"RFIRE US.iso") and ffmpeg with libvorbis. Writes packs/original_pc/music/win_<tier>.ogg and jingles.json.
Usage: python extract_win_jingles.py [pack dir]
"""
import json
import mmap
import os
import struct
import subprocess
import sys

import rfexe

GAME_DIR = rfexe.GAME_DIR
ISO = os.environ.get("RF_ISO", os.path.join(GAME_DIR, "RFIRE US.iso"))
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

tier_files = [rfexe.cstr(rfexe.dword(0x44e110 + 4 * t)) for t in range(4)]      # e.g. "TITLE\\Win1.stm"
by_levl = [rfexe.dword(0x44e120 + 4 * i) for i in range(10)]

iso = open(ISO, "rb")
blob = mmap.mmap(iso.fileno(), 0, access=mmap.ACCESS_READ)


def read_iso_file(name):
    i = blob.find(name.upper().encode() + b";1")
    assert i > 0, name
    rec = i - 33
    lba = struct.unpack_from("<I", blob, rec + 2)[0]
    size = struct.unpack_from("<I", blob, rec + 10)[0]
    return blob[lba * 2048: lba * 2048 + size]


def audio_of(stm):
    assert stm[12:16] == b"auds", "not a stream header"
    fmt, channels, rate, _avg, _align, bits = struct.unpack_from("<HHIIHH", stm, 0x98)
    assert (fmt, channels, rate, bits) == (1, 2, 22050, 16), (fmt, channels, rate, bits)
    total_frames = struct.unpack_from("<I", stm, 0x2c)[0]
    parts = []
    for b in range((len(stm) - 0x1000) // 0x10000):
        o = 0x1000 + b * 0x10000
        off, frames = struct.unpack_from("<II", stm, o + 8)
        assert off + frames * 4 <= 0x10000
        parts.append(stm[o + off: o + off + frames * 4])
    pcm = b"".join(parts)
    assert len(pcm) == total_frames * 4, (len(pcm), total_frames)
    return pcm


out_dir = os.path.join(PACK_DIR, "music")
os.makedirs(out_dir, exist_ok=True)
tiers = []
for t, path in enumerate(tier_files):
    pcm = audio_of(read_iso_file(path.split("\\")[-1]))
    name = "win_%d.ogg" % t
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "22050", "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", os.path.join(out_dir, name)], input=pcm, check=True)
    tiers.append({"file": name, "source": path, "seconds": round(len(pcm) / 4 / 22050.0, 2)})
    print(t, path, tiers[-1]["seconds"], "s")
with open(os.path.join(out_dir, "jingles.json"), "w") as f:
    json.dump({"_source": "RFIRE.BIN tables 0x44e110 / 0x44e120 and the TITLE\\WIN*.STM streams on the CD image; document 101", "tiers": tiers, "tier_by_levl": by_levl}, f, indent=1)
    f.write("\n")
