"""List or extract a 3DO disc image's Opera filesystem (issue #95, PORTING_PLAN Phase 7).

The 3DO discs (Return Fire, Return Fire: Maps o' Death) are raw MODE1/2352 images with the 3DO's own
"Opera" filesystem, not ISO 9660. Layout, as verified on both discs on 2026-10-11:

    sector    2352 bytes, 2048 bytes of user data at offset 16
    block 0   volume header: 0x01, sync 5A x5, version, flags, comment[32], label[32], then big-endian
              u32s at 0x48: id, block size (0x800), block count, root dir id, root dir block count,
              root block size, last avatar index, avatars[] (block numbers of the root directory's copies)
    dir block u32 next, prev, flags, first_free, first_entry; then entries from first_entry to first_free:
              u32 flags, id, char type[4], u32 block_size, byte_count, block_count, burst, gap,
              char name[32], u32 last_avatar, u32 avatars[last_avatar + 1]
              flags & 0xff == 7 is a directory; 0x80000000 = last entry in the directory,
              0x40000000 = last entry in this block

Prototype for the importer's GDScript reader (importer/iso9660.gd's sibling). Extraction writes only
where you point it; keep it under the gitignored build/ (the default), never in the repo.

    python tools/rf3do_opera.py <image.bin>                 list every file
    python tools/rf3do_opera.py <image.bin> --extract [dir]  extract (default build/3do/<image name>)
"""
import os
import struct
import sys

SECTOR = 2352
USER_OFFSET = 16
BLOCK = 2048
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class OperaImage:
    def __init__(self, path):
        self.f = open(path, "rb")
        vh = self.block(0)
        if vh[0] != 1 or vh[1:6] != b"\x5a" * 5:
            raise ValueError("%s is not a 3DO Opera volume (block 0 has no 01 5A5A5A5A5A header)" % path)
        self.label = vh[40:72].split(b"\0")[0].decode("latin1")
        _id, self.block_size, self.block_count, _root_id, self.root_blocks = struct.unpack_from(">5I", vh, 0x48)
        self.root = struct.unpack_from(">I", vh, 0x64)[0]   # avatars[0]

    def block(self, n, count=1):
        out = bytearray()
        for i in range(count):
            self.f.seek((n + i) * SECTOR + USER_OFFSET)
            out += self.f.read(BLOCK)
        return bytes(out)

    def walk(self, start=None, nblocks=None, path=""):
        """Yields (path, byte_count, type, first_block) for every file, depth first."""
        start = self.root if start is None else start
        nblocks = self.root_blocks if nblocks is None else nblocks
        for b in range(nblocks):
            d = self.block(start + b)
            first_free, first_entry = struct.unpack_from(">II", d, 12)
            off = first_entry
            while off < min(first_free, BLOCK):
                flags, _id, etype, _bs, nbytes, nblk = struct.unpack_from(">II4sIII", d, off)
                name = d[off + 32:off + 64].split(b"\0")[0].decode("latin1")
                last = struct.unpack_from(">I", d, off + 64)[0]
                avatars = struct.unpack_from(">%dI" % (last + 1), d, off + 68)
                off += 68 + 4 * (last + 1)
                p = path + "/" + name
                if flags & 0xff == 7:
                    yield from self.walk(avatars[0], nblk, p)
                else:
                    yield p, nbytes, etype.decode("latin1"), avatars[0]
                if flags & 0xC0000000:
                    break

    def read(self, first_block, nbytes):
        return self.block(first_block, (nbytes + BLOCK - 1) // BLOCK)[:nbytes]


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    img = OperaImage(argv[0])
    extract = "--extract" in argv
    if extract:
        rest = argv[argv.index("--extract") + 1:]
        out = rest[0] if rest else os.path.join(REPO, "build", "3do", os.path.splitext(os.path.basename(argv[0]))[0])
    total = 0
    files = list(img.walk())
    for p, n, t, first in files:
        total += n
        if extract:
            dst = os.path.join(out, p.lstrip("/"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            with open(dst, "wb") as o:
                o.write(img.read(first, n))
        else:
            print("%10d %-6r %s" % (n, t, p))
    print("%s: label %r, %d files, %d bytes%s" % (argv[0], img.label, len(files), total,
                                                  (" -> " + out) if extract else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
