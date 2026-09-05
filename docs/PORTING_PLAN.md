# Return Fire (1996, Silent Software) — Godot Port Plan

**Status:** planning complete. Phase 1a/1b/1c converters written and verified.
**Audience:** an AI coding agent executing after context compaction. Everything needed is
in this file; do not assume prior conversation is available.

**Converters live in:** `C:\Users\Alex\Documents\code\returnfire-godot\tools\`
**Source data:** `C:\Users\Alex\Documents\returnfire`

---

## 0. Goal and constraints

Rebuild *Return Fire* (PC/Win95 port of the 3DO original) as a **Godot 4 project**.

Two things this engine must do, and the second one shapes the whole architecture:

1. Run the original game from the user's own retail data files — **including the 3DO
   original**, not just the PC port. The user has said the 3DO base game disc should be
   supported *alongside* the 3DO-exclusive expansion, *Return Fire: Maps o' Death* (rather
   than the expansion being supported in isolation) — the two share the same native 3DO
   asset formats and filesystem, so this is one importer effort, not two. The expansion
   image is already in hand; the base 3DO game image is a planned future addition (not yet
   provided). See section 1.11 for initial recon and section 4 for the open extraction work.
2. Run equally well on a **completely custom, hand-authored replacement asset set**.

The engine is therefore a *data-driven engine that happens to ship with an importer for
the 1996 files* — not a port with modding bolted on. See section 2.4.

Target features that justify the rebuild (a DirectDraw wrapper cannot give these):

- Native widescreen
- Uncapped / decoupled framerate
- Linux and ARM builds
- Netplay
- **Web export**, shipping the author's own asset pack
- **4-player support.** The original is 2-player only — every `.RFM` file defines exactly
  one team-0 and one team-1 spawn point, never more (section 1.5, and the totals in section
  1.5's converter run: 204 team-0 spawns, 104 team-1 spawns, one each, no exceptions). Making
  this real needs: (a) a split-screen/viewport layout that scales past 2 (section 2.2), (b) a
  netcode design that isn't quietly assuming 2 participants (section 3 Phase 5), and (c) a
  decision for the original's own maps, which have nowhere for a 3rd/4th spawn to come from —
  either synthesize extra spawns algorithmically or scope 4-player to custom/replacement maps
  (section 2.4) where the map author places all 4 explicitly. See section 4 item 8.

The web target is not a "someday maybe" — it constrains the language the simulation is
written in, the rendering backend, the netplay transport, and the pack format. See
section 2.5. **Do not treat it as a late-stage porting exercise; it is a design input.**

**Legal rule, non-negotiable:** ship converters and engine code only. Never commit or
distribute extracted assets, and never commit decompiled game code verbatim. The build
must require the user to supply their own installed copy. This is the devilutionX /
OpenRCT2 / OpenTTD pattern. Note that a *complete* replacement asset pack (section 2.4)
would let the engine ship standalone, the way FreeDoom and OpenRA do — that is a real
strategic payoff, not just a nicety.

---

## 1. Ground truth — measured facts

Established by direct inspection. **Section 1.6 contains corrections to earlier
assumptions that turned out to be wrong — read the CORRECTION notes.**

### 1.1 Executables

| File | Type | Notes |
|---|---|---|
| `RFIRE.BIN` | 32-bit x86 PE, MSVC, linked 1996-04-08 | **The actual game.** `.text` 243,724 b; `.data` 327,376 b; relocs intact; not packed |
| `RFIRE.EXE` | 32-bit PE, 22 KB | Launcher only. Resolves a path, execs `\RFIRE.BIN` |
| `AUTORUN.BIN`, `CONFIG.BIN` | 32-bit PE | Autorun shell / config utility |
| `_RUNME.EXE` | 32-bit PE | Launches `AutoRun.bin` |
| `RUNME.EXE` | **real-mode DOS MZ**, no PE header | Cannot run on 64-bit Windows (no NTVDM). Bypass it |
| `DIRECTX/` | DirectX 3 redist, Sep 1995, incl. 16-bit DLLs + `.VXD` | **Never run `DXSETUP.EXE` on a modern OS** |

`RFIRE.BIN` is a 32-bit user-mode PE, so it already runs on 64-bit Windows under WoW64.
Nothing in the game's own code blocks 64-bit; only the DOS stub and the 1995 DirectX
installer do.

Version string: `Return Fire Ver. G406.1.0.00 Win95 x86 - Windows 95 DirectX Game`

### 1.2 What RFIRE.BIN binds to (informs what must be reimplemented)

- **Graphics:** `DDRAW.dll` → `DirectDrawCreate` **only**, plus GDI `StretchDIBits`,
  `CreatePalette`, `RealizePalette`, `GetSystemPaletteEntries`, `UpdateColors`.
  → A **pure software rasterizer** writing a palettized buffer and blitting once per
  frame. No 3D pipeline, no Glide, no D3D immediate mode to translate.
- **Audio:** `DSOUND.dll` → `DirectSoundCreate`.
- **CD audio:** `WINMM` `mciSendCommandA` → Redbook music, **with a `SOUND/Score.WAV`
  streaming fallback when no CD device is open (SOLVED, section 1.8) — `DRUMS.WAV` is
  unrelated, never referenced by the binary at all.**
- **Input:** `WINMM` `joyGetNumDevs`, `joyGetDevCapsA`, `joyGetPos`, `joyGetPosEx`
  (legacy joystick API); `USER32` `GetKeyboardState`.
- **Timing:** `timeGetTime`, `GetTickCount`.
- **Video:** `AVIFIL32` + `MSVFW32` (`ICOpen` / `ICSendMessage`) imports exist, but **there
  is no cutscene video format to solve — corrected (2026-09-05), see section 1.11.** The
  reference retail CD's `Title/*.stm` files, which looked like the obvious cutscene-video
  candidate, turn out to be **more audio**, not video: every one opens with the same `auds`
  fourCC as `Score.WAV` (section 1.8). The `AVIFIL32` import is the same
  `AVIStreamOpenFromFileA`-on-a-non-AVI-container trick applied a second time, not evidence
  of real video playback anywhere in this game.
- No `DPLAY` import → original networking is serial / split-screen, not DirectPlay.

### 1.3 `.RFA` art files — SOLVED, converter written and run

Plain uncompressed Windows BMPs with a renamed extension. All 16 files converted cleanly.

The one trap: palette size is **not** always 256 entries, so the pixel offset must be read
from `bfOffBits` at offset 10 — a hardcoded 1078 would corrupt two files.

| File | W x H | bpp | Palette |
|---|---|---|---|
| `PS480.RFA` | 640 x 480 | 8 | 256 |
| `PS240.RFA` | 320 x 240 | 8 | 256 |
| `1PBSCRH.RFA` | 640 x 176 | 8 | 256 |
| `2PBSCRH.RFA` | 640 x 183 | 8 | 256 |
| `AUTORUN.RFA` | 276 x 400 | 8 | 256 |
| `BUTTONS.RFA` | 257 x 144 | 8 | 256 |
| `FIX.RFA`, `NOWRL.RFA` | 128 x 128 | 8 | 256 |
| `2PMSCR.RFA` | 24 x 299 | 8 | 256 |
| `SMALL.RFA` | 20 x 13 | 8 | 256 |
| `NEWREQLG.RFA` | 640 x 480 | 8 | **224** |
| `NEWREQSM.RFA` | 320 x 240 | 8 | **224** |
| `PAUSE16.RFA` | 320 x 240 | **4** | **16** |

`ART/TRANS.TBL` (81,924 b) is a translucency / blend LUT for the software rasterizer. In
Godot this becomes a shader blend mode; likely needed only for exact colour matching.

### 1.4 `.SDT` sound files — SOLVED, converter written and run

Plain RIFF/WAVE, **format tag `0x0001` (uncompressed PCM)**. All 40 files validated as PCM
with a `data` chunk; no anomalies. Rates found:

- 11025 Hz mono 8-bit — 37 files
- 44100 Hz **stereo 16-bit** — 1 file (`AR1.SDT`)
- 5563 Hz mono 8-bit — 1 file
- 11127 Hz mono 8-bit — 1 file (odd rate; resample on import)

Do not assume a single format. (An earlier guess that these were 3DO SDX2 ADPCM was
wrong — the port converted them to PCM.)

### 1.5 `.RFM` map files — MOSTLY SOLVED, verified against the real loader in RFIRE.BIN

204 files under `WORLDS/{1PLAYER,2PLAYER}/LEVEL*/`. Exactly two sizes:
**16,756 bytes (x154)** and **16,772 bytes (x50)**.

**This section was cracked by reading the actual loader out of Ghidra (headless, via
`tools/ghidra_scripts/`, see Phase 2), not by guessing from bytes.** The real format is a
**named-chunk container**, not a fixed-layout header — that reframes what "the header" even
means, so treat the byte-offset table below as ground truth over anything stated elsewhere
in this document that predates it.

**Container layout:**

```
offset 0x00        "WRL\0"     4-byte magic (verified: RFIRE.BIN compares the first 4
                                bytes against this exact constant via lstrcmpiA)
offset 0x04..0x3F  ...         header fields -- MOSTLY DECODED as of 2026-09-06, see below.
    0x04  4 bytes  constant `54 4D 00 05` ("TM\0\x05") in all 204 real files -- likely a
                    secondary format/version tag; exact meaning unconfirmed, but its
                    constancy is itself confirmed, not assumed.
    0x08  u16 LE   width          (128 in every file seen so far)
    0x0A  u16 LE   height         (128 in every file seen so far)
    0x0C  2 bytes  constant `01 01` in all 204 real files -- meaning unconfirmed.
    0x0E  u16 LE   MS-DOS packed date -- **file CREATED date**, part of a timestamp pair
                    (see below).
    0x10  u16 LE   MS-DOS packed time -- file CREATED time.
    0x12  u16 LE   MS-DOS packed date -- file **last-MODIFIED** date.
    0x14  u16 LE   MS-DOS packed time -- file last-modified time.
    0x16  u8       mode/player-count selector byte (copied into a global that gates
                    1-player vs. 2-player logic elsewhere in the loader)
    0x17  15 bytes null-padded ASCII -- **level author/designer name**, defaulting to the
                    literal string `"Unknown"` when not set. (Not the same field as `NAME`'s
                    display name below, and not at offset 0x18 as an earlier draft of this
                    document guessed before being re-examined -- it starts at 0x17.)
    0x26  26 bytes  constant zero in all 204 real files (padding out to offset 0x40).
offset 0x40        u8          must be non-zero, or the loader rejects the file outright
                                (an "enabled"/"valid" flag, meaning not every *.rfm on
                                disk is necessarily loadable -- unconfirmed which if any
                                in this install have it unset)
offset 0x44        u32 LE      byte length of the tile-grid region (== width*height;
                                16384 for every 128x128 file seen so far)
offset 0x48        u32 LE      byte offset from file start to where the chunk table ends
                                AND the tile grid begins (this single field is used both
                                ways in the loader -- see below)
offset 0x50 ..      chunk table -- see next section
  (0x48 value)-1
offset (0x48 value)  tile grid, width*height bytes, one byte per tile, row-major
  .. end of file      (== last 16384 bytes for every 128x128 file seen so far, matching
                       earlier ASCII-rendered verification)
