"""Extracts the game's music (document 98) from the CD image into the pack: music/track_NN.ogg and music/music.json.

The game's music is one long 44.1 kHz stereo WAV, `SOUND/Score.WAV` (a copy of the CD's audio tracks; the install's copy is a 20-byte stub, the real one is on the CD image),
cut into 24 tracks by the offset table at 0x449470 of RFIRE.BIN (file offsets into the sample data). The "music lines" (document 71 read them as announcer voice lines) are the
18 entries of 0x2c bytes at 0x4463b8: {id, lowest, highest, enabled, name ptr, transition byte, transition-list ptr, flags, start / alternate-start / end track, ...}.
A line plays the tracks from `start` up to (not including) `end`; a looping line then restarts at `alt`; a sting (flags bit 1) plays once.
Reads RFIRE.BIN and the ISO from RF_GAME_DIR (default C:/Users/Alex/Documents/returnfire): "RFIRE.BIN" and "RFIRE US.iso" (override the image with RF_ISO). Needs ffmpeg with libvorbis.
Usage: python extract_music.py [pack_dir]
"""
import json
import os
import struct
import subprocess
import sys

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")
ISO = os.environ.get("RF_ISO", os.path.join(GAME_DIR, "RFIRE US.iso"))
PACK_DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "packs", "original_pc")

exe = open(os.path.join(GAME_DIR, "RFIRE.BIN"), "rb").read()
pe = struct.unpack_from("<I", exe, 0x3c)[0]
nsec = struct.unpack_from("<H", exe, pe + 6)[0]
opt = struct.unpack_from("<H", exe, pe + 20)[0]
image_base = struct.unpack_from("<I", exe, pe + 24 + 28)[0]
sections = []
for i in range(nsec):
    _name, vsize, va, rsize, roff = struct.unpack_from("<8sIIII", exe, pe + 24 + opt + i * 40)
    sections.append((image_base + va, max(vsize, rsize), roff))


def off(va):
    for v, size, roff in sections:
        if v <= va < v + size:
            return roff + va - v
    raise ValueError(hex(va))


def cstr(va):
    o = off(va)
    return exe[o:exe.index(b"\0", o)].decode("latin-1")


table = list(struct.unpack_from("<30I", exe, off(0x449470)))   # track n starts at table[n]; the sample data is 44 bytes into the file
lines = []
for i in range(18):
    b = off(0x4463b8 + i * 0x2c)
    line_id, lo, hi, enabled = struct.unpack_from("<BbbB", exe, b)
    name_ptr, trans_byte, list_ptr, flags, start, alt, end = struct.unpack_from("<I", exe, b + 4)[0], exe[b + 9], struct.unpack_from("<I", exe, b + 0x10)[0], struct.unpack_from("<I", exe, b + 0x14)[0], *struct.unpack_from("<iii", exe, b + 0x18)
    trans = []
    if list_ptr:
        o = off(list_ptr)
        while exe[o] < 0x80:
            trans.append({"from_line": exe[o], "type": exe[o + 1]})
            o += 8
    lines.append({"id": line_id, "name": cstr(name_ptr), "lowest": lo, "highest": hi, "enabled_bit0": enabled & 1, "default_transition": trans_byte, "transitions": trans,
                  "sting": bool(flags & 2), "flags": flags, "start_track": -start, "alt_track": -alt, "end_track": -end})

# the ISO9660 record of SCORE.WAV
iso = open(ISO, "rb")
blob = iso.read()
i = blob.find(b"SCORE.WAV;1")
rec = i - 33
lba = struct.unpack_from("<I", blob, rec + 2)[0]
size = struct.unpack_from("<I", blob, rec + 10)[0]
wav = blob[lba * 2048: lba * 2048 + size]
del blob
assert wav[:4] == b"RIFF" and wav[8:16] == b"WAVEfmt ", "not the music WAV"
pcm = wav[44:]

out_dir = os.path.join(PACK_DIR, "music")
os.makedirs(out_dir, exist_ok=True)
tracks = []
for n in range(1, 25):
    a, z = table[n], table[n + 1]
    seg = pcm[a:z]
    path = os.path.join(out_dir, "track_%02d.ogg" % n)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "44100", "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", path], input=seg, check=True)
    tracks.append({"n": n, "file": "track_%02d.ogg" % n, "start_byte": a, "end_byte": z, "seconds": round((z - a) / 176400.0, 2)})
    print("track", n, tracks[-1]["seconds"], "s")
with open(os.path.join(out_dir, "music.json"), "w") as f:
    json.dump({"_source": "RFIRE.BIN offset table 0x449470 and music line table 0x4463b8; SOUND/Score.WAV on the CD image; document 98", "tracks": tracks, "lines": lines}, f, indent=1)
print("wrote", len(tracks), "tracks and", len(lines), "lines to", out_dir)
