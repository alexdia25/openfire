"""Phase 1d: convert Return Fire .RFM level files to tilemap + level JSON.

.RFM is a named-chunk container, NOT a fixed-size header. Reverse engineered from the
real loader in RFIRE.BIN via Ghidra (see docs/PORTING_PLAN.md section 1.5 for the full
writeup and how each field below was confirmed).

Container layout:
    0x00        "WRL\0"     4-byte magic
    0x04-0x3F   ...         header fields (see docs/PORTING_PLAN.md section 1.5 for how
                             each was found and verified against all 204 real files):
        0x04  4 bytes  constant "TM\0\x05" -- probable format/version tag, unconfirmed
        0x08  u16 LE  width
        0x0A  u16 LE  height
        0x0C  2 bytes  constant 01 01 -- meaning unconfirmed
        0x0E  u16 LE  MS-DOS packed date -- file created
        0x10  u16 LE  MS-DOS packed time -- file created
        0x12  u16 LE  MS-DOS packed date -- file last modified
        0x14  u16 LE  MS-DOS packed time -- file last modified
        0x16  u8      mode/player-count selector byte
        0x17  15 bytes  null-padded ASCII level author/designer name, default "Unknown"
        0x26  26 bytes  constant zero (padding)
    0x40        u8          must be non-zero, or the loader rejects the file
    0x44        u32 LE      byte length of the tile-grid region (== width*height)
    0x48        u32 LE      byte offset from file start to where the chunk table ends
                             AND the tile grid begins
    0x50 ..     chunk table: [tag(4)][total_record_len(4)][payload...], repeating.
      (0x48 val)-1  Walk it by adding each record's length to reach the next one.
    (0x48 val)  tile grid, width*height bytes, one byte per tile, row-major
      .. EOF

Confirmed chunk tags:
    NAME  payload = null-terminated display name string
    LEVL  payload byte 0 = stored value+1 (so decoded = byte-1), clamped 0-8 by the
          loader if the decoded value is out of range. Meaning beyond "some per-level
          knob" (difficulty?) is not confirmed.
    VHCL  payload bytes 0-5 = vehicle/level tuning parameters: A(rmor), H(ealth),
          J(eep?), T(eam?), an unnamed 5th byte, M(ission?). Sentinel 0xFF = "not set".
          The SAME six parameters can be written directly into the .rfm FILENAME as a
          bracket suffix the loader also parses, e.g. "SomeLevel[A3H5T2].rfm" -- letters
          are case-insensitive, digits immediately follow. When both are present the
          VHCL chunk wins per-field (only overrides a field the filename left at 0xFF).
          Hardcoded fallback defaults below that: A=3 H=3 T=3 J=8 (M and the 5th byte
          default to 0xFF, meaning "unset", except M becomes 0 instead of 0xFF when the
          header's mode byte at 0x16 == 2).

Four tile VALUES are not terrain -- they are spawn points and building/target placement
candidates, resolved by RFIRE.BIN through a lookup table that is NOT present in the .rfm
file itself (so this converter hardcodes them; see section 1.5 for how they were found
and cross-validated against all 204 real files):
    0x39  player 1 spawn point   (present exactly once in every file seen so far)
    0x4D  player 2 spawn point   (present 0 or 1 times; only in 2-player levels)
    0xB4  building/target candidate, pool A (only in 2-player levels; 0-56 per file)
    0xDC  building/target candidate, pool B (every file; 1-160 per file)
The real engine picks exactly one candidate from each non-empty pool at random per
match. This converter extracts all candidates rather than picking one -- pick-one-at-
random is gameplay behaviour that belongs in the engine/sim, not baked into the
converted asset.

Every raw tile byte (0-239) resolves to a final rendered "art id" through a second,
fully static lookup -- see tools/rf_tile_art.py for the two-table pipeline (reverse
engineered from FUN_00414130 and FUN_0042e4f0) and docs/PORTING_PLAN.md section 1.5.
Notably this is NOT a runtime autotiling algorithm -- there is no neighbor scanning at
load time -- the level editor already baked the correct coastline-edge art id into the
raw byte when the file was saved. Cross-checked against all 204 real files: zero cells
fail to resolve to an art id, and the 104 art ids the lookup predicts are exactly the
104 actually used.

Output per level: <name>.json (metadata + entities -- including "decorations", every
tile's nonzero coastal-blend id, document 35's second use for that id; see
tools/build_pack.py for how that becomes real placed objects), <name>.tiles.bin (raw
width*height tile bytes, entity-tile cells zeroed to a neutral 0 -- the true default
terrain under a spawn/candidate marker is not recoverable from the file), and
<name>.art.bin (the same grid run through raw_tile_to_art_id -- this is what Phase 3/4
rendering should consume, not the raw bytes). A debug PNG is also written, colour-coded
by art id, so the grid and extracted entities can be checked visually rather than
trusted from statistics alone.

Usage:
    python convert_rfm.py <returnfire_dir> <out_dir> [--limit N]
"""

