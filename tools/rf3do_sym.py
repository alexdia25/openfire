"""List the global and static variables in the 3DO version's rfire.sym (issue #94, partial; document 132).

rfire.sym is a big-endian ARM symbolic debug table. Each record is u16 length (bytes, header included), u16 code.
Only code 4 (a variable) is decoded here, with the layout read off the file rather than from ARM's documentation:

    +0x00  u16 length, u16 code (4)
    +0x04  u32 type
    +0x08  u32 source position
    +0x0c  u32 storage class: 1 for the globals checked so far, 2 for file statics (assumed from the names)
    +0x10  u32 location: the offset in the `rfire` executable, whose load base is 0 (checked: the DebugFontName
                         and SmallDebugFontName strings sit at exactly their symbols' locations)
    +0x14  u8 name length, then the name

Each module repeats the variables it declares, so the list is de-duplicated. Procedures, types and structs (the
other codes) are not decoded yet.

    python tools/rf3do_sym.py <rfire.sym>                 every variable, by location
    python tools/rf3do_sym.py <rfire.sym> --grep Debug    those whose name contains "Debug"
    python tools/rf3do_sym.py <rfire.sym> --near 0x386e4  the variables within 0x40 bytes of a location
"""
import struct
import sys


def variables(data):
    seen = set()
    o = 0
    while o + 4 <= len(data):
        length, code = struct.unpack_from(">HH", data, o)
        if length == 0:
            o += 4
            continue
        if code == 4 and length >= 21:
            _type, _pos, storage, location = struct.unpack_from(">IIII", data, o + 4)
            n = data[o + 20]
            name = data[o + 21:o + 21 + n].decode("latin-1")
            seen.add((location, storage, name))
        o += length
    return sorted(seen)


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    with open(argv[0], "rb") as f:
        found = variables(f.read())
    if "--grep" in argv:
        needle = argv[argv.index("--grep") + 1].lower()
        found = [v for v in found if needle in v[2].lower()]
    if "--near" in argv:
        at = int(argv[argv.index("--near") + 1], 0)
        found = [v for v in found if abs(v[0] - at) <= 0x40]
    for location, storage, name in found:
        print("%08x  %d  %s" % (location, storage, name))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
