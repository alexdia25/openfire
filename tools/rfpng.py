"""Minimal dependency-free PNG writer (RGBA8) and BMP reader.

Stdlib only (zlib, struct). Shared by the Return Fire asset converters so the
pipeline has no third-party dependencies.
"""

import struct
import zlib


def write_png_rgba(path, width, height, pixels):
    """Write RGBA8 pixel data (bytes-like, len == width*height*4) as a PNG."""
    if len(pixels) != width * height * 4:
        raise ValueError(
            "pixel buffer is %d bytes, expected %d" % (len(pixels), width * height * 4)
        )

    stride = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0 (None)
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    out = bytearray(b"\x89PNG\r\n\x1a\n")
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    out += chunk(b"IEND", b"")

    with open(path, "wb") as f:
        f.write(out)


class BmpError(Exception):
    pass


def read_bmp(data):
    """Decode a Windows BMP (4bpp or 8bpp, uncompressed).

    Returns (width, height, indices, palette) where `indices` is a bytearray of
    width*height palette indices in TOP-DOWN row order, and `palette` is a list
    of (r, g, b) tuples.

    Notes on this game's files: the pixel offset must be read from bfOffBits at
    offset 10 -- palettes are not always 256 entries (NEWREQLG.RFA has 224,
    PAUSE16.RFA has 16), so a hardcoded 1078-byte offset would be wrong.
    """
    if data[:2] != b"BM":
        raise BmpError("not a BMP (missing 'BM' magic)")

    pix_off = struct.unpack_from("<I", data, 10)[0]
    hdr_size = struct.unpack_from("<I", data, 14)[0]
    if hdr_size < 40:
        raise BmpError("unsupported DIB header size %d" % hdr_size)

    width, height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    compression = struct.unpack_from("<I", data, 30)[0]

    if compression != 0:
        raise BmpError("compressed BMP (compression=%d) not supported" % compression)
    if bpp not in (4, 8):
        raise BmpError("unsupported bit depth %d" % bpp)

    bottom_up = height > 0
    height = abs(height)

    pal_off = 14 + hdr_size
    pal_count = (pix_off - pal_off) // 4
    palette = []
    for i in range(pal_count):
        b, g, r = data[pal_off + i * 4:pal_off + i * 4 + 3]
        palette.append((r, g, b))

    # BMP rows are padded to a 4-byte boundary.
    row_bits = width * bpp
    row_bytes = ((row_bits + 31) // 32) * 4

    indices = bytearray(width * height)
    for y in range(height):
        src_y = (height - 1 - y) if bottom_up else y
        row = data[pix_off + src_y * row_bytes:pix_off + src_y * row_bytes + row_bytes]
        dst = y * width
        if bpp == 8:
            indices[dst:dst + width] = row[:width]
        else:  # 4bpp, high nibble first
            for x in range(width):
                byte = row[x >> 1]
                indices[dst + x] = (byte >> 4) if (x & 1) == 0 else (byte & 0x0F)

    return width, height, indices, palette


def indices_to_rgba(indices, palette, transparent_index=None):
    """Expand palette indices to an RGBA8 buffer."""
    lut = bytearray(256 * 4)
    for i in range(256):
        if i < len(palette):
            r, g, b = palette[i]
        else:
            r = g = b = 0
        a = 0 if (transparent_index is not None and i == transparent_index) else 255
        lut[i * 4:i * 4 + 4] = bytes((r, g, b, a))

    out = bytearray(len(indices) * 4)
    for n, idx in enumerate(indices):
        out[n * 4:n * 4 + 4] = lut[idx * 4:idx * 4 + 4]
    return out