import json
import os
import struct
import sys

from rfpng import write_png_rgba
from rf_tile_art import raw_tile_to_art_id, raw_tile_to_coastal_id

MAGIC = b"WRL\x00"
CHUNK_TABLE_START = 0x50

TAG_NAME = b"NAME"
TAG_LEVL = b"LEVL"
TAG_VHCL = b"VHCL"

TILE_SPAWN_P1 = 0x39
TILE_SPAWN_P2 = 0x4D
TILE_CANDIDATE_A = 0xB4
TILE_CANDIDATE_B = 0xDC
SPECIAL_TILES = {TILE_SPAWN_P1, TILE_SPAWN_P2, TILE_CANDIDATE_A, TILE_CANDIDATE_B}

VHCL_DEFAULTS = {"A": 3, "H": 3, "J": 8, "T": 3, "unk4": 0xFF, "M": 0xFF}
VHCL_FIELD_ORDER = ["A", "H", "J", "T", "unk4", "M"]  # payload byte 0..5

AUTHOR_OFFSET = 0x17
AUTHOR_LEN = 15


class RfmError(Exception):
    pass


def decode_dos_datetime(date_u16, time_u16):
    """Classic MS-DOS packed date/time (the format _dos_getftime and Win32's
    FAT-era APIs use): date = yyyyyyymmmmddddd, time = hhhhhmmmmmmsssss (seconds
    in 2-second units). Returns an ISO-ish string; callers treat this as display
    data only, not something to do arithmetic on."""
    year = 1980 + (date_u16 >> 9)
    month = (date_u16 >> 5) & 0xF
    day = date_u16 & 0x1F
    hour = (time_u16 >> 11) & 0x1F
    minute = (time_u16 >> 5) & 0x3F
    second = (time_u16 & 0x1F) * 2
    return "%04d-%02d-%02d %02d:%02d:%02d" % (year, month, day, hour, minute, second)


def parse_bracket_params(filename):
    """Parse an [A3H5T2]-style parameter suffix out of a level filename.

    Mirrors FUN_00413f00's filename scan: find '[', then repeatedly match an
    alphabetic letter followed by one or more digits, applying range checks per
    letter. Returns a dict with only the letters that were actually found (and
    passed their range check) -- caller layers this under defaults.
    """
    start = filename.find("[")
    if start < 0:
        return {}
    out = {}
    i = start + 1
    n = len(filename)
    while i < n and filename[i] not in "]":
        ch = filename[i]
        if ch.isalpha():
            j = i + 1
            digits = ""
            while j < n and filename[j].isdigit():
                digits += filename[j]
                j += 1
            if digits:
                val = int(digits)
                letter = ch.upper()
                ok = False
                if letter == "A" and val < 10:
                    out["A"] = val; ok = True
                elif letter == "H" and val < 10:
                    out["H"] = val; ok = True
                elif letter == "J" and 0 < val < 10:
                    out["J"] = val; ok = True
                elif letter == "M" and val < 0xC9:
                    out["M"] = val; ok = True
                elif letter == "T" and val < 10:
                    out["T"] = val; ok = True
                i = j
                continue
        i += 1
    return out


