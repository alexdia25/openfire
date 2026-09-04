"""Phase 1a: convert Return Fire .SDT sound files to .wav.

The .SDT files are already RIFF/WAVE with format tag 0x0001 (uncompressed PCM)
-- they are plain .wav files with a renamed extension. This tool validates that
assumption per file and reports the real format rather than copying blindly, so
any file that is NOT plain PCM gets flagged instead of silently producing a
broken asset.

Usage:
    python convert_sdt.py <returnfire_dir> <out_dir>
"""

import os
import struct
import sys


def parse_riff(data):
    """Return (fmt_dict, has_data_chunk) for a RIFF/WAVE buffer, or raise."""
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("not a RIFF/WAVE file")

    riff_size = struct.unpack_from("<I", data, 4)[0]
    fmt = None
    has_data = False

    pos = 12
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        size = struct.unpack_from("<I", data, pos + 4)[0]
        body = pos + 8

        if tag == b"fmt ":
            (tag_fmt, channels, rate, byte_rate, align, bits) = struct.unpack_from(
                "<HHIIHH", data, body
            )
            fmt = {
                "format_tag": tag_fmt,
                "channels": channels,
                "sample_rate": rate,
                "byte_rate": byte_rate,
                "block_align": align,
                "bits": bits,
                "fmt_chunk_size": size,
            }
        elif tag == b"data":
            has_data = True

        pos = body + size + (size & 1)  # chunks are word-aligned

    if fmt is None:
        raise ValueError("no 'fmt ' chunk")

    fmt["riff_size_ok"] = (riff_size + 8 == len(data))
    return fmt, has_data


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2

    src_root, out_dir = sys.argv[1], sys.argv[2]
    snd_dir = os.path.join(src_root, "SOUND")
    if not os.path.isdir(snd_dir):
        print("error: no SOUND directory under %s" % src_root)
        return 1

    os.makedirs(out_dir, exist_ok=True)

    ok = 0
    flagged = []
    formats = {}

    for name in sorted(os.listdir(snd_dir)):
        if not name.upper().endswith(".SDT"):
            continue
        path = os.path.join(snd_dir, name)
        with open(path, "rb") as f:
            data = f.read()

        try:
            fmt, has_data = parse_riff(data)
        except ValueError as e:
            flagged.append("%s: %s" % (name, e))
            continue

        if fmt["format_tag"] != 1:
            flagged.append(
                "%s: format tag 0x%04X is not PCM -- needs a decoder"
                % (name, fmt["format_tag"])
            )
            continue
        if not has_data:
            flagged.append("%s: no 'data' chunk" % name)
            continue
        if not fmt["riff_size_ok"]:
            flagged.append(
                "%s: RIFF size field disagrees with file length (copied anyway)" % name
            )

        key = (fmt["sample_rate"], fmt["channels"], fmt["bits"])
        formats[key] = formats.get(key, 0) + 1

        out_name = os.path.splitext(name)[0] + ".wav"
        with open(os.path.join(out_dir, out_name), "wb") as f:
            f.write(data)
        ok += 1

    print("converted %d .SDT -> .wav in %s" % (ok, out_dir))
    print("formats seen (rate, channels, bits) -> count:")
    for key in sorted(formats):
        print("   %6d Hz  %dch  %2d-bit  x%d" % (key[0], key[1], key[2], formats[key]))

    if flagged:
        print("\nFLAGGED (%d):" % len(flagged))
        for line in flagged:
            print("   " + line)
    else:
        print("\nno anomalies -- every file was plain PCM")

    return 0


if __name__ == "__main__":
    sys.exit(main())