```

**The header body (offsets `0x0E`-`0x25`) — SOLVED (2026-09-06), no Ghidra needed this time.**
Purely empirical: dumped bytes `0x00`-`0x4F` of all 204 real files and looked at per-offset
variance directly (which offsets are constant across every file vs. which vary). Two real
fields fell out:

- **`0x0E`-`0x15` (8 bytes): a pair of MS-DOS packed date+time stamps** (the classic
  `_dos_getftime` 2+2-byte format DOS/Win16 tools used for file timestamps) — file
  **created** at `0x0E`/`0x10`, last **modified** at `0x12`/`0x14`. Verified, not guessed:
  decoded all 204 files' worth and checked every one falls in a sane range (year 1994-1996,
  valid month/day/hour/minute) — **zero failures**. Real decoded examples: `RFMAP001.RFM`
  created `1995-07-21 11:07:00`, modified `1995-10-30 17:11:36`; `RFMAP002.RFM` created
  `1995-09-14 17:23:34`, modified `1996-02-17 11:29:08` — both consistent with `RFIRE.BIN`'s
  own linked date of 1996-04-08. Almost certainly the source `.rfm` file's own filesystem
  timestamps, captured by the level editor at save time.
- **`0x17`-`0x25` (15 bytes): a null-padded ASCII field holding the level's author/designer
  name**, defaulting to the literal string `"Unknown"` when not set (71 of 204 files).
  Real, human values found across the other files: `MichaelAngelo` (by far the most common
  credited designer, in several capitalizations — `Michael Angelo`, `michael`, `MICHAEL
  ANGELO`), `John`, `John L. Saleigh`, `Van`/`van`, `James`, `Reichart`, `Michael Klug`,
  `Andy`, `CJ`/`cj`, `oliver`, `Rasputin(tm)`, `William Ware`, `The Baron`, and a plain `v`
  (67 files — the same short-signature pattern as the fuller names, not an anomaly). This
  resolves the loose end left in the `NAME` chunk row below ("offset 0x18" was never
  re-examined) — the real field starts at `0x17`, not `0x18`, is a fixed 15 bytes, and is
  a completely different piece of data from the `NAME` chunk's display name (that one's the
  level's title shown in-game; this one is who built it, never shown to the player as far as
  this investigation found).

Still not decoded: `0x04`-`0x07` (constant `54 4D 00 05` = `"TM\0\x05"` in every real file —
a probable secondary format/version tag, exact meaning unconfirmed) and `0x0C`-`0x0D`
(constant `01 01`, meaning unconfirmed); `0x26`-`0x3F` is confirmed plain zero padding.

The previously-recorded 372/388-byte "header length" (`filesize - 16384`) is exactly the
value at offset 0x48 for a 128x128 level: it is chunk-table-end, not a fixed struct size.
**Confirmed exactly** (converter run against all 204 real files, `tools/convert_rfm.py`):
the 50 files at 16,772 bytes are *precisely* the 50 files with a `VHCL` chunk present; the
154 files at 16,756 bytes are *precisely* the 154 without one. The size-class split was
never a format variant -- it's just whether that one optional chunk is there.

**Chunk table format** (offset 0x50 through the offset-0x48 value): a flat sequence of
records, each `[4-byte tag name][4-byte total record length][payload...]`. Walk it by
adding each record's length field to your position to reach the next record, stopping at
the offset-0x48 boundary. Confirmed tags, all four seen in every one of the 204 real files
except where noted:

| Tag | Payload | Meaning |
|---|---|---|
| `LEVL` | payload byte 0 | A value 0-8 (stored on disk as value+1; the loader treats a decoded value >8 as invalid and clamps to 8). Read from a single byte, likely difficulty or a related per-level knob -- name inferred from the tag, not yet certain. |
| `NAME` | starts with a null-terminated string, **but the record is much bigger than that string** (e.g. 268 bytes for a ~14-byte name) | The level's display name (confirmed exactly right -- decoded names like "The Cakewalk" and "Driving School" match the source filenames seen in section 1.2/1.5's string dump). Everything after the terminating null in the same record is editor/build-only cruft, not gameplay data: observed to contain what is very likely the original developer's full source path (`...\Images\Worlds\1Player\Level1\The Cakewalk.rfm`) followed by a block of binary data that looks like leftover editor state (camera position, undo history, or similar -- not decoded, not needed). **The converter must stop at the first null byte and ignore the rest of the record.** Separate from the header body's own author/designer-name field at offset `0x17` (confirmed, see above) -- that one is who built the level, this one is its displayed title. |
| `VHCL` | 6 bytes, relative to the *record start* (not payload start): `+8`=A, `+9`=H, `+0xA`=J, `+0xB`=T, `+0xC`=?, `+0xD`=M | Level-tuning parameters, present in exactly 50 of 204 files (see above). **The same six parameters can also be written directly into the .rfm *filename*** using a bracket suffix the loader parses independently, e.g. `SomeLevel[A3H5T2].rfm` -- confirmed by decompiling the parameter parser (`FUN_00413f00`): it scans the filename for `[`, then for each `<letter><digits>` pair inside the brackets sets that parameter, with the VHCL chunk (if present) only overriding whichever of the six the loader didn't already get a valid (non-`0xFF`) value for. Letters confirmed: `A` (<10), `H` (<10), `J` (<10, nonzero), `M` (<201), `T` (<10). This is a real, working config mechanism worth preserving in the content-pack format (section 2.4) rather than special-cased away. |
| `EDTN` | 4 bytes, e.g. `27 03 27 03` (two identical u16 LE values) | **CONFIRMED UNUSED BY THE GAME (2026-09-06).** `FUN_00414130` (the loader) contains exactly 3 chunk-tag string comparisons in its entire body, dumped and read directly: `"VHCL"` @ `0x0044881C`, `"NAME"` @ `0x00448824`, `"LEVL"` @ `0x0044882C` -- no fourth comparison exists anywhere in the function. Any chunk tag the loader doesn't recognize (including `EDTN`) is walked past purely by its record-length field and never inspected. Its contents are therefore editor/build-only bookkeeping the *game itself* never reads -- not just unidentified, but confirmed irrelevant to a faithful port. Round-tripping it opaquely (already done) isn't a shortcut, it's the behaviorally correct thing to do: it's exactly what `RFIRE.BIN` itself does. |

Chunk tag constants live at `0x00448814`-ish through `0x00448834` in RFIRE.BIN's data
segment if this needs re-verifying or extending (`VHCL\0\0\0\0`, `NAME\0\0\0\0` are adjacent
8-byte-padded entries; `LEVL` is a separate, standalone 8-byte-padded string at `0x0044882C`
found via the same technique).

**No dedicated spawn-point / building-placement chunk exists — SOLVED. Spawn points and
building/target candidates are specific tile *values* in the grid**, not a separate object
list, and the mechanism is now fully traced end-to-end (loader code + cross-checked against
all 204 real files):

**Tile-grid runtime decoding (verified from the loader):**

- The engine always maintains a **fixed 128x128 (16384-entry) world buffer**, regardless of
  a level's on-disk width/height. If a level's grid is smaller than 128x128, it is
  **centered** in that buffer (`(128-width)/2, (128-height)/2` offset) rather than placed at
  the origin. Every level examined so far happens to be exactly 128x128 (no centering
  needed), but the loader clearly supports smaller grids -- do not assume all 204 files are
  128x128 without checking.
- Each runtime buffer entry is a **32-bit value**, not the raw on-disk byte. Each raw
  on-disk byte (0-239; values >=240 are clamped to 0 before lookup) indexes a **4-byte
  stride lookup table at `0x00448450`** in RFIRE.BIN (240 entries, fully dumped, persisted
  at `tools/data/tile_lookup_tables.json`), one record per possible tile value:
  `[transform_byte, coastal_id, param4, dispatch_idx]`. (Earlier notes here called fields 2
  and 3 `pad`/`secondary_param` -- that was wrong, corrected after decompiling the function
  that actually consumes them; see below.)
  - `transform_byte` sets the low 7 bits of the runtime tile value directly (a value of
    `0xFF` here means "leave the tile's low 7 bits alone / no terrain art" instead; 58 of
    the 240 raw slots are `0xFF` with `coastal_id` also `0` -- confirmed genuinely unused:
    **none of the 204 real files ever contain any of those 58 raw byte values**).
  - **If `coastal_id != 0`: calls `FUN_0042e4f0(coastal_id, tile_ptr, 0, param4)`.** This
    function was decompiled in full (`tools/ghidra_scripts/DecompileOne.java 0042e4f0`).
    Contrary to the earlier guess in this section, **it does NOT do any runtime
    neighbor-aware autotiling** -- the loader always calls it with the "neighbor" argument
    (`param_3`) hardcoded to `0`. It's a second, static table lookup: `coastal_id` (1-91,
    count confirmed at `DAT_00447028 == 0x5B == 91`) indexes a **56-byte-stride table at
    `0x00447038`**, whose `+8` byte (`base_art`) becomes the tile's final low-7-bit art id,
    unless `base_art == 0xFF` (in which case the `transform_byte` from the primary table
    is kept -- always `0` for every coastal-tagged raw value in practice, since coastal
    tiles' `transform_byte` is only ever a placeholder). There's also a `+4` "mode" field
    compared against the literal `8` for an alternate `base_art + param4` path -- dumped
    across all 91 real entries, `mode` is never actually `8`, so that path is dead for real
    game data and isn't implemented in the converter. **Net effect: the final rendered art
    id for every raw tile byte is a pure static function of the byte itself -- the level
    editor bakes the correct coastline-edge shape into the file when it's saved, there is
    no per-match or per-neighbor computation.** Implemented as `tools/rf_tile_art.py`
    (`raw_tile_to_art_id()`), cross-checked against all 204 real files: **zero cells fail to
    resolve, and the 104 art ids the two tables predict are exactly the 104 art ids that
    actually appear.** `convert_rfm.py` now emits this resolved grid as `<name>.art.bin`
    (parallel to the raw `<name>.tiles.bin`) -- **Phase 3/4 rendering should consume
    `.art.bin`, not the raw bytes.**
  - **If `dispatch_idx != 0`: dispatches through a 2-entry function-pointer table at
    `0x00448810`** (confirmed to be exactly 2 entries -- the string table for the chunk tags
    `VHCL`/`NAME`/`LEVL` begins immediately after at `0x0044881C`, so don't over-read it).
    Only 4 of the 240 tile values trigger this: `0x39`, `0x4D` → function-pointer index 1
    (`FUN_00413e00` @ `0x00413e00`); `0xB4`, `0xDC` → index 2 (`FUN_00413db0` @
    `0x00413db0`). Both were force-decompiled (they're only reachable via an indirect call,
    so Ghidra's static analysis didn't auto-recognize them as functions --
    `tools/ghidra_scripts/ForceDecompile.java` handles this: disassemble + createFunction at
    the address, then decompile). Neither dispatch function touches the tile's art bits --
    they only record a position -- so spawn/candidate tiles still resolve to a real,
    meaningful art id via the `coastal_id`/`transform_byte` path above (e.g. both candidate
    tiles `0xB4`/`0xDC` resolve to art id 109, i.e. "buildable ground"; the two spawn tiles
    resolve to distinct ids 90/91). `convert_rfm.py` computes `.art.bin` from the grid
    *before* zeroing these cells out in the raw `.tiles.bin`, specifically to preserve this.

**What those two dispatch functions actually do, and what the four special tile values
are, cross-checked against a byte-histogram scan of all 204 real `.rfm` files**
(`tile.count(value)` over each file's last 16384 bytes):

| Tile value | Occurrences across 204 files | Only in 2-player levels? | Dispatch fn | Meaning |
|---|---|---|---|---|
| `0x39` | **exactly 1, in every single file** | no (both modes) | `FUN_00413e00`, arg `0` | **Player 1 spawn point.** |
| `0x4D` | 0 or 1 (1 in exactly the 104 `2PLAYER\` files, 0 in all 100 `1PLAYER\` files) | **yes** | `FUN_00413e00`, arg `1` | **Player 2 spawn point.** |
| `0xB4` | 0-56, present only in `2PLAYER\` files (104) | **yes** | `FUN_00413db0`, arg `0` | Candidate building/target position, pool A. |
| `0xDC` | 1-160, present in **every** file (both modes) | no | `FUN_00413db0`, arg `1` | Candidate building/target position, pool B. |

`FUN_00413e00(tile_ptr, team_index, pixel_x, pixel_y)` writes into a small fixed-size (4
slots per team) spawn-position table, keyed by `team_index` (0 or 1 -- exactly matching the
two tags' `secondary_param` values above). This is genuinely a two-team spawn system, not
per-player-count special-casing.

`FUN_00413db0(tile_ptr, pool_index)` appends the tile's *pointer into the runtime grid
buffer* (not a separate x/y) to one of two growable candidate-position pools — confirmed
exactly which is which by decompiling it: `pool_index==0` (tile `0xB4`, "pool A") appends to
`DAT_0045ae70` and grows count `DAT_0045ae28`; `pool_index==1` (tile `0xDC`, "pool B")
appends to `DAT_0045b270` and grows count `DAT_0045ae2c` — capped at 254 entries each. Back
in the main loader (`FUN_00414130`), once the whole grid has been scanned, **each non-empty
pool has exactly one entry picked at random** — `FUN_00404360(count)` calls the C runtime
`rand()` and scales it into `[0, count)` — and stored as the active building/target for that
match (`_DAT_0045ae50` for pool A, `_DAT_0045ae54` for pool B). This is the mechanism behind
the classic Return Fire feature where the destructible target/base locations differ between
plays of the same level: **the level file defines a pool of candidate positions, and the
engine randomly commits to a subset each match.**

**The `>>1` "half the pool count" computation — SOLVED (2026-09-06), and it's not a literal
win condition.** `_DAT_0048ca20 = DAT_0045ae28 >> 1` and `_DAT_0048ca24 = DAT_0045ae2c >> 1`
are each pool's initial "replacement budget" (half its candidate count, rounded down), and
those two globals have exactly 2 other cross-references in the whole binary, both inside
`FUN_00432710` — the object-destruction handler, called whenever a queued object is removed
from play. It reads a pool index from **bits 14-15 of the destroyed tile's runtime value**
(`(tile & 0xc000) >> 0xe`) — *correcting* the earlier "orientation-ish (bits 14-15)" guess
below: those bits are the pool-membership tag, not orientation — decrements that pool's
budget, and if the destroyed object was the pool's currently-tracked active target, calls
`FUN_00432600(pool)` to activate a replacement. That function scans the pool's candidate
array for any position still showing "intact" state (`tile & 0x3f80 == 0xb00`, a distinct
state/frame field, not the low-7-bit terrain art id) and, if any remain, randomly picks one
(`FUN_0041d3d0`) as the new active target. **Net effect: each pool is a rotating
single-target spawner** — exactly one destructible target is live per pool at a time,
immediately replaced from the remaining candidates when destroyed, for as long as the
pool's budget holds out. This is a materially better description of the classic
"bases keep reappearing elsewhere" feel than the original "destroy half the spawned targets
to win" guess: it's a continuous replacement budget, not a simultaneous group to wipe out.
**Still open:** no code touching these two budget globals reads them to declare an overall
match-won/lost state, so what (if anything) happens when a pool's budget is fully spent
hasn't been found. `FUN_0042c4d0` (called from `FUN_00432710` right as a pool's tracking
gets cleared) was checked and **ruled out (2026-09-06)** as the win-condition trigger — it's
a fully generic "mark this object dead and link it into the free list" utility called from
35+ unrelated sites across the entire binary (vehicles, projectiles, buildings alike), not
anything specific to match state. The trail from there leads into a large, general
AI-targeting/combat subsystem (`FUN_00432d00`/`FUN_00432d80`/`FUN_00432e40` and neighbors)
with no clear anchor pointing at "declare victory" specifically, so this question is left
open rather than chased further without a better lead — see section 4.

**Remaining work, in priority order:**
1. The `+9` "height_seed" byte in the `0x00447038` coastal table and the runtime tile
   value's elevation-ish bits 25-27 (set by `FUN_0042e4f0`) are dumped but not chased --
   likely affect physics/movement, not rendering, so lower priority than art. (Bits 14-15
   are no longer mysterious -- see above: pool membership, not orientation.)
2. The exact meaning of the two small constant header fields `0x04`-`0x07` (`"TM\0\x05"`)
   and `0x0C`-`0x0D` (`01 01`) -- confirmed constant across all 204 real files, but *why*
   is still a guess (a secondary format/version tag, most likely). Very low priority: a
   constant the converter can round-trip without understanding, same as `EDTN`.

**DONE (2026-09-06):** Mapped the previously-undecoded header body -- see above (`0x0E`-`0x25`
now fully decoded: a DOS-format created/modified timestamp pair and a 15-byte author/designer
name field). Also confirmed none of the 204 real files have the offset-`0x40` "enabled" byte
unset (a plain empirical check, cheap enough to just run rather than leave open).

**DONE:** Decompiled `FUN_0042e4f0` and fully resolved the raw-tile-byte → rendered-art-id
pipeline (see above) -- this was open question #2 ("classify the ~94 plain-terrain tile
values") and is now closed with 100% coverage, cross-validated against all 204 real files.
**Wrote the actual `.RFM` converter** (Phase 1d, `tools/convert_rfm.py`) -- parses the
chunk table, resolves tile values through both lookup tables, and emits tilemap + art-id
grid + spawn points + candidate-pool JSON, run clean against all 204 real files.

**Ghidra references for continuing this:** `FUN_00414130` @ `0x00414130` in RFIRE.BIN is the
full level loader (decompiled in full during this investigation -- re-run
`tools/ghidra_scripts/DecompileOne.java` with that address to get it again without redoing
the search). Its caller is `FUN_0041e9f0` @ `0x0041e9f0`. The lightweight "just get the
display name for the level-select menu" path is a separate, simpler function,
`FUN_004266d0` @ `0x004266d0`, called from `FUN_00426f70` @ `0x00426f70` (which enumerates
`*.rfm` files via `FindFirstFileA`/`FindNextFileA`).

### 1.6 `ART/ART.CAR` — SOLVED, converter written and verified for all 2165 cels

1,926,415 bytes. A 3DO Cel Control Block array, flattened for the PC port.

```
offset 0x000000   char[4]  "CCBA"
offset 0x000004   u32      1926415     == exact file size (verified)
offset 0x000008   u32      2165        == cel count
offset 0x00000C   u32      0x23F24     == end of CCB array (== 16 + count*68, verified)
offset 0x000010   CCB[2165], 68 bytes each  (17 x u32 LE)
offset 0x023F24   u32[2165][2]  17,320 bytes == count*8 exactly. PURPOSE UNKNOWN.
                                Observed values mostly 5.
offset 0x0282CC   PLUT palettes
offset ...        cel pixel data, addressed by each CCB's SourcePtr
```

**CCB field order (68 bytes, all u32 LE):**

```
 0 Flags      1 NextPtr    2 SourcePtr   3 PLUTPtr
 4 XPos       5 YPos       6 HDX         7 HDY
 8 VDX        9 VDY       10 HDDX       11 HDDY
12 PIXC      13 PRE0      14 PRE1       15 Width
16 Height
```

**Verified properties:**

- `SourcePtr` and `PLUTPtr` are **file-relative byte offsets**, not 3DO pointers.
- **Most cels are 8bpp unpacked linear** — exactly `Width*Height` bytes at `SourcePtr`.
  Confirmed two ways: consecutive-offset deltas equal `W*H` for 1880 of ~1890 measurable
  cels, and the resulting atlas renders as correct, recognisable sprite art.
- **Palette index 0 IS transparent — CONFIRMED VISUALLY.** The decoded atlas shows sprites
  cleanly isolated on transparent black.
  (A border-vs-interior statistical heuristic reported "inconclusive" here — 77.8% of
  border pixels and 61.5% of interior pixels are index 0 — because these sprites are
  mostly empty space inside power-of-two cells. **Ignore that heuristic; trust the
  render.**)
- **PLUT format is Windows `RGBQUAD` (B, G, R, pad)** — 4 bytes per entry, NOT 3DO RGB555.
  At `0x282CC`: `00 00 00 00 | FF FF FF 00 | 57 85 B5 00 | ...` → entry 0 black, entry 1
  white, entry 2 = RGB(0xB5, 0x85, 0x57). Read as `b, g, r, pad`. 256 entries.
- **Three distinct `PLUTPtr` values: `0x282CC` (2161 cels), `0x28AD0` (2), `0x28AE0` (2).**
  *CORRECTION: an earlier draft listed `0x28B10` / `0x28B20`. Those were wrong.* **RESOLVED
  (2026-09-05):** the two oddball PLUTs belong exactly to the 4 `PRE0==17` cels (see below) —
  each is a genuine small embedded palette for an ordinary sprite, not an anomaly.
- **Two distinct `Flags` values: `0x7FE64400` (1847 cels) and `0x7FE64420` (318 cels).**
  They differ only in bit `0x20`. **RESOLVED:** this is the real 3DO `CCB_BGND` flag
  (confirmed against `trapexit/3doplay`'s `Madam.cpp` — see section 4). It gates whether
  pixel value 0 is treated as transparent for a cel. Neither value here has it set, so
  transparency is on for every cel in this file — consistent with the visual confirmation
  above.
  *CORRECTION: an earlier draft had these two counts swapped.*

**The `PRE0 != 0` cels — SOLVED (2026-09-04), and they are not what they were assumed to
be.** 93 of 2165 cels have non-zero `PRE0`. An earlier pass through this investigation
assumed (by analogy with the real 3DO MADAM cel engine) that these were *compressed sprite
colour data* — `PRE0`'s low 3 bits chosen to look like the real 3DO bit-depth code, packed
with a literal/skip/repeat opcode stream. **That was wrong.** It was checked directly
against `RFIRE.BIN`'s actual renderer via Ghidra and the real mechanism is different and,
once understood, fully explains every piece of prior evidence (the tiny byte counts, the
confirmed row-offset table, and why the literal-opcode decode attempt produced noise).

**What they actually are:** 89 of the 93 are not sprites at all. They are **coverage masks
for a masked palette-translation blend effect** — shadows, colour tints, glow gradients, and
similar VFX overlays (the exact tint mechanism, including which are shadows vs. colour tints
vs. glows, is now fully solved — see below). The mask says *where* to draw; the colour comes
from remapping whatever pixel is **already on screen underneath**, `dest[x,y] =
TransTable[dest[x,y]]` (or, for 11 of them, a per-pixel-varying row of a 2D table — see
below), not from any colour stored in the cel. This was traced end-to-end through the real
per-frame cel dispatcher and validated by decoding real cels and rendering the masks: they
come out as clean, obviously intentional shapes (a blob/splat silhouette, a notched
rectangular block), not noise, and not something excerpted from copyrighted sprite art since
no colour data is being reproduced, only a coverage silhouette. **The remaining 4 (`PRE0==17`)
are not masks at all — they're ordinary sprites with their own embedded palette** (see below).

Full technical writeup, including the two mask *shape* encodings (`MASK_FAMILY_LINEAR`: plain
`Width*Height` byte array; `MASK_FAMILY_SPAN`, `PRE0==13` only: the *same* row-offset table
this investigation had already found, now with its real meaning — each row's data is a list
of `(x0, x1)` span pairs proportionally scaled from a stored 0-255 range, terminated by a
pair whose first byte is 0, not a bit-packed opcode stream) and the exact tint mechanism for
each `PRE0` value, lives in `tools/rf_effect_cel.py`'s module docstring. Decoded and
cross-checked against **all 93 real cels with zero exceptions** (`tools/rf_effect_cel.py`
run standalone, and via `tools/convert_car.py`).

**Key Ghidra findings that got there** (all headless-decompiled, see
`tools/ghidra_scripts/`): the per-frame cel dispatcher `FUN_00418ef0` switches on the CCB's
**raw 32-bit `PRE0` field**, not `PRE0 & 7` as the earlier (wrong) draft assumed — real
`PRE0` values seen in `ART.CAR` are `{1, 2, 3, 5, 13, 17}`, not a clean bit-depth code.
Traced via the render-submission queue (`FUN_00413c90` queues a raw CCB copy; the queue is
flushed once full or once per frame by `FUN_0041d510` → `FUN_00436fd0` → an indirect call
through `PTR_FUN_00449390`, statically pointing at `FUN_00418ef0`) down through the
mask-blit routines: `FUN_00419920`/`FUN_00419af0` (linear-mask family, `PRE0` 1/2 and
3/4/5 respectively), `FUN_004109a0` (span-mask family, `PRE0==13`, the majority — 46 of
93), and `FUN_00419ea0` (`PRE0==17` — see below, not actually a mask). None of the mask
routines touch a "colour" byte from the cel at all; they read the mask and recolour
whatever's already on screen.

**Exact runtime tint colour — SOLVED (2026-09-05).** The 4 shared translation tables
(`DAT_0046a8f0`/`aa08`/`aa0c`/`aa14`) live in runtime BSS (all-zero in the static binary,
not file data) and are built by `FUN_00424420` (tries `Art\Trans.tbl` first, `0x14004`
bytes; falls back to generating one if missing). Decompiling that fallback-generation path
in full explains exactly what each table is:

- A 256-colour "master palette" is realized as a real `HPALETTE` from a block of raw bytes
  sitting `0x400` bytes past cel 0's own PLUT in `ART.CAR` — the file embeds a ready-made
  palette for exactly this purpose.
- `DAT_0046aa0c`: a full 256x256-byte table, `aa0c[i*256+j] = GetNearestPaletteIndex(master,
  average(pal[i], pal[j]))` for every pair of palette entries — a general "tint toward
  colour `i`" table for any background colour `j`.
- `DAT_0046aa20`: a 32x256-byte "darken" table, 32 brightness levels from ~97% down to 0%.
- `DAT_0046aa14`: a 32x256-byte "brighten" table, 32 levels of `+3` to `+96` per channel
  (clamped).
- `DAT_0046a8f0`/`DAT_0046aa08` are not separate tables — they are fixed **rows 4 and 2** of
  the darken table (~84%/~91% brightness), kept as named pointers because they're the two
  constant shadow strengths the game actually uses.

Cross-checking each mask family's real per-pixel formula against the real mask *byte
values* (not just their code, per section 5's standing rule) revealed a refinement: for
`PRE0` 1/2 the mask is genuinely binary coverage (real bytes are exactly `{0,11}` and
`{0,243}` respectively) feeding a flat `dest=table[dest]`; but for `PRE0` 3/4/5,
`FUN_00419af0` computes `dest = table[mask_value*256 + dest]` — **the mask's raw byte value
selects which row of the 2D table to use, i.e. it is not a coverage flag at all, it encodes
a per-pixel tint colour (`PRE0` 3/4, 8-10 distinct real values per cel) or brightness level
(`PRE0` 5, 16-25 distinct real values, a genuine glow gradient).** `PRE0==13` uses the same
flat formula as 1/2 with the same table (row 4) — explaining why it's the majority (46/93):
these are vehicle/structure drop shadows.

**`PRE0==17` turned out not to be a mask at all.** `FUN_00419ea0` does a plain
`dest = OwnPLUT[mask_value]` — a direct indexed-colour lookup through the *cel's own*
embedded PLUT (`*(CCB+0xc)`), no background blending, standard index-0-transparent
convention. Structurally this is an ordinary sprite. This also resolves the "3 distinct
PLUTPtr values" detail noted below: the two oddball PLUTs (`0x28AD0`, `0x28AE0`, 2 cels
each) belong exactly to these 4 cels.

**RULED OUT (2026-09-06): these are not a team-colour swatch.** An earlier pass here
speculated, from the byte data alone, that these 4 opaque own-palette cels might be an
unused colour-swatch hinting at team colouring. Rendering and cropping them (cel indices
1969-1972, `art_atlas.png`) shows otherwise: each is a 16x16 concentric-ring bullseye
(purple outer ring, black, then a yellow ring, with the innermost ring/dot in a distinct
colour per cel — red, blue, purple-red, blue-black) — visually a pulsing target-lock
reticle, not a palette reference. This is exactly the "render it and look" rule from
section 5 catching a guess that the byte statistics alone couldn't rule out.
`FindConstant.java` confirmed no code anywhere references cel index 1969, 1970, 1971, 1972,
or `0x44`-scaled CCB byte offset 1969*0x44 as a literal operand — whatever selects one of
these 4 per frame does so with a computed index (an animation-frame counter, most likely),
not a hardcoded per-frame call site, so this specific lead has no further code trail to
follow without a lot more searching. Team colouring itself remains fully open — see
section 4.

Full per-`PRE0` writeup and the mask-value verification data live in
`tools/rf_effect_cel.py`'s module docstring.

**Consequence for the converter:** `tools/convert_car.py` now extracts all 2165 cels
correctly — 2076 real sprites (the 2072 `PRE0==0` cels, plus the 4 `PRE0==17` cels, now
correctly reclassified) into `art_atlas.png`, and the 89 genuine coverage-mask cels
(`PRE0` in `{1,2,3,5,13}`) into a separate `art_effects.png` + `art_atlas.json`
(`"kind": "effect_mask"`, tagged with which table it uses; `PRE0` 3/4/5 masks now preserve
their real per-pixel byte value instead of being collapsed to 0/255, per the refinement
above). **There is no more missing/unrecovered sprite art in `ART.CAR`, and the exact
runtime tint mechanism for every effect mask is now fully understood** — reproducing it in
Godot is a shader/lookup-table implementation task, not an open RE question, though the
*visual* result still won't be pixel-identical without also porting the palette-matching
step (`GetNearestPaletteIndex` against the game's own realized palette).

`tools/rfcel.py` (the old literal-opcode decoder) is kept in the repo as a marked-superseded
investigative record rather than deleted, per section 5's standing lesson below, which this
whole detour is a direct instance of.

### 1.7 `.RFM` art id → `ART.CAR` cel mapping — SOLVED (2026-09-05): there is no mapping table, it's identity

This was open question #1 (section 4) and Phase 4 step 1's hard blocker: section 1.5 gives
every level tile a resolved 0-127 "art id"; section 1.6 fully classifies `ART.CAR`'s 2165
cels. Neither told you which cel is art id 42. **Answer: art id *is* the cel index.**
`ART.CAR`'s CCB array is loaded into memory unmodified at startup and indexed directly by
the tile's art id, times `sizeof(CCB)` — no separate lookup table, no indirection, nothing
built at load time. This was approach 2 from `docs/process/07-next-steps.md` (trace the
runtime tile buffer forward through rendering), not approach 1 (empirical guessing) — it
turned out to be findable and exact, so the empirical fallback was never needed.

**How this was found (anchor → xref → decompile, same recipe as every other finding here):**

1. Anchor: the runtime 128x128 tile buffer, `DAT_0046aa30`, whose address came for free out
   of the already-decompiled level loader `FUN_00414130` (section 1.5) — it's what the loader
   fills in as it resolves each raw tile byte to an art id.
2. `FindDataXrefs.java 0046aa30` found 21 functions touching it. One, `FUN_00408d60`, is the
   real per-frame terrain blitter (it computes camera-relative screen offsets and iterates
   the visible tile window every frame — clearly the renderer, not the loader). Inside it:

   ```c
   puVar7 = (uint *)((*puVar4 & 0x7f) * 0x44 + DAT_0044964c);
   puVar5 = (uint *)FUN_00413c90(local_a0);      /* same render-submission queue as section 1.6 */
   *puVar5 = *puVar7 & 0xbfffffff | 0x1000;
   puVar5[2] = puVar7[2];                        /* SourcePtr, copied straight from puVar7 */
   puVar5[3] = puVar7[3];                        /* PLUTPtr, copied straight from puVar7 */
   ```

   `*puVar4 & 0x7f` is exactly the art id (the tile's low 7 bits, per section 1.5).
   `0x44` is 68 decimal — `sizeof(CCB)`. So `puVar7` is `DAT_0044964c + art_id * sizeof(CCB)`:
   a plain C array of CCBs, indexed by art id, and the code just copies that CCB's
   `SourcePtr`/`PLUTPtr` into a fresh render-queue entry — the exact same submission path
   used for every other sprite in the game.
3. `FindDataXrefs.java 0044964c` on that array's base pointer found `FUN_00424950`, which
   opens `Art\ART.CAR` (string `s_Art_art_CAR_00449688`), reads the **entire file** into a
   single allocated buffer with `ReadFile`, and sets `DAT_0044964c = fileBuffer + 0x10`.
   `0x10` is exactly the 16-byte `ART.CAR` header (`"CCBA"` + filesize + count + dataoff,
   section 1.6) — so `DAT_0044964c` is not a copy, a rebuild, or a filtered subset. **It is
   the literal on-disk CCB array, loaded verbatim, with art id used as its index.** The level
   editor and the sprite artist were working against the same fixed cel numbering; there was
   never a translation step to reverse.

**Verified against every real file, not just the logic:** for all 104 art ids the 204 real
`.rfm` files actually use (section 1.5), the `ART.CAR` cel at that exact index
(`build/car/art_atlas.json`, `cels[art_id]`) is `kind: "sprite"` (never an effect mask),
`32x32`, `PRE0 == 0` — zero exceptions. Cel indices 0-111 (112 cels) turn out to be a single
uniform block: all `32x32`, all `PRE0 == 0`, all sharing one `PLUTPtr` (`0x282CC`), with
`SourcePtr` packed back-to-back at an exact 1024-byte (`32*32`) stride and no gaps — clearly
a deliberately laid-out terrain tileset, not a coincidence. Cel index 112 is the first break
in that pattern (`16x16`, a different sprite category) — every art id any real level uses
(max observed: 109) falls safely inside the uniform block, with 6 slots in range (92, 102,
105-108) apparently unused by any of the 204 levels in this install.

**Consequence:** no converter change is needed — `build/car/art_atlas.json`'s existing
`cels[n]` entry for `n == art_id` already *is* the answer, because the mapping function is
`f(x) = x`. Phase 4's terrain renderer should draw `art_atlas.json.cels[art_grid[i]]` for
each `.art.bin` cell directly, with no intermediate table to build or maintain.

### 1.8 Music playback: Redbook CD audio primary, `SOUND/Score.WAV` streaming fallback — SOLVED (2026-09-06)

Section 1.2 flagged this as unconfirmed: `WINMM.mciSendCommandA` is imported (suggesting
Redbook CD audio) and a 2.8 MB `SOUND/DRUMS.WAV` exists on disk (suggesting a local
fallback), but which one is actually music was never traced. Tracing every caller of the
`mciSendCommandA` import (`FindDataXrefs.java` on its IAT slot, `0048e804`) answers it
directly, and **DRUMS.WAV turns out to have nothing to do with it.**

**The mechanism is a single set of functions that plays either an MCI `cdaudio` device or a
locally-streamed WAV file through the same per-track offset table**, selected by whether an
MCI device handle (`DAT_0044145c`) is open:

- `FUN_004051c0(hwnd, track)` — "start track `track`." If `DAT_0044145c != 0` (a CD device is
  open), it calls `mciSendCommandA(DAT_0044145c, 0x806 /*MCI_PLAY*/, 0xc /*MCI_FROM|MCI_TO*/,
  &args)` with a from/to frame range read out of a 44-byte-stride per-track table
  (`DAT_004463d0`/`3d4`/`3d8`, indexed `track * 0x2c`) — i.e. it plays a specific track of a
  physical Redbook audio CD by frame range, the standard MCI `cdaudio` idiom. If
  `DAT_0044145c == 0` (no CD device), it instead calls `FUN_00403ef0`, which opens
  **`SOUND\Score.WAV`** (not `DRUMS.WAV`) through the **AVIFile streaming API**
  (`AVIStreamOpenFromFileA(..., 0x73647561 /* 'auds', the AVI audio-stream fourCC */, ...)`
  — Windows' AVI file handler transparently accepts a plain RIFF/WAV file here) and reads the
  *same* 44-byte-stride table's fields as **byte offsets into that one file** instead of CD
  frames. One track-boundary table, two playback backends.
- `FUN_00405360`/`FUN_004055d0` — stop/close: `mciSendCommandA(handle, 0x808 /*MCI_STOP*/,
  ...)` then `0x804 /*MCI_CLOSE*/`.
- `FUN_00405480` — a background thread that polls `mciSendCommandA(handle, 0x814
  /*MCI_STATUS*/, 0x100, &status)` every 200 ms; when the device reports stopped, it advances
  to the next track (`FUN_0040f600`) or, on the WAV path, calls `FUN_00403ac0` to keep
  streaming.
- `FUN_00405180` (called once at startup, `FUN_0041a400`) is a pure existence check —
  `OpenFile("SOUND\Score.WAV", ...)` then immediately closes it — and disables music
  entirely (clears both `DAT_0044145c` and the "music available" flag `DAT_00443008`) if the
  file is missing. It does **not** open the MCI `cdaudio` device itself; that happens
  earlier, elsewhere in startup, gated on whatever detects a real audio CD in the drive
  (not traced further — not needed to answer the question asked).

**`DRUMS.WAV` is unrelated to music.** `FindBytes.java` searched the entire binary for the
literal bytes `DRUM` and found zero hits — the game never references that filename by any
string, anywhere. Whatever `DRUMS.WAV` is for (a cut feature, a different build, sound
design scratch), it isn't loaded by `RFIRE.BIN`. This install's actual `SOUND\Score.WAV` is a
20-byte stub, not real audio data — consistent with the `.avi` cutscenes also being missing
from this install (section 1.2): the big copyrighted media assets were stripped from this
particular copy, while the small `.SDT`/`.RFM`/`ART.CAR` data files survived intact.

**Consequence:** a faithful port needs to reproduce a Redbook-CD-first, streamed-WAV-fallback
music system with a shared per-track boundary table — not just "load and loop an mp3." This
particular install has neither real CD audio nor a real `Score.WAV` (a 20-byte stub), but
**the real files are now available** — see section 1.11: the reference retail ISO carries a
full 222 MB `Score.WAV`. The *mechanism* (per-track start/end table driving either backend)
is fully understood and portable regardless of where the audio content ultimately comes
from. **The engine itself must never require a mounted CD** — the music/video importer
accepts ripped tracks as ordinary file-based pack inputs; see section 2.4.3 item 11 for the
hard requirement this becomes.

### 1.9 Native framebuffer resolution — SOLVED (2026-09-06); fixed sim tick rate — STILL OPEN

**Resolution: 320x240.** The game window's client size comes from two globals
(`DAT_00448d50`/`DAT_00448d54`) that `AdjustWindowRect` turns into the actual `CreateWindowExA`
size (`FUN_0041abe0`); tracing every write to `DAT_00448d50` finds its only hardcoded default,
in the command-line-argument parser (`FUN_0041a770`, run once at startup before any `-`
flags are applied): `DAT_00448d50 = 0x140; DAT_00448d54 = 0xf0;` — **320x240**, before any
`-2`/`-J`/`-Z` flag can override it. (The pause-screen code also switches between
`ART/PS240.RFA` and `ART/PS480.RFA` bitmaps depending on `DAT_00448d5c`'s display-mode value,
confirming the game supports at least a 320-class and a 640-class mode — 320x240 is the
default/base mode, not necessarily the only one an option flag can select.)

**Fixed sim tick rate: not found, and the evidence so far argues there may not be a classic
one.** Traced the actual per-frame call chain from `WinMain` (`FUN_0041eef0`): its message
loop's idle branch calls a function pointer that (once gameplay starts) is
`FUN_00421de0` → `FUN_004312c0`, which reads real wall-clock time from `timeGetTime()` and
passes it as a parameter into a small state-machine table (`PTR_PTR_0044e27c`, 0x14-byte
stride entries, each a `(table, frame_counter, elapsed_time_ms)` callback that returns
nonzero when that state is done and the table pointer should advance to the next entry).
No `Sleep()`, frame-rate cap, or fixed-`delta` accumulator was found anywhere in this call
chain — the main loop's only wait is a conditional `WaitMessage()` when the window isn't the
foreground app (`DAT_00448d08 & 2`). This is consistent with a game that paces itself off
`GetMessage`/vsync-driven redraw and hands each update stage the *real* elapsed milliseconds
rather than a fixed simulation quantum — but the specific state-table entry that does vehicle
physics hasn't been identified yet, so this isn't confirmed either way. **Next hop:** dump
`PTR_PTR_0044e27c`'s entries and find which one is the in-game (not title/menu) state, then
check whether *it* internally quantizes `elapsed_time_ms` into a fixed step.

**Update (2026-09-06): that next hop is done, and it's a dead end for a different reason than
[document 10](../process/10-worked-example-target-respawn.md)'s — not a wrong function, but
the wrong *system entirely*.** All three known writers of `PTR_PTR_0044e27c`
(`FUN_00431320`, `FUN_00431340`, `FUN_00431370`) were traced to their literal table
addresses (`0044e178`, `0044e218`, `0044e240`), and `DumpFunctionTable.java` dumped their raw
contents. Every entry resolves to one of a handful of functions (`FUN_00430da0`,
`FUN_00430e20`, `FUN_00430fb0`, `FUN_00431120`, `FUN_00430b10`) called with bitmap-name string
pointers and millisecond duration triples (`0x1f4`=500, `0x3e8`=1000, `0x9c4`=2500) —
classic fade-in/hold/fade-out timings for a slideshow. Combined with `FUN_00430b10`'s own
`TITLE_BanBL.bmp`/`TITLE_Win1.stm` string references (seen while tracing `timeGetTime`
callers), this is conclusively **the boot-time publisher/title logo slideshow, not
gameplay** — the `PTR_PTR_0044e27c` machinery this trace reached is real, but it's the wrong
system. It does, however, rule out one more candidate mechanism cleanly:
`FindSymbol.java SetTimer` finds **zero** references to `SetTimer` anywhere in the binary, so
the game definitely isn't using a `WM_TIMER` message for frame pacing either. Between this
and the earlier no-`Sleep()` result, two of the three classic Win32 fixed-interval mechanisms
are now ruled out; the remaining candidate is a blocking `IDirectDrawSurface::Flip` (vsync
wait) as the actual pacing mechanism, which — being a COM vtable call, not a named import —
needs a different search technique (find the `Flip` vtable-offset call the same way section
1.9's own `Lock()` call was identified by its vtable offset, then check the call site once a
level is actually running, not during the title sequence). Left open at this narrower,
more specific point rather than chased further this session.

### 1.10 Object rendering is real perspective-projected 3D, not 2D sprite-pivot rotation — SOLVED (2026-09-06)

The backlog's "implicit sprite pivots" question assumed the original renders vehicles as flat
2D sprites rotated around some anchor point baked into the cel art. Tracing the actual
per-object draw call chain (starting from `FUN_0042dd90`, found while chasing team colouring
in section 4) shows that assumption is wrong — **there is no 2D pivot concept in the
original's object rendering at all.** The engine does genuine (if simplified) 3D projection:

1. **64 discrete headings, each with a real 3x3 rotation matrix.** `FUN_0041ae50` (part of
   the same startup routine that builds `ART.CAR`'s translation tables, section 1.6) loops
   `iVar3` from 0 to `0x1000000` in steps of `0x40000` — exactly 64 steps around a full
   16.16-fixed-point circle — calling sin/cos-equivalents (`FUN_00410be0`/`FUN_00410dc0`) and
   `FUN_0041e770` to build a 3x3 rotation matrix (9 ints, 0x24-byte stride) per heading into
   `DAT_00481710`.
2. **A shared perspective (1/z) scale table**, also built by `FUN_0041ae50`:
   `scale[i] = focal_length / depth(i)` for a real division per table entry, not an
   approximation. `FindDataXrefs.java` on this table (`PTR_DAT_00449400`) shows it's read by
   *both* the terrain tile blitter (`FUN_00408d60`, section 1.7) and the object-quad
   projector below — terrain and objects share one perspective system, not two.
3. **Per-object quad projection** (`FUN_00413d00`, called from `FUN_0042dd90` and others): for
   each of an object's local-space 3D corner points, computes `screen_xy = (local_xy +
   camera_xy) * scale[depth >> 16] + screen_center`, where `scale[]` is table 2 above indexed
   by the point's transformed depth. This is textbook perspective-divide-via-lookup-table, a
   standard software-renderer trick to replace a division with a table read.
4. **The projected quad is applied through the CCB's own parallelogram-mapping mode, not a
   position+rotation+scale.** `FUN_00419820` (reached via `FUN_00436fb0`) sets a CCB flag bit
   (`|= 0x1000`) and writes all 4 of a CCB's corner-coordinate field pairs directly from 4
   selected projected points — this is the CCB "arbitrary quadrilateral" texture-mapping mode
   inherited from the original 3DO CEL engine (Return Fire shipped on 3DO before this Win95
   port), not a simple 2D blit position. The specific 4 points used per heading are picked by
   small integer indices stored alongside each heading's angle range in the same per-object
   facing-group table already documented in section 4's team-colouring lead
   (`FUN_0042dd90`'s `piVar7 + 2`).

**Consequence for the backlog question:** there's no fixed pivot offset to extract from the
cel art, because placement was never pivot-based — each pre-rendered directional sprite is
one *face* of a rotation, texture-mapped onto a quad whose 4 corners come from a real
per-frame 3D-to-2D projection of the object's (probably simple, box-like) local-space
geometry. **This is a real architecture decision for Godot, not just trivia:** reproducing
the original's exact visual behavior (vehicles subtly skewing/scaling with camera-relative
depth as they move, not just rotating flat) requires either (a) replicating this
projected-quad technique — a `Node2D` with a custom vertex-mapped `Polygon2D`/shader per
object instead of a plain `Sprite2D`, feeding it the same per-heading local geometry and a
ported perspective-scale table — or (b) deliberately accepting a simpler flat 2D
rotate-in-place approximation as a scoped-down visual target. Either is now an informed
choice; before this it was an unknown risk. See section 2.2 (Rendering).

### 1.11 Reference material obtained: retail PC ISO catalogued; 3DO expansion identified — 2026-09-05

The user supplied two disc images for reference, both outside the git repo
(`C:\Users\Alex\Documents\returnfire\`):

- **`RFIRE US.iso`** — the retail PC CD. Standard ISO9660 (`CD001` signature at sector 16);
  mounted read-only and catalogued in full. This is the disc the installed copy under
  `C:\Users\Alex\Documents\returnfire\` was missing pieces from:
  - **`Sound\Score.wav` is a real 222 MB file here** (vs. the 20-byte stub in the install)
    — directly usable to verify/complete section 1.8's music-fallback mechanism once
    ripped into a pack.
  - **`Sound\Drums.wav` is a real 2.8 MB file here too**, confirming it's a genuine shipped
    asset, not a phantom filename — but section 1.8's `FindBytes.java` result stands: the
    binary never references it by name. It's real, unused audio, nothing more.
  - **`Title\*.stm` files** (`rf.stm` 8.9 MB, `twi.stm` 2 MB, `win.stm` 20 MB, `win1/2/3.stm`,
    `prolific.stm` 2.8 MB) were the natural candidate for the "missing `.avi` cutscenes"
    guessed at in section 1.2. They are not video: every one starts with the same `auds`
    fourCC (`0x73647561`) at the same header offset as `Score.WAV`'s AVIFile-audio-stream
    trick (section 1.8), confirmed by checking 4 of the 6 files. **There is no cutscene
    video in this game at all** — `.stm` is just another named container for the same
    audio-streaming mechanism, most likely per-situation music/jingles (win themes, a
    "twilight" track, the publisher logo's stinger). Section 1.2 updated accordingly; no
    video codec work is needed anywhere in this project.
  - No Redbook audio track content is recoverable from this file — a `.iso` normally
    captures only the data track of a mixed-mode disc. If real CD-audio music is wanted,
    it needs to come from ripping the actual disc's audio tracks, not this image.
- **`Return-Fire-Maps-O-Death_3DO_EN/`** (`.bin`/`.cue`, `MODE1/2352`, one data track) —
  a genuine **3DO** disc image, not a PC one: the 3DO-exclusive expansion pack, never
  released for PC. Identified (not yet parsed) from sector 0's header, which matches the
  publicly-documented 3DO volume format: a sync/`ZZZZZ` marker, an ASCII `cd-rom` label,
  and the `duckiamaduckiama...` filler pattern 3DO's own disc-mastering tools pad unused
  directory blocks with. **This is a new goal (section 0), not a resolved item:**
  - The 3DO used its own filesystem (not ISO9660) and its own native asset formats — the
    CEL image format (already partially relevant, since `ART.CAR`'s CCB/CEL structures in
    the PC port are a direct descendant, per section 1.6's `CCB_BGND` cross-check against
    `trapexit/3doplay`), plus 3DO-native audio (likely SDX2/ADPCM-compressed `AIFF`-family
    sound) and whatever level-data format this expansion's maps use — almost certainly
    *not* the PC `.RFM` format, since this disc predates the PC port.
    Trapexit/3doplay is worth deliberately reusing as prior art for both the filesystem and
    CEL parsing.
  - No filesystem parsing or file listing has been attempted yet. Next concrete step: get
    (or write) a 3DO CD-ROM filesystem reader to enumerate the volume's actual files —
    `trapexit/3doplay`'s source is a plausible reference implementation to check before
    writing one from scratch, since section 1.6 already leaned on that project once. See
    section 4 for this as an open backlog item.
  - **Scope update (2026-09-05):** the user wants the base **3DO original game** disc
    supported alongside this expansion, not the expansion in isolation — they'll provide
    that disc image too, "when the time comes" (not yet in hand). This doesn't change the
    technical next step above; the base game and the expansion are the same platform, same
    filesystem, and almost certainly the same native asset formats, so whatever filesystem
    reader / CEL / audio / map-format work gets done for one directly serves the other. Treat
    "3DO extraction" as covering both discs once the second one arrives, not as two separate
    efforts.

## 2. Architecture decisions (decide once, up front)

### 2.1 The simulation must NOT live in Godot's engine types

**Load-bearing decision.** Implement the simulation as **fixed-point integer** code that is
isolated from Godot's engine types, and use Godot strictly for rendering, input, audio
and UI.

Rationale: the 3DO's ARM60 **had no FPU**, so the original simulation is near-certainly
fixed-point integer maths, carried into the PC port. A faithful reimplementation is
therefore **naturally deterministic**, which is what makes lockstep or rollback netplay
tractable. Most 90s remakes have to fight for determinism; here it is free unless you throw
it away.

**Write the simulation in GDScript, using integer arithmetic only.**

*This reverses an earlier draft of this plan, which recommended a C++ GDExtension or a C#
assembly. Both are wrong for this project, because of the web target:*

- **GDExtension is not supported in Godot 4 web exports.** A C++ simulation cannot ship
  to the browser.
- **C# / .NET has no web export in Godot 4** either.
- Therefore a native-language simulation would mean either abandoning web, or maintaining
  two implementations of the same simulation and keeping them bit-identical forever.

GDScript is fast enough here. This is a 1996 game: a 128 x 128 map with on the order of
tens of active entities at a fixed tick rate. The simulation load is trivial by modern
standards, and GDScript integers are 64-bit, so integer determinism holds.

**If** profiling later proves GDScript insufficient on desktop, a native implementation can
be added behind the same interface — integer algorithms *can* be made bit-exact across
languages, which is precisely why the integer rule matters. But do not start there, and
never ship two implementations without a cross-implementation determinism test.

**Rules for the implementer:**

- No `float` / `double` anywhere in simulation code. Fixed-point only (suggest Q16.16).
  In GDScript this means `int` everywhere, and never `/` where integer division semantics
  are unclear — write explicit helpers.
- No Godot `PhysicsBody`, `Area2D` collision, or `move_and_slide` for gameplay.
- No `randf()`. Use an integer PRNG seeded per match and advanced only on sim ticks.
- The simulation advances only on a fixed tick, driven explicitly — never from frame time,
  never from `delta`.
- Rendering interpolates between the last two sim states. Rendering never mutates sim state.
- Keep simulation code in its own directory with no Godot node imports, so it stays
  portable and unit-testable headlessly.

**Verify before building:** confirm GDExtension and .NET web-export status against the
Godot version actually being used. If GDExtension web support has shipped by then, the
tradeoff can be revisited — but the integer-only rule stands either way.

### 2.2 Rendering

**Use the Compatibility rendering backend** (WebGL2-class). Web export requires it, and
targeting it from day one avoids discovering late that an effect does not survive the port.

- Terrain: `TileMapLayer` built from the 128 x 128 `.RFM` grid.
- Sprites: `Sprite2D`, or `MultiMeshInstance2D` if unit counts justify it. **Decide up front
  whether to reproduce the original's projected-quad object rendering (section 1.10 —
  vehicles are real perspective-projected 3D quads with 64 discrete headings, not flat
  rotated sprites) or accept a simpler flat-rotation approximation.** The former needs a
  vertex-mapped `Polygon2D`/shader per object fed the ported per-heading local geometry and
  perspective table, not a plain `Sprite2D`; the latter is simpler but visibly diverges from
  the original's subtle depth-skew look. Pick one before building the vehicle-rendering step
  (Phase 4 step 2) — retrofitting later means redoing every vehicle's rendering path.
- Split-screen: one `SubViewport` per player inside `SubViewportContainer`s. The original
  only ever needs 2 (section 0's 4-player goal, section 4 item 8); design the
  `SubViewportContainer` grid to scale to 4 from the start (e.g. a 2x2 grid that collapses to
  a 1x2 split for 2 players) rather than hardcoding a 2-way layout and retrofitting later.
- Palette: bake to RGBA8 at conversion time, or keep indexed and apply the palette in a
  fragment shader if palette-cycling or team-colour swapping turns out to need it.
  Any such shader must be WebGL2-compatible — **no compute shaders, no storage buffers**.

### 2.3 Widescreen warning

Widescreen **materially changes balance** — seeing more of the map is a competitive
advantage, it affects split-screen fairness, and the original AI may assume what is
on-screen. Implement authentic 4:3 with pillarboxing as a selectable option alongside
widescreen; do not ship widescreen only.

### 2.4 Asset abstraction: original files and replacement packs are equal citizens

**The engine must never read `.RFM` / `.CAR` / `.RFA` / `.SDT` at runtime.** Converters
produce an open, documented **content pack**; the engine reads only content packs. The
1996 data becomes just one pack among others, produced by an importer.

```
   original retail files ─┐
                          ├─► [converters] ─► CONTENT PACK ─► [engine]
   hand-authored source ──┘                   (open format)
```

This is what makes a full art replacement possible, and it must be designed in from the
start — retrofitting it later means rewriting every asset reference in the codebase.

#### 2.4.1 The asset ID registry — the gating deliverable

The engine must reference art by **stable semantic ID** (`vehicle.helicopter.rotor.f03`,
`terrain.water.edge.ne`, `ui.hud.fuel_gauge`), never by cel index. So there must be a
canonical registry mapping **all 2165 cels** to semantic IDs.

**This registry is the single thing that makes replacement art possible.** Without it, an
artist looking at cel 1427 has no idea what they are being asked to draw. Producing it is
genuine classification work — partly automatable by clustering cels by size and by
adjacency in the file (animation frames are contiguous), but it needs human or in-game
verification.

Store as `packs/registry/asset_ids.json`, version it, and treat additions as a semver
minor bump and removals as a major bump.

#### 2.4.2 Content pack layout

```
mypack/
  pack.json            manifest: id, name, version, engine_api_version, author,
                       license, base_pack (or null), overrides []
  sprites/
    *.png              atlas pages, or loose frames
    sprites.json       id -> { page, x, y, w, h, pivot_x, pivot_y }
  animations.json      id -> { frames [], durations [], loop, facings }
  terrain/
    tileset.png
    tileset.json       tile_id -> { region, terrain_class, autotile_rules }
  audio/
    *.ogg / *.wav
    audio.json         id -> { file, category, loop_start, priority }
  fonts/
    *.png + fonts.json glyph -> region, advance, kerning
  ui/
    layouts.json       resolution-independent anchors, 9-slice regions
```

#### 2.4.3 Requirements a replacement pack must satisfy

These are the design constraints that must be honoured *now*, in the engine, or custom art
will be impossible later:

1. **Resolution independence.** The engine works in **world units**, never pixels. Each
   pack declares `pixels_per_world_unit`. The original pack declares the 1996 value; a 4x
   HD pack declares 4x that and everything else just works. If the engine hardcodes
   32-pixel tiles anywhere, HD replacement is dead.
2. **Declared pivots.** Every sprite needs an explicit origin/pivot in world units.
   Original cels are drawn against fixed-size cells whose implicit pivot must be recovered;
   replacement art has different bounds and must state its own.
3. **Team colouring.** Return Fire has two teams. Determine how the original does it —
   palette index ranges swapped at draw time, or separate cels per team. A replacement pack
   must declare its mechanism: either `team_palette_range: [lo, hi]` on an indexed sprite,
   or a separate team-mask texture (preferred for modern art). Support both.
4. **Animation timing in ticks, not frames.** Durations expressed in simulation ticks so
   uncapped framerate and netplay stay correct.
5. **Gameplay footprint is pack-independent.** Collision extents, weapon mount offsets and
   hitboxes live in **gameplay data**, not in the art pack. Art may not change gameplay —
   otherwise a replacement pack silently rebalances the game and desyncs netplay.
6. **Partial packs must layer.** A pack declares `base_pack` and overrides only the IDs it
   supplies, so someone can replace just the vehicles.
7. **Every ID must be optional-checkable.** Ship `tools/validate_pack.py` reporting missing
   IDs, unknown IDs, absent pivots, malformed regions. A third-party artist needs this to
   work without reading engine source.
8. **Pack identity in the netplay hash.** The pack id + version must be part of the
   determinism / session handshake so mismatched packs are rejected at join rather than
   desyncing mid-match. Art-only differences may be permitted; gameplay-data differences
   must not be.
9. **Web-deployable.** Every pack declares a size budget and supports lazy loading of
   per-level and per-screen assets, because the web build downloads what it ships. See
   section 2.5.3. A pack that only works as one monolithic blob cannot go to the browser.
10. **No pack may require a native dependency.** Formats must be ones Godot can load in a
    web build (PNG, Ogg, JSON). No pack-supplied executables, shaders outside WebGL2, or
    platform-specific codecs.
11. **CD independence.** The original needs a physical/virtual Redbook audio CD for music
    (section 1.8) — the engine must never require one at runtime. The music importer must
    accept **files** (ripped audio tracks as WAV/OGG) sourced from the user's own copy of
    the game — CD, ISO, or digital release — as a first-class pack input, exactly like
    every other asset type. A user who owns the game but doesn't want to keep a disc
    mounted must have a fully working, file-based pack. (There is no cutscene video to
    worry about — section 1.11 ruled that out entirely.) The reference retail ISO is now on
    hand (section 1.11) with a real `Score.WAV` to test this against once a pack importer
    exists; Redbook track content itself would still need ripping from the physical disc's
    audio tracks, which a `.iso` file doesn't capture.

#### 2.4.4 Authoring aids to ship

- **Contact-sheet exporter** — renders every registry ID with its name and pivot, so an
  artist has a visual specification of what to draw.
- **Template pack** — a complete pack of placeholder art at correct dimensions and pivots,
  as a starting skeleton.
- **Hot reload** — reload a pack without restarting, or iteration is unbearable.
- **Pack diff** — compare a pack against the registry and against another pack.

### 2.5 Web export constraints

Godot exports to the browser, but the browser removes capabilities the desktop build takes
for granted. Each item below is a decision that must be made *now*, not at export time.

#### 2.5.1 There is no filesystem to point at

The desktop first-run flow ("show me your `returnfire` install") **cannot work on the
web**. There is no install directory to browse.

**Consequence: the web build must ship a complete, original-free content pack.** This is
not a limitation to work around — it is exactly the model that makes a public web build
legally clean, and it is why the asset ID registry (section 2.4.1) is on the critical path
to web, not a side quest.

Two optional extras, neither of them the default:

- A browser file-picker that accepts the user's own `ART.CAR` / `.RFM` files and converts
  them **client-side**, so a user with the retail game can play their own data in the
  browser. This requires the converters to exist in a form the web build can run — either
  reimplemented in GDScript, or compiled to WASM. Nice to have; do not let it drive design.
- Keep original-asset web builds private/unlisted if ever made at all.

#### 2.5.2 Language and threading

- **GDExtension (C++) and C# have no Godot 4 web export.** This is why the simulation is
  GDScript. See section 2.1.
- **Threads require `SharedArrayBuffer`**, which requires the page to be served
  cross-origin isolated (`COOP: same-origin`, `COEP: require-corp`). Many static hosts
  cannot set these headers. **Assume a single-threaded web build** and never make the
  simulation depend on threading. Note the header requirement in deployment docs.

#### 2.5.3 Download size is a hard design constraint

A web build downloads everything before play. Desktop does not care about a 200 MB pack;
the web does.

- Give each pack a **declared size budget** and have `validate_pack.py` enforce it.
- The pack format must support **splitting and lazy loading** — per-level terrain and
  per-screen UI art loaded on demand, not one monolithic blob. Design this into
  `pack.json` from the start; retrofitting lazy loading means re-cutting every atlas.
- Prefer a small number of large atlas pages over thousands of loose files: HTTP request
  count matters more than raw bytes on some hosts.
- Budget audio aggressively. Ogg Vorbis, mono where the original is mono.

#### 2.5.4 Netplay transport must be abstracted

Browsers cannot open raw UDP sockets, so **ENet is unavailable on the web**. Web netplay
must use WebRTC (peer-to-peer, needs a signalling server) or WebSockets (needs a relay).

**Therefore: define a transport interface in Phase 5 and implement it twice** — ENet for
desktop, WebRTC or WebSocket for web. Lockstep works fine over all three. Do not write
ENet calls directly into the netcode; that mistake is invisible until the first web build.

Cross-play between desktop and web is then possible, but only if both sides run bit-exact
simulations — another reason the integer rule in section 2.1 is absolute.

#### 2.5.5 Miscellaneous browser behaviour

- **Audio requires a user gesture** before it can start. Needs a click-to-start screen.
- **Saves go to IndexedDB** via `user://`, and can be wiped by the browser. Do not assume
  persistence; offer export/import of save data.
- **Gamepads** work via the browser Gamepad API but only after a button press, and mapping
  differs from desktop. Keyboard must remain a complete control scheme.
- Fullscreen and pointer lock require user gestures too.

---

## 3. Execution phases

### Phase 0 — Repo setup

1. Godot 4 project at `C:\Users\Alex\Documents\code\returnfire-godot`, separate from data.
2. Structure:
   ```
   /tools/            Python converters + pack validator (Phase 1 lives here)
   /src/              GDExtension simulation code
   /game/             Godot scenes, scripts, shaders
   /packs/            content packs + the asset ID registry
   /docs/             this plan + format notes as refined
   /build/            converter output — GITIGNORED
   ```
3. `.gitignore` must exclude `/build/`, every converted asset, and any copy of original data.
4. First-run flow asking the user to point at their `returnfire` install.

### Phase 1 — Asset pipeline (Python, offline)

**1a. `.SDT` → WAV — DONE.** `tools/convert_sdt.py`. 40/40 converted, all validated PCM.

**1b. `.RFA` → PNG — DONE.** `tools/convert_rfa.py`. 16/16 converted. Reads `bfOffBits`;
handles 4bpp and non-256 palettes.

**1c. `ART.CAR` → atlas + manifest — DONE for all 2165 cels.** `tools/convert_car.py`.
2076 unpacked cels (the 2072 with `PRE0==0`, plus 4 with `PRE0==17` that looked like masks
at first but turned out to be ordinary sprites with their own embedded palette) packed into
a 2048x2048 atlas + `art_atlas.json`; output visually verified as correct sprite art. **The
remaining 89 (`PRE0` in `{1,2,3,5,13}`) are not sprites — decompiling the real renderer in
Ghidra (Phase 2) confirmed they are coverage masks for a masked palette-translation blend
effect** (colour tints, glow gradients, shadows — the exact tint mechanism for each is now
fully understood, section 1.6), extracted separately into `art_effects.png`
(`tools/rf_effect_cel.py`, replacing the earlier `tools/rfcel.py` guess, which rendered as
noise and was correctly rejected rather than shipped — see section 1.6 for the full
correction). Cross-checked against all 93 real non-zero-`PRE0` cels with zero exceptions.

**1d. `.RFM` → tilemap + entity JSON — DONE.** `tools/convert_rfm.py`. 204/204 real files
converted with zero failures. Per level, emits `<name>.json` (chunk metadata, resolved
`VHCL` params with their source per field, spawn points, candidate pools), `<name>.tiles.bin`
(raw width*height tile bytes, entity cells zeroed to 0), `<name>.art.bin` (the resolved
render-ready art id per cell -- see below), and `<name>.debug.png` (false-colour terrain by
art id + entity markers, for visual sanity-checking rather than trusting the numbers alone
-- this is what caught that "Campgrounds Of America" is a uniform grid of 160 evenly-spaced
`0xDC` candidate markers, which makes perfect thematic sense and was a good confirmation the
extraction is correct, not a bug; the art-id-coloured render also newly reveals a distinct
road/path terrain class connecting those camping spots that the earlier raw-byte grayscale
render didn't make visible).

Totals across all 204 files (all consistent with section 1.5's per-file findings): 204 team-0
spawn points (one each, no exceptions), 104 team-1 spawn points (exactly the 2-player files),
641 pool-A candidates, 1560 pool-B candidates. Decoded `NAME` strings were spot-checked
against the source filenames already known from section 1.2/1.5 (`"The Cakewalk"`,
`"Driving School"`) and matched exactly.

**Also done: resolving all raw terrain tile values into semantic/render art ids** (was the
open question in section 4 as "classify the ~94 plain-terrain tile values", turned out to
cover all 240 raw values, not just the plain ones). `tools/rf_tile_art.py` implements the
static two-table pipeline reverse-engineered from `FUN_00414130`/`FUN_0042e4f0` (full
writeup in section 1.5); `tools/data/tile_lookup_tables.json` holds the dumped tables.
Cross-checked against all 204 real files: zero grid cells fail to resolve to an art id, and
the 104 art ids the tables predict are exactly the 104 art ids real levels actually use.
This is a pure lookup, not a guess -- **Phase 3/4 rendering should consume `.art.bin`, not
the raw `.tiles.bin` bytes**. The art id IS the `ART.CAR` cel index directly (section 1.7,
verified 2026-09-05) -- render `art_atlas.json.cels[art_id]`, no separate mapping needed.

**1e. Asset ID registry + pack emitter — NOT STARTED.** Convert the raw atlas manifest into
a semantic registry (section 2.4.1) and make the converters emit a proper content pack
rather than a flat atlas. **Do this before Phase 4** — the engine must consume packs from
its first line of asset-loading code.

**Validation gate:** a standalone viewer that renders any level's terrain grid using real
tile art, and plays any sound. Do not start Phase 3 until this looks right.

### Phase 2 — Ghidra project + reference capture

**Toolchain is installed and verified (2026-09-04), outside the repo (not version
controlled, not part of the game data — pure local tooling):**

```
C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1\      Temurin JDK 21 (Ghidra 12.1.3 requires it)
C:\Users\Alex\Documents\code\tools\ghidra_12.1.3_PUBLIC\  Ghidra 12.1.3
C:\Users\Alex\Documents\code\tools\ghidra_projects\       Ghidra project dir; `returnfire` project has
                                                            RFIRE.BIN imported, with full auto-analysis
                                                            already run (2026-09-04, 29s, no errors)
```

**`ghidra_projects\` must stay outside this repo, permanently, on purpose.** It contains
Ghidra's analysis database for `RFIRE.BIN` -- effectively a disassembled/decompiled copy of
the copyrighted game binary. This is exactly the "never commit decompiled game code
verbatim" rule from section 0. The scripts in `tools/ghidra_scripts/` (below) are fine to
version -- they're original analysis code, not decompiler output.

- `JAVA_HOME` is set persistently for the Windows user account, and
  `ghidra_12.1.3_PUBLIC\support\launch.properties` has `JAVA_HOME_OVERRIDE` pointing at the
  JDK above -- both needed because Ghidra's launcher requires a bootstrap `JAVA_HOME` before
  it even reads its own config. A **new** terminal window picks up the persisted user env var
  fine. If a stale shell doesn't see it, `ghidra_12.1.3_PUBLIC\run_ghidra.bat` sets it inline
  before launching, or just `$env:JAVA_HOME = "...\jdk-21.0.12.1+1"` first.
- GUI: `ghidra_12.1.3_PUBLIC\ghidraRun.bat` (or the wrapper above). No tool here can drive a
  native GUI window -- if the executing agent is an AI agent without a human at the keyboard,
  **use the headless analyzer, not the GUI**, for anything scriptable:
  `ghidra_12.1.3_PUBLIC\support\analyzeHeadless.bat <project_dir> <project_name> [-import <file> | -process] [-postScript <script> ...] [-scriptPath <dir>]`.
  Jython is **not** bundled in this Ghidra version (only PyGhidra/Python3, and only Java
  `GhidraScript`s are guaranteed to work headlessly without further setup) -- write scripts
  in Java, they compile on the fly.

**Reusable scripts already written, version-controlled at `tools/ghidra_scripts/` in this
repo.** Pass `-scriptPath "C:\Users\Alex\Documents\code\returnfire-godot\tools\ghidra_scripts"`
(or wherever this repo is checked out) to use them:

- `FindRfmStrings.java` — finds every string matching Return Fire format markers (`.rfm`,
  `art.car`, `retfire.ini`, etc.), lists cross-references, and decompiles every referencing
  function. Good first move in a fresh investigation.
- `FindCallers.java <hexAddr>` — given a function's entry point, lists and decompiles every
  caller, and separately scans the whole program for functions that call both a file-open
  and a file-read API (candidate loader functions).
- `DecompileOne.java <hexAddr>` — decompiles one function plus its immediate callers and
  non-external callees. The main workhorse for walking a call graph one hop at a time.
- `FindConstant.java <hex32>` — scans every instruction for a scalar operand equal to a
  given 32-bit immediate (e.g. a packed 4-character magic). Fast, but misses constants
  loaded from memory rather than used as an immediate.
- `FindBytes.java <hexBytes>` — scans raw program bytes (regardless of whether Ghidra has
  them marked as code/data/undefined) for a literal byte sequence, and lists cross-references
  to every hit. **Prefer this over `FindConstant.java`** for magic-number/string hunting --
  it's what actually found the `.RFM` chunk tags (see section 1.5); the scalar-operand search
  found nothing for the same bytes.
- `DumpStringAt.java <hexAddr> [byteCount]` — hex+ASCII dump of raw bytes at an address, for
  reading small data tables / string constants directly.
- `DumpFunctionTable.java <hexAddr> <count>` — reads `count` 4-byte little-endian pointers
  starting at an address and decompiles whichever land on a recognized function. For
  jump/dispatch tables. Watch for the table running into adjacent unrelated data (as
  happened at `0x00448810` -- it's only 2 entries before the chunk-tag string table begins).
- `ForceDecompile.java <hexAddr>` — disassembles and force-creates a function at an address
  Ghidra didn't already recognize as one, then decompiles it. Needed for functions only
  reachable via an indirect/computed call (e.g. through a function-pointer table) --
  static analysis often doesn't find these on its own.
- `DecompileMany.java <hexAddr> [hexAddr...]` — decompiles a flat list of functions with no
  caller/callee expansion, unlike `DecompileOne.java`. Use for surveying many candidate
  functions at once (e.g. every function referencing a given global) without an
  exponential-blowup log.
- `FindDataXrefs.java <hexAddr>` — like `FindCallers.java` but for a DATA address: lists
  every cross-reference to a global variable and decompiles each unique referencing
  function. Essential for tracing a global (a queue pointer, a lookup-table base) forward
  to find every place it's read or written, not just one function's call graph.
- `FindImportCallers.java <substring>` — finds every function/import whose name contains
  the given substring and decompiles every caller. Note: a Win32 API called only through
  an IAT slot doesn't show up as a `Function` at all in Ghidra's function manager (only as
  a `Data`/`Label` symbol for the IAT slot) -- if this finds nothing, fall back to
  `FindSymbol.java` to find the IAT slot's address, then `FindDataXrefs.java` on that.
- `FindSymbol.java <substring>` — case-insensitive substring search over ALL symbols
  (functions, labels, data), not just functions. Use this first when hunting for a Win32
  API by name; it will find the `PTR_<Name>_<addr>` IAT-slot label even when
  `FindImportCallers.java` finds no matching `Function`.

1. ~~Run full auto-analysis on the imported `RFIRE.BIN`~~ **DONE** (2026-09-04, 29 seconds,
   no errors). Re-run `-process RFIRE.BIN` without `-import` or `-noanalysis` if analysis
   ever needs redoing (e.g. after a Ghidra version upgrade). FLIRT signatures were not
   separately applied — MSVC 4.x CRT code is a minor readability cost, not a blocker; revisit
   only if it's getting in the way.
2. Anchor on known strings and imports:
   - `%sWorlds\%s\%s\*.rfm` → **DONE, this settled the whole `.RFM` container format** —
     see section 1.5. Still open within that: the tile-value → function-pointer dispatch
     table (likely object placement) and the undecoded header body.
   - `DirectDrawCreate` call site → surface lock and blit → framebuffer format, native
     dimensions, and the team-colour / palette mechanism (section 2.4.3 item 3). **Not yet
     done.**
   - `joyGetPosEx` / `GetKeyboardState` → input mapping and control scheme. **Not yet done.**
3. Get the original running under a DirectDraw wrapper (`cnc-ddraw` or `dgVoodoo2` dropped
   beside `RFIRE.BIN`) as a **side-by-side reference**. Run `RFIRE.BIN` directly; do not
   use `RUNME.EXE`, do not run `DXSETUP.EXE`.

### Phase 3 — Extract gameplay constants (targeted RE, NOT a full decompile)

Extract only what cannot be guessed or tuned by feel:

- Vehicle handling: acceleration, max speed, turn rates, fuel burn per tick, per vehicle
  type (helicopter, tank, support/jeep, armoured car).
- Weapon damage, rate of fire, ammo capacity, projectile speed.
- Building and target hitpoints, destruction rules.
- Scoring and mission completion conditions.
- AI state machines and target selection.
- The fixed simulation tick rate.

Record each in `/docs/constants.md` with the address it came from. These become **gameplay
data**, kept separate from art packs (section 2.4.3 item 5).

### Phase 4 — Godot implementation

Keep each step playable, and load everything through the pack layer from step 1:

1. Load a level, render terrain + static objects.
2. One player-controlled vehicle with authentic movement.
3. Camera, scrolling, split-screen viewports.
4. Weapons and projectiles.
5. Destructible targets and buildings.
6. Enemy AI.
7. Mission objectives, scoring, level progression.
8. Audio: SFX and music.
9. Menus and HUD.

### Phase 5 — Netplay

Deferred until the simulation is complete and provably deterministic.

1. Determinism test: run the sim N ticks from a fixed seed and input log on two platforms;
   assert identical state hashes. **Make this a CI check, and include a web build in it** —
   desktop-only determinism testing will not catch a browser-only divergence.
2. **Define a transport interface first, before any netcode.** Implement ENet for desktop
   and WebRTC or WebSocket for web behind it. Browsers cannot open raw UDP sockets, so
   writing ENet calls directly into the netcode silently forecloses web multiplayer.
   See section 2.5.4.
3. Lockstep with input delay first — simple and sufficient to start with, and it works
   over all three transports. Lockstep itself generalizes to 4 participants without a
   redesign; just don't let the session/handshake code (or the split-screen viewport count,
   section 2.2) quietly assume exactly 2 (section 0's 4-player goal, section 4 item 8).
4. Rollback (GGPO-style) only if input latency proves unacceptable.
5. Pack id + version in the session handshake (section 2.4.3 item 8).

### Phase 6 — Platform targets

Godot exports Windows, Linux, ARM and web natively. The work is confirming the determinism
test passes on all of them — this is where a stray `float` will finally bite.

**Do not leave the web build until last.** Produce a web export as soon as anything is
playable (Phase 4 step 2), even if it is one vehicle on an empty map, and keep it building
from then on. Every constraint in section 2.5 fails silently on desktop and only surfaces
in the browser; discovering them at the end means reworking the simulation language, the
netcode transport and the pack layout simultaneously.

Web checklist:

- Compatibility rendering backend, no compute shaders.
- Ships a complete original-free content pack (section 2.5.1).
- Single-threaded, or documented `COOP`/`COEP` hosting requirements (section 2.5.2).
- Within its declared download budget, with lazy loading working (section 2.5.3).
- Click-to-start screen for audio; keyboard is a complete control scheme.
- Save export/import, since IndexedDB can be wiped.

---

## 4. Open questions

1. **What ends a match?** The per-pool target-replacement budgets (section 1.5) are fully
   traced, but nothing touching those two globals declares a win/lose state. The most
   obvious next hop, `FUN_0042c4d0`, was checked and **ruled out** (2026-09-06) — it's a
   generic object-death utility called from 35+ unrelated sites, not a win-condition
   trigger. The trail from there runs into a large general AI-targeting/combat subsystem
   with no clear "declare victory" anchor; left open rather than chased further without one.
2. The coastal table's (`0x00447038`) `+9` "height_seed" byte and the runtime tile value's
   elevation-ish bits 25-27, set by `FUN_0042e4f0` — dumped but not chased; likely
   physics/movement, not rendering (section 1.5). (Bits 14-15 are no longer part of this
   question — see RESOLVED below.)
3. The two small constant `.RFM` header fields `0x04`-`0x07` (`"TM\0\x05"`) and `0x0C`-`0x0D`
   (`01 01`) — confirmed constant across all 204 real files, exact meaning still a guess
   (section 1.5). Very low priority.
4. Purpose of the `count * 8` byte table at `ART.CAR` offset `0x23F24`.
5. **How is team colouring done?** Palette ranges or separate cels? Still fully open. The
   "4 `PRE0==17` cels are a team-colour swatch" lead from section 1.6 is now **RULED OUT
   (2026-09-06)**: rendered and eyeballed (per section 5's own rule — never trust code
   alone), the 4 cels are visibly a 16x16 concentric-ring bullseye (purple/black/yellow, one
   ring recoloured red/blue per cel) — a target-lock reticle, not a colour swatch. `FindConstant.java`
   found no literal reference anywhere in the binary to any of their 4 cel indices (1969-1972)
   or the equivalent CCB byte offset, consistent with an animated HUD overlay whose frame
   index is computed at runtime rather than hardcoded per-frame. The
   `GetNearestPaletteIndex`-built masked-translation-table infrastructure (section 1.6) is
   still a plausible *mechanism* for team colouring, but there is no lead left pointing at
   *where* it's invoked for that purpose — needs a fresh anchor, most likely starting from
   wherever a vehicle's CCB is queued for the frame (candidate entry points seen so far:
   `FUN_0042dd90`, which does directional-sprite-frame selection off a heading angle and
   indexes the same `ART.CAR` CCB array, but that trace didn't reach a team/owner field).
   Blocks section 2.4.3.
6. **The fixed sim tick rate** (section 1.9) — resolution itself is solved (320x240), but
   whether there's a classic fixed-Hz simulation quantum is still open. `PTR_PTR_0044e27c`'s
   state-machine table, the trace's first destination, is **ruled out (2026-09-06)**: all 3
   of its known table addresses dump to boot-time logo/slideshow functions (bitmap names +
   fade-timing triples), not gameplay. `SetTimer` also has zero references anywhere in the
   binary, ruling out a `WM_TIMER`-based tick too. Next hop: find the actual
   `IDirectDrawSurface::Flip` vtable call site (same technique as finding `Lock()` by its
   vtable offset, section 1.9) and check whether it blocks for vsync during real gameplay —
   that's the remaining candidate pacing mechanism.
7. **3DO support: base game + "Maps o' Death" expansion extraction** (section 1.11, new
   2026-09-05; scope widened 2026-09-05) — a whole new goal, not a single question, and
   deliberately scoped to cover **both** 3DO discs together rather than the expansion
   alone, since the user wants the base 3DO original supported too (its disc image is
   promised but not yet provided; the expansion's is already in hand). The expansion disc
   image is identified as a genuine 3DO CD but not yet parsed at all. Next concrete step:
   get or write a 3DO CD-ROM filesystem reader (check `trapexit/3doplay` first, already
   used as prior art in section 1.6) to enumerate the volume's real files, then identify
   whatever native map/CEL/audio formats this PC-never-released material actually uses —
   expect them to differ substantially from the PC `.RFM`/`ART.CAR`/`.SDT` formats
   documented elsewhere in this file. Whatever reader/format work happens here should be
   written generically enough to also read the base game disc once it arrives, since both
   are the same platform and (almost certainly) the same asset formats.
8. **4-player support** (section 0, new 2026-09-05) — a whole new goal, not a single
   question: the original engine is 2-player only, so there's no decompiled logic to trace
   here, just a design decision to make and thread through. Every real `.RFM` file defines
   exactly one team-0 and one team-1 spawn (section 1.5) and nothing else, so the original's
   own 204 maps have no data-level room for a 3rd/4th spawn point. Two ways to reconcile
   that, not yet decided between: (a) synthesize extra spawns for the original maps
   algorithmically (e.g. offset from the existing team-1 spawn) so they remain playable at 4,
   or (b) treat 4-player as available only to custom/replacement map packs (section 2.4)
   where the author places all 4 spawns explicitly, and leave the original's maps at their
   native 2-player cap. Also touches the split-screen viewport layout (section 2.2) and the
   netcode session/handshake design (section 3 Phase 5) — both should be built assuming up to
   4 participants from the start rather than retrofitted from a 2-player assumption.

**RESOLVED:**
- **The "missing `.avi` cutscenes"** — **section 1.11** (2026-09-05). There never was
  cutscene video to find: the reference retail ISO's `Title/*.stm` files, the obvious
  candidate, all open with the same `auds` AVIFile fourCC as `Score.WAV` (section 1.8) —
  they're more streamed audio, not video. Section 1.2's video bullet corrected; no codec
  work needed.
- **"Implicit sprite pivots"** — **section 1.10** (2026-09-06). The premise was wrong: there
  is no 2D pivot to extract. Object rendering is real perspective-projected 3D — 64 discrete
  headings each with a precomputed 3x3 rotation matrix, a shared 1/z perspective-scale table
  (also used by the terrain blitter), and per-object local-space corner geometry projected
  to screen space and quad-mapped onto the CCB's own arbitrary-parallelogram texture-mapping
  mode. Reframes this from a data question (extract a pivot value) into an architecture
  decision for section 2.2 (reproduce the projected-quad technique, or accept a flat
  2D-rotation approximation).
- **Native framebuffer resolution** — **section 1.9** (2026-09-06). 320x240
  (`DAT_00448d50 = 0x140`, `DAT_00448d54 = 0xf0`), the command-line parser's hardcoded
  default before any override flag is applied. (The fixed sim tick rate half of this same
  backlog item is still open — see section 1.9 and the open-questions list above.)
- **Music playback mechanism** — **section 1.8** (2026-09-06). Both, not either/or: an MCI
  `cdaudio` device (`mciSendCommandA`) plays specific Redbook track frame-ranges when a real
  audio CD is present, falling back to streaming `SOUND\Score.WAV` (via the AVIFile
  streaming API, not raw waveOut) through the *same* per-track boundary table when it isn't.
  `SOUND/DRUMS.WAV` — the file this question used to name as the likely fallback — turned out
  to be a red herring: `FindBytes.java` found the string `DRUM` nowhere in the binary at all.
- **The `.RFM` header body, offsets `0x0E`-`0x25`** — **section 1.5**. A DOS-format
  created/modified timestamp pair (`0x0E`-`0x15`) and a 15-byte null-padded level
  author/designer name field (`0x17`-`0x25`, defaulting to `"Unknown"`), found purely
  empirically (per-offset byte variance across all 204 real files, no Ghidra needed) and
  verified rigorously: every one of the 204 files' timestamps decodes to a sane 1994-1996
  date with zero failures, and the author field turned up real human names (`MichaelAngelo`,
  `John L. Saleigh`, `Van`, and others) — the actual level designers' credits, still sitting
  in the shipped data. Also resolves the long-standing "offset 0x18 string, not
  re-examined" loose end: the real field starts at `0x17`, and it's unrelated to the `NAME`
  chunk (that's the level's displayed title; this is who built it). Also confirmed none of
  the 204 real files have the offset-`0x40` "enabled" byte unset.
- **The `EDTN` chunk tag** — **section 1.5**. Confirmed unused by the game itself, not just
  unidentified: `RFIRE.BIN`'s loader contains exactly 3 chunk-tag comparisons in its entire
  body (`VHCL`, `NAME`, `LEVL`, each dumped and read directly from its data segment) and no
  fourth. Any tag it doesn't recognize is skipped by record length alone. Round-tripping
  `EDTN` opaquely (already done) isn't a shortcut — it's exactly what the original engine
  itself does with it.
- **The `>>1` "half the candidate-pool count" computation** — **section 1.5**. Each pool's
  budget for how many *replacement* targets it will spawn over a match (not a literal
  "destroy half simultaneously" count). Traced end-to-end: `FUN_00432710` (destruction
  handler) decrements the destroyed tile's pool's budget and, if it was the active target,
  calls `FUN_00432600` to randomly activate a new one from the pool's remaining candidates —
  a rotating single-target-per-pool spawner. Also corrects an earlier guess: runtime tile
  value bits 14-15 are the pool-membership tag, not "orientation-ish."
- **Exact runtime tint colour of `ART.CAR`'s effect-mask cels** — **section 1.6**. Fully
  traced: what the 4 shared translation tables contain and how `FUN_00424420` builds them
  (a `GetNearestPaletteIndex`-driven average-blend table, a 32-level darken table, a 32-level
  brighten table, and 2 fixed rows of the darken table used as constant shadow strengths),
  and the exact per-`PRE0` formula each of the 3 mask-blit routines uses — including the
  refinement that `PRE0` 3/4/5's mask byte VALUE (not just coverage) selects a tint colour
  or brightness level, confirmed against real mask data. Also discovered along the way:
  `PRE0==17` is not a mask at all, just an ordinary sprite with its own embedded palette —
  `tools/convert_car.py` now extracts it as a real sprite, resolving the "3 distinct PLUTs"
  detail below as a side effect.
- Are the 3 `ART.CAR` PLUTs meaningfully different? **Yes, and now explained** — 2 of the 3
  belong exclusively to the 4 `PRE0==17` sprites (section 1.6), not a near-duplicate or
  anomaly.
- **Mapping `.RFM` art ids to `ART.CAR` cels** — **section 1.7**. There is no mapping table:
  `ART.CAR`'s CCB array is loaded into memory verbatim and indexed directly by art id
  (`art_id * sizeof(CCB)`), confirmed by decompiling the real per-frame terrain blitter
  (`FUN_00408d60`) and its source, the `Art\ART.CAR`-loading function (`FUN_00424950`).
  Verified against all 104 real art ids with zero exceptions. Unblocks Phase 4 step 1.
- Is palette index 0 transparent in `ART.CAR` cels? **Yes** — confirmed by visual
  inspection of the atlas (section 1.6).
- Meaning of `ART.CAR` `Flags` bit `0x20`: it is the real 3DO `CCB_BGND` flag (confirmed
  against `trapexit/3doplay`'s `Madam.cpp`), which controls whether the "index 0 /
  pixel value 0" convention is treated as transparent for that cel
  (`pdec.tmask = !(Flags & CCB_BGND)`). Both observed `Flags` values in this file have it
  *unset*, i.e. transparency is on for every cel here — consistent with the visual finding
  above.
- `.RFM` "header" contents and the 372/388-byte size-class split — **section 1.5**,
  verified against the real loader (`FUN_00414130` in RFIRE.BIN) via Ghidra. It's a
  named-chunk container, not a fixed struct; the size difference is chunk-content length,
  not a format variant.
- **Where spawn points and building/target placements live in `.RFM`** — **section 1.5**.
  Not a separate chunk: four specific tile *values* (`0x39`/`0x4D` = team spawn points,
  `0xB4`/`0xDC` = candidate building/target position pools, one randomly committed per
  match). Verified against the loader and cross-checked by byte-histogram scan of all 204
  real files (e.g. `0x39` occurs in every single file, exactly once), then confirmed a
  second time by actually running the converter (`tools/convert_rfm.py`) against all 204.
- The 372/388-byte `.RFM` size-class split, precisely: it's the `VHCL` chunk's presence,
  confirmed exactly (all 50 files at 16,772 bytes have one; all 154 at 16,756 don't; no
  exceptions either way) by running `tools/convert_rfm.py` against every real file.
- **The `.RFM` raw-tile-byte → rendered-art-id mapping, including the `0xC8`-`0xEF`
  "coastline" range** — **section 1.5**. `FUN_0042e4f0` decompiled in full: it is a
  *second static table lookup* (`0x00447038`, 91 entries), not runtime neighbor-aware
  autotiling as guessed earlier — the loader always calls it with the neighbor argument
  hardcoded to `0`. `tools/rf_tile_art.py` implements the combined two-table pipeline;
  cross-checked against all 204 real files with zero unresolved cells and an exact match
  on the 104 distinct art ids actually used.
- **What `ART.CAR`'s 93 `PRE0 != 0` cels are** — **section 1.6**. Not compressed sprite
  colour data (the earlier `tools/rfcel.py` hypothesis, which rendered as noise and was
  correctly rejected). Decompiling the real renderer (`FUN_00418ef0` and its mask-blit
  callees) showed they are coverage masks for a masked palette-translation blend effect —
  the colour comes from remapping the existing background pixel, not from the cel.
  `tools/rf_effect_cel.py` decodes both mask encodings; cross-checked against all 93 real
  cels with zero exceptions, and visually confirmed as recognisable iconography (radar
  rings, explosion starbursts, targeting wedges), not noise. The exact runtime tint colour
  remains open (question 2 above).

---

## 5. Standing instructions for the executing agent

- **Verify before trusting, and prefer rendering over statistics.** Section 1.6's
  corrections all came from a 7-cel sample being generalised to 2165. The transparency
  question was settled in seconds by *looking at the atlas* after a statistical heuristic
  returned "inconclusive". When an asset question is visual, render it and look.
- **A plausible byte count is not a correctness proof for a codec.** The packed-cel
  decode attempt (section 1.6) decoded 92 of 93 cels to a byte length within 2x the
  unpacked size — and was still completely wrong; it rendered as noise. For any
  guessed binary format, the only real validation is rendering (or otherwise directly
  inspecting) the *decoded content*, not just checking the decoder didn't crash or
  overrun.
- **Never commit extracted assets or original game files.** Converters only.
- **Never introduce floating point into simulation code.** See section 2.1.
- **Never let the engine read a 1996 file format directly.** See section 2.4.
- **Never write simulation logic in a language that cannot reach the browser**, and never
  call a transport API directly from netcode. See sections 2.1 and 2.5.4.
- **Art may never affect gameplay.** Footprints and hitboxes are gameplay data.
- Work phase by phase. Do not start Phase 3 before the Phase 1 validation gate passes.
- Record newly decoded format details back into `/docs/`, in the style of section 1, so the
  next compaction does not lose them.