def resolve_vhcl(filename, vhcl_payload, mode_byte):
    """Layer defaults -> filename brackets -> VHCL chunk, matching FUN_00413f00."""
    values = dict(VHCL_DEFAULTS)
    sources = {k: "default" for k in values}

    from_name = parse_bracket_params(filename)
    for k, v in from_name.items():
        values[k] = v
        sources[k] = "filename"

    if vhcl_payload is not None:
        for idx, field in enumerate(VHCL_FIELD_ORDER):
            if idx < len(vhcl_payload) and vhcl_payload[idx] != 0xFF:
                values[field] = vhcl_payload[idx]
                sources[field] = "chunk"

    if values["M"] == 0xFF and mode_byte == 2:
        values["M"] = 0
        sources["M"] = "mode2_default"

    return values, sources


def parse_chunks(data, chunk_table_end):
    """Walk the chunk table at 0x50..chunk_table_end. Returns list of
    (tag_bytes, record_start, record_len, payload_bytes)."""
    chunks = []
    pos = CHUNK_TABLE_START
    guard = 0
    while pos < chunk_table_end:
        guard += 1
        if guard > 10000:
            raise RfmError("chunk table walk exceeded 10000 records -- corrupt length?")
        if pos + 8 > len(data):
            raise RfmError("chunk record header runs past end of file at 0x%X" % pos)
        tag = data[pos:pos + 4]
        reclen = struct.unpack_from("<I", data, pos + 4)[0]
        if reclen < 8 or pos + reclen > len(data):
            raise RfmError("bad chunk record length %d at 0x%X" % (reclen, pos))
        payload = data[pos + 8:pos + reclen]
        chunks.append((tag, pos, reclen, payload))
        pos += reclen
    return chunks


