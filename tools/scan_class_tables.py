#!/usr/bin/env python3
"""List every object class table in RFIRE.BIN: (class number, name, init, end, tick, draw, first behaviour).

Every live thing in the original is made by FUN_0042c290(class_table, team, x, y, z, extra). A class table
is a block of dwords in the data segment (wiki document 113, Step 2):

    +0x00 class number   +0x04 pointer to the class NAME   +0x08 init   +0x0c end handler   +0x10 per-tick
    +0x14 draw descriptor   +0x1c first behaviour   +0x30 size word   +0x34 blocked-by-tile callback
    +0x38 collided-with-object callback   +0x3c hit callback

The name string makes each table self-describing ("Turret Gun", "Drone", "MAN", "SUB", ...). Classes whose
init/end/tick slots are all empty (the projectile classes) are found by the second, weaker pass.

Reads the original game's RFIRE.BIN and writes nothing; no extracted data is kept. Usage:

    python tools/scan_class_tables.py [path/to/RFIRE.BIN]        (default: $RF_GAME_DIR/RFIRE.BIN)
"""
import os
import struct
import sys


def load_sections(data):
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    opt = pe + 24
    base = struct.unpack_from("<I", data, opt + 28)[0]
    sec = opt + struct.unpack_from("<H", data, pe + 20)[0]
    out = []
    for i in range(nsec):
        o = sec + 40 * i
        name = data[o:o + 8].rstrip(b"\0")
        vsize, va, rsize, rptr = struct.unpack_from("<IIII", data, o + 8)
        out.append((name, base + va, max(vsize, rsize), rptr))
    return out


def scan(data):
    secs = load_sections(data)

    def read(addr, n):
        for _, va, size, rptr in secs:
            if va <= addr < va + size:
                return data[rptr + addr - va: rptr + addr - va + n]
        return None

    def dword(addr):
        raw = read(addr, 4)
        return struct.unpack("<I", raw)[0] if raw and len(raw) == 4 else None

    def cstr(addr):
        raw = read(addr, 24)
        if not raw:
            return None
        text = raw.split(b"\0")[0]
        if len(text) >= 3 and all(32 <= c < 127 for c in text):
            return text.decode("latin1")
        return None

    text_sec = next(s for s in secs if s[0] == b".text")
    data_sec = next(s for s in secs if s[0] == b".data")

    def is_code(value):
        return value is not None and text_sec[1] <= value < text_sec[1] + text_sec[2]

    found = []
    addr = data_sec[1]
    while addr < data_sec[1] + data_sec[2] - 0x40:
        cls, name_ptr = dword(addr), dword(addr + 4)
        if cls is not None and 0 <= cls < 0x20 and name_ptr and cstr(name_ptr):
            slots = [dword(addr + 4 * i) for i in range(2, 8)]
            full = is_code(slots[0]) and is_code(slots[1])
            # the weaker pass: projectile classes have only a draw descriptor and a tick
            weak = is_code(slots[0]) or (is_code(slots[2]) and slots[3])
            if full or (weak and cls in (0, 7, 16, 18)):
                found.append((addr, cls, cstr(name_ptr), slots))
        addr += 4
    return found


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.environ.get("RF_GAME_DIR", "."), "RFIRE.BIN")
    with open(path, "rb") as f:
        data = f.read()
    print("table      class  name                init       end        tick       draw       behaviour")
    for addr, cls, name, s in scan(data):
        def h(v):
            return "-" if not v else "0x%x" % v
        print("0x%06x   %-5d  %-18s  %-9s  %-9s  %-9s  %-9s  %s" % (addr, cls, name, h(s[0]), h(s[1]), h(s[2]), h(s[3]), h(s[5])))


if __name__ == "__main__":
    main()
