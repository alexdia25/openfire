"""Reads RFIRE.BIN by virtual address (the same PE section walk extract_music.py does inline): rfexe.dword(va), rfexe.byte(va), rfexe.cstr(va).
RF_GAME_DIR (default C:/Users/Alex/Documents/returnfire) is the game install."""
import os
import struct

GAME_DIR = os.environ.get("RF_GAME_DIR", "C:/Users/Alex/Documents/returnfire")

_exe = open(os.path.join(GAME_DIR, "RFIRE.BIN"), "rb").read()
_pe = struct.unpack_from("<I", _exe, 0x3c)[0]
_nsec = struct.unpack_from("<H", _exe, _pe + 6)[0]
_opt = struct.unpack_from("<H", _exe, _pe + 20)[0]
_base = struct.unpack_from("<I", _exe, _pe + 24 + 28)[0]
_sections = []
for _i in range(_nsec):
    _name, _vsize, _va, _rsize, _roff = struct.unpack_from("<8sIIII", _exe, _pe + 24 + _opt + _i * 40)
    _sections.append((_base + _va, max(_vsize, _rsize), _roff))


def off(va):
    for v, size, roff in _sections:
        if v <= va < v + size:
            return roff + va - v
    raise ValueError(hex(va))


def byte(va):
    return _exe[off(va)]


def dword(va, signed=False):
    return struct.unpack_from("<i" if signed else "<I", _exe, off(va))[0]


def cstr(va):
    o = off(va)
    return _exe[o:_exe.index(b"\0", o)].decode("latin-1")