def parse_rfm(path, filename):
    with open(path, "rb") as f:
        data = f.read()

    if data[:4] != MAGIC:
        raise RfmError("bad magic %r" % data[:4])

    width, height = struct.unpack_from("<HH", data, 0x08)
    mode_byte = data[0x16]
    enabled = data[0x40] != 0
    created = decode_dos_datetime(*struct.unpack_from("<HH", data, 0x0E))
    modified = decode_dos_datetime(*struct.unpack_from("<HH", data, 0x12))
    author_raw = data[AUTHOR_OFFSET:AUTHOR_OFFSET + AUTHOR_LEN]
    nul = author_raw.find(b"\x00")
    author = (author_raw[:nul] if nul >= 0 else author_raw).decode("cp1252", "replace")
    grid_size = struct.unpack_from("<I", data, 0x44)[0]
    chunk_table_end = struct.unpack_from("<I", data, 0x48)[0]

    if chunk_table_end + grid_size != len(data):
        raise RfmError(
            "size check failed: chunk_table_end(%d) + grid_size(%d) != filesize(%d)"
            % (chunk_table_end, grid_size, len(data))
        )
    if grid_size != width * height:
        raise RfmError(
            "grid_size(%d) != width*height(%d*%d=%d)" % (grid_size, width, height, width * height)
        )
    if not enabled:
        raise RfmError("'enabled' byte at 0x40 is zero -- file marked invalid by its own header")

    chunks = parse_chunks(data, chunk_table_end)

    name = None
    levl_raw = None
    vhcl_payload = None
    chunk_tags_seen = []
    unrecognized_chunks = {}  # tag -> hex payload, for tags we don't decode (e.g. EDTN)
    known_tags = (TAG_NAME, TAG_LEVL, TAG_VHCL)
    for tag, rec_start, rec_len, payload in chunks:
        tag_str = tag.decode("ascii", "replace")
        chunk_tags_seen.append(tag_str)
        if tag == TAG_NAME and name is None:
            nul = payload.find(b"\x00")
            raw = payload[:nul] if nul >= 0 else payload
            name = raw.decode("cp1252", "replace")
        elif tag == TAG_LEVL and levl_raw is None:
            if payload:
                levl_raw = payload[0]
        elif tag == TAG_VHCL and vhcl_payload is None:
            vhcl_payload = payload
        elif tag not in known_tags:
            # Round-trip anything we don't decode (e.g. EDTN) rather than dropping it,
            # so no information is silently lost even though we don't understand it yet.
            unrecognized_chunks[tag_str] = payload.hex()

    vhcl_values, vhcl_sources = resolve_vhcl(filename, vhcl_payload, mode_byte)

    grid = bytearray(data[chunk_table_end:chunk_table_end + grid_size])

    # Resolve the real rendered art id per cell BEFORE zeroing entity tiles below --
    # spawn/candidate raw values still carry a real "ground" art id (the dispatch
    # call that registers them only records a position, it never touches the tile's
    # stored art bits), so this is not lossy the way the raw grid's zeroing is.
    art_grid = bytearray(raw_tile_to_art_id(val) or 0 for val in grid)

    # Document 35 (docs/process/): a tile's coastal-blend id doubles as a decoration-spawn
    # id -- resolving one was always understood to pick a blended ground texture; the same
    # id, via a separate lookup this converter doesn't do (tools/data/coastal_decorations.json,
    # Ghidra-extracted, consumed by tools/build_pack.py), can also place a real object.
    # Recorded here purely as "this tile's coastal id, if any" -- every nonzero id is kept,
    # same "extract everything, let the pack decide what's known" choice already made for
    # art ids; the pack/engine side is what decides whether a given id actually resolves to
    # a decoration (most coastal ids do; a handful don't, or aren't extracted yet).
    decorations = []
    for idx, val in enumerate(grid):
        coastal_id = raw_tile_to_coastal_id(val)
        if coastal_id:
            decorations.append({"x": idx % width, "y": idx // width, "coastal_id": coastal_id})

    spawn_points = []
    candidates_a = []
    candidates_b = []
    for idx, val in enumerate(grid):
        if val not in SPECIAL_TILES:
            continue
        x, y = idx % width, idx // width
        if val == TILE_SPAWN_P1:
            spawn_points.append({"team": 0, "x": x, "y": y})
        elif val == TILE_SPAWN_P2:
            spawn_points.append({"team": 1, "x": x, "y": y})
        elif val == TILE_CANDIDATE_A:
            candidates_a.append({"x": x, "y": y})
        elif val == TILE_CANDIDATE_B:
            candidates_b.append({"x": x, "y": y})
        grid[idx] = 0  # neutral placeholder -- true underlying terrain is not recoverable

    levl_value = None
    if levl_raw is not None:
        v = levl_raw - 1
        levl_value = v if 0 <= v < 9 else 8

    return {
        "source": filename,
        "width": width,
        "height": height,
        "mode_byte": mode_byte,
        "enabled": enabled,
        "name": name,
        "author": author,
        "created": created,
        "modified": modified,
        "levl_raw": levl_raw,
        "levl_value": levl_value,
        "vehicle_params": vhcl_values,
        "vehicle_param_sources": vhcl_sources,
        "chunk_tags_seen": chunk_tags_seen,
        "unrecognized_chunks": unrecognized_chunks,
        "spawn_points": spawn_points,
        "candidate_pools": {"a": candidates_a, "b": candidates_b},
        "decorations": decorations,
    }, grid, art_grid


def _art_id_color(art_id):
    """Deterministic false-colour per resolved art id (0-127ish). Art id 0 is the
    large "blank/unused" bucket (mostly reserved slots) -- render it as dark green
    "generic land" so real levels don't look like they have holes; every other id
    gets a colour hashed from the id itself so distinct terrain classes are visibly
    distinct without needing real art yet."""
    if art_id == 0:
        return (40, 110, 50)
    h = (art_id * 2654435761) & 0xFFFFFFFF  # Knuth multiplicative hash
    r = 60 + (h & 0xFF) % 180
    g = 60 + ((h >> 8) & 0xFF) % 180
    b = 60 + ((h >> 16) & 0xFF) % 180
    return (r, g, b)


def render_debug_png(path, width, height, art_grid, meta):
    """False-colour terrain by resolved ART ID (not raw tile byte) with entities
    highlighted on top, so the grid and extracted entities can be checked by eye,
    not just counted."""
    buf = bytearray(width * height * 4)
    for i, art_id in enumerate(art_grid):
        r, g, b = _art_id_color(art_id)
        o = i * 4
        buf[o], buf[o + 1], buf[o + 2], buf[o + 3] = r, g, b, 255

    def mark(x, y, color, radius=1):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < width and 0 <= yy < height:
                    o = (yy * width + xx) * 4
                    buf[o], buf[o + 1], buf[o + 2], buf[o + 3] = color

    for sp in meta["spawn_points"]:
        color = (255, 0, 0, 255) if sp["team"] == 0 else (255, 255, 0, 255)
        mark(sp["x"], sp["y"], color, radius=1)
    for c in meta["candidate_pools"]["a"]:
        mark(c["x"], c["y"], (255, 0, 255, 255), radius=0)
    for c in meta["candidate_pools"]["b"]:
        mark(c["x"], c["y"], (0, 255, 255, 255), radius=0)

    write_png_rgba(path, width, height, buf)


def main():
    argv = sys.argv[1:]
    limit = None
    args = []
    i = 0
    while i < len(argv):
        if argv[i] == "--limit":
            limit = int(argv[i + 1]); i += 2
        else:
            args.append(argv[i]); i += 1

    if len(args) != 2:
        print(__doc__)
        return 2

    src_root, out_dir = args
    worlds_dir = os.path.join(src_root, "WORLDS")
    if not os.path.isdir(worlds_dir):
        print("error: no WORLDS directory under %s" % src_root)
        return 1

    os.makedirs(out_dir, exist_ok=True)

    rfm_files = []
    for dirpath, _dirs, files in os.walk(worlds_dir):
        for name in files:
            if name.upper().endswith(".RFM"):
                rfm_files.append(os.path.join(dirpath, name))
    rfm_files.sort()
    if limit:
        rfm_files = rfm_files[:limit]

    print("found %d .rfm files under %s" % (len(rfm_files), worlds_dir))

    ok = 0
    failed = []
    total_spawns = {0: 0, 1: 0}
    total_candidates = {"a": 0, "b": 0}
    size_classes = {}

    for path in rfm_files:
        filename = os.path.basename(path)
        rel = os.path.relpath(path, worlds_dir)
        try:
            meta, grid, art_grid = parse_rfm(path, filename)
        except RfmError as e:
            failed.append((rel, str(e)))
            continue

        meta["rel_path"] = rel.replace("\\", "/")
        stem = os.path.splitext(filename)[0]
        out_json = os.path.join(out_dir, stem + ".json")
        out_bin = os.path.join(out_dir, stem + ".tiles.bin")
        out_art = os.path.join(out_dir, stem + ".art.bin")
        out_png = os.path.join(out_dir, stem + ".debug.png")

        with open(out_json, "w") as f:
            json.dump(meta, f, indent=1)
        with open(out_bin, "wb") as f:
            f.write(grid)
        with open(out_art, "wb") as f:
            f.write(art_grid)
        render_debug_png(out_png, meta["width"], meta["height"], art_grid, meta)

        for sp in meta["spawn_points"]:
            total_spawns[sp["team"]] = total_spawns.get(sp["team"], 0) + 1
        total_candidates["a"] += len(meta["candidate_pools"]["a"])
        total_candidates["b"] += len(meta["candidate_pools"]["b"])
        size_classes[os.path.getsize(path)] = size_classes.get(os.path.getsize(path), 0) + 1
        ok += 1

    print("\nconverted %d / %d files" % (ok, len(rfm_files)))
    print("spawn points found: team0=%d team1=%d" % (total_spawns.get(0, 0), total_spawns.get(1, 0)))
    print("candidate positions found: pool_a=%d pool_b=%d" % (total_candidates["a"], total_candidates["b"]))
    print("file sizes seen:", {k: v for k, v in sorted(size_classes.items())})

    if failed:
        print("\nFAILED (%d):" % len(failed))
        for rel, err in failed:
            print("   %s: %s" % (rel, err))
    else:
        print("\nno failures")

    return 0


if __name__ == "__main__":
    sys.exit(main())
