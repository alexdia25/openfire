"""Extracts the four victory jingles' audio AND video (TITLE\\WIN1.STM, WIN2.STM, WIN3.STM, WIN.STM on the CD image) into the pack's music/ folder (document 101, and
its addendum on issue #60: the original genuinely decodes and displays the video behind the ribbon, confirmed by a real ICSendMessage decompress-call chain in RFIRE.BIN).

The .STM files are an AVI-derived stream container: a 0x1000-byte header (an `auds` stream header with a WAVEFORMATEX at +0x98: PCM, 2 channels, 22050 Hz, 16 bits, and the
total audio frame count at +0x2c; a `vids`/`cvid` stream header giving 320x240 and a nominal frame count/rate), then 0x10000-byte blocks. Each block starts with a 0x20-byte
header whose dwords at +8 and +12 are the byte offset of the block's audio inside the block and its length in 4-byte frames; everything else in the block (always *before*
the audio -- verified across every block of every tier that video_bytes + audio_bytes == exactly 0x10000, with 0-2 bytes of trailing pad) is one or more Cinepak-compressed
video chunks. Each chunk is a standard 10-byte Cinepak frame header (flags:u8, size:u24be [includes this header], width:u16be, height:u16be, numStrips:u16be) followed by
`size - 10` bytes of compressed data; found by scanning for the frame's own width/height bytes (320x240 for every chunk in every tier) rather than computing a fixed offset,
since chunks are preceded by a small (8 or 10 byte) per-chunk record whose own meaning was not fully pinned down (its last 2 bytes are a simple sequential chunk counter,
confirmed gapless 0..N-1 for every tier -- a good validity check, but not needed for extraction). The real chunk count found this way is consistently a little below the
stream header's own nominal frame count (e.g. 160 real chunks vs a nominal 177 for WIN1.STM's 11.8 s at its declared 15 fps): playback timing is therefore derived from
the chunks actually found, spread evenly across the audio's own known duration, not from the header's nominal rate.
Which file the game plays is read from RFIRE.BIN: the level's LEVL (0-8) picks a tier through the byte table at 0x44e120, the tier a file name through the pointer table at 0x44e110
(FUN_00430620, FUN_00430b10).
Needs the ISO (RF_ISO, default RF_GAME_DIR/"RFIRE US.iso") and ffmpeg with libvorbis. Writes packs/original_pc/music/win_<tier>.ogg, win_<tier>.cvid (the raw, concatenated
Cinepak elementary stream, decoded live by game/cinepak_decoder.gd -- this format is a real engine capability, not a one-off transcode) and jingles.json.
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


CINEPAK_SIG = bytes([0x01, 0x40, 0x00, 0xF0])  # width=320, height=240, big-endian: every chunk in every tier uses this


def video_of(stm):
    """The raw, concatenated Cinepak elementary stream (just the 10-byte-headered chunks, container framing stripped),
    in decode order. Each block's video region is everything before its own audio (see module docstring)."""
    vids = stm.find(b"vids")
    assert vids > 0 and stm[vids + 4:vids + 8] == b"cvid", "not a Cinepak video stream"
    chunks = []
    for b in range((len(stm) - 0x1000) // 0x10000):
        o = 0x1000 + b * 0x10000
        aoff, _aframes = struct.unpack_from("<II", stm, o + 8)
        region = stm[o + 32: o + aoff]
        start = 0
        while True:
            i = region.find(CINEPAK_SIG, start)
            if i < 0:
                break
            hstart = i - 4
            size = int.from_bytes(region[hstart + 1:hstart + 4], "big")
            assert size >= 10, size
            chunks.append(region[hstart:hstart + size])
            start = hstart + size
    return chunks


out_dir = os.path.join(PACK_DIR, "music")
os.makedirs(out_dir, exist_ok=True)
tiers = []
for t, path in enumerate(tier_files):
    stm = read_iso_file(path.split("\\")[-1])
    pcm = audio_of(stm)
    name = "win_%d.ogg" % t
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", "22050", "-ac", "2", "-i", "-", "-c:a", "libvorbis", "-q:a", "4", os.path.join(out_dir, name)], input=pcm, check=True)
    seconds = round(len(pcm) / 4 / 22050.0, 2)

    chunks = video_of(stm)
    video_name = "win_%d.cvid" % t
    with open(os.path.join(out_dir, video_name), "wb") as vf:
        for c in chunks:
            vf.write(c)
    frame_lengths = [len(c) for c in chunks]

    tiers.append({"file": name, "source": path, "seconds": seconds,
                  "video_file": video_name, "video_width": 320, "video_height": 240, "video_frame_lengths": frame_lengths})
    print(t, path, seconds, "s,", len(chunks), "video chunks")
with open(os.path.join(out_dir, "jingles.json"), "w") as f:
    json.dump({"_source": "RFIRE.BIN tables 0x44e110 / 0x44e120 and the TITLE\\WIN*.STM streams on the CD image; document 101, video addendum for issue #60",
               "tiers": tiers, "tier_by_levl": by_levl}, f, indent=1)
    f.write("\n")
