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

1. Run the original game from the user's own retail data files.
2. Run equally well on a **completely custom, hand-authored replacement asset set**.

The engine is therefore a *data-driven engine that happens to ship with an importer for
the 1996 files* — not a port with modding bolted on. See section 2.4.

Target features that justify the rebuild (a DirectDraw wrapper cannot give these):

- Native widescreen
- Uncapped / decoupled framerate
- Linux and ARM builds
- Netplay
- **Web export**, shipping the author's own asset pack

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
- **CD audio:** `WINMM` `mciSendCommandA` → Redbook music. (`SOUND/DRUMS.WAV`, 2.8 MB,
  may be the local fallback. Confirm during RE.)
- **Input:** `WINMM` `joyGetNumDevs`, `joyGetDevCapsA`, `joyGetPos`, `joyGetPosEx`
  (legacy joystick API); `USER32` `GetKeyboardState`.
- **Timing:** `timeGetTime`, `GetTickCount`.
- **Video:** `AVIFIL32` + `MSVFW32` (`ICOpen` / `ICSendMessage`). **The `.avi` files were
  removed from this install.** Playback code is still in the binary but there is no media.
  Cutscenes need recovering from the original CD; transcode offline to Ogg Theora/WebM.
  The dead VfW codec problem never has to be solved.
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
offset 0x04..0x3F  ...         header fields, MOSTLY STILL UNDECODED. Known so far:
    0x08  u16 LE   width          (128 in every file seen so far)
    0x0A  u16 LE   height         (128 in every file seen so far)
    0x16  u8       mode/player-count selector byte (copied into a global that gates
                    1-player vs. 2-player logic elsewhere in the loader)
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
| `NAME` | starts with a null-terminated string, **but the record is much bigger than that string** (e.g. 268 bytes for a ~14-byte name) | The level's display name (confirmed exactly right -- decoded names like "The Cakewalk" and "Driving School" match the source filenames seen in section 1.2/1.5's string dump). Everything after the terminating null in the same record is editor/build-only cruft, not gameplay data: observed to contain what is very likely the original developer's full source path (`...\Images\Worlds\1Player\Level1\The Cakewalk.rfm`) followed by a block of binary data that looks like leftover editor state (camera position, undo history, or similar -- not decoded, not needed). **The converter must stop at the first null byte and ignore the rest of the record.** Separate from whatever string lives at old-header offset 0x18, which has not been re-examined since this discovery. |
| `VHCL` | 6 bytes, relative to the *record start* (not payload start): `+8`=A, `+9`=H, `+0xA`=J, `+0xB`=T, `+0xC`=?, `+0xD`=M | Level-tuning parameters, present in exactly 50 of 204 files (see above). **The same six parameters can also be written directly into the .rfm *filename*** using a bracket suffix the loader parses independently, e.g. `SomeLevel[A3H5T2].rfm` -- confirmed by decompiling the parameter parser (`FUN_00413f00`): it scans the filename for `[`, then for each `<letter><digits>` pair inside the brackets sets that parameter, with the VHCL chunk (if present) only overriding whichever of the six the loader didn't already get a valid (non-`0xFF`) value for. Letters confirmed: `A` (<10), `H` (<10), `J` (<10, nonzero), `M` (<201), `T` (<10). This is a real, working config mechanism worth preserving in the content-pack format (section 2.4) rather than special-cased away. |
| `EDTN` | 4 bytes, e.g. `27 03 27 03` (two identical u16 LE values) | Present in every file. Not decoded -- likely an editor/build bookkeeping value (version, checksum, or similar). Low priority: the converter round-trips it as an opaque tag but doesn't need to understand it. |

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
  stride lookup table at `0x00448450`** in RFIRE.BIN (240 entries, fully dumped), one per
  possible tile value: `[transform_byte, pad, secondary_param, function_ptr_index]`.
  - `transform_byte` sets the low 7 bits of the runtime tile value (a value of `0xFF` here
    means "clear to the base/default tile" instead; ~60 of the 240 entries are `0xFF` --
    almost certainly unused/reserved tile-ID slots, not meaningful gameplay data).
  - If `secondary_param != 0` (true for values `0xC8`-`0xEF`, the "high" range): calls
    `FUN_0042e4f0`, not yet decompiled -- plausibly neighbor-aware blending for the
    coastline autotiling already observed visually. Not chased further this pass.
  - **If `function_ptr_index != 0`: dispatches through a 2-entry function-pointer table at
    `0x00448810`** (confirmed to be exactly 2 entries -- the string table for the chunk tags
    `VHCL`/`NAME`/`LEVL` begins immediately after at `0x0044881C`, so don't over-read it).
    Only 4 of the 240 tile values trigger this: `0x39`, `0x4D` → function-pointer index 1
    (`FUN_00413e00` @ `0x00413e00`); `0xB4`, `0xDC` → index 2 (`FUN_00413db0` @
    `0x00413db0`). Both were force-decompiled (they're only reachable via an indirect call,
    so Ghidra's static analysis didn't auto-recognize them as functions --
    `tools/ghidra_scripts/ForceDecompile.java` handles this: disassemble + createFunction at
    the address, then decompile).

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
buffer* (not a separate x/y) to one of two growable candidate-position pools (`pool_index`
0 or 1, again matching `secondary_param`), capped at 254 entries. Back in the main loader
(`FUN_00414130`), once the whole grid has been scanned, **each non-empty pool has exactly
one entry picked at random** — `FUN_00404360(count)` calls the C runtime `rand()` and scales
it into `[0, count)` — and stored as the active building/target for that match. This is the
mechanism behind the classic Return Fire feature where the destructible target/base
locations differ between plays of the same level: **the level file defines a pool of
candidate positions, and the engine randomly commits to a subset each match.** (There is
also a `>>1` "half the count" computation right after the random pick, not yet chased down
-- possibly a win-condition threshold, e.g. "destroy half the spawned targets to win".)

**Remaining work, in priority order:**
1. Decompile `FUN_0042e4f0` (the coastline-blending function called for tile values
   `0xC8`-`0xEF`) to nail down the autotiling rule.
2. Map the still-undecoded header body (offsets `0x04`-`0x3F`, minus the now-known width/
   height/mode-byte fields) -- likely more gameplay metadata.
3. Re-examine the old offset-`0x18` string finding now that `NAME` is known to be the real
   display-name source -- confirm what offset `0x18` actually holds.
4. Confirm whether any of the 204 `.rfm` files have the offset-`0x40` "enabled" byte unset.
5. Chase the `>>1` "half the pool count" computation after the random building/target pick
   -- likely a win condition.
6. **Write the actual `.RFM` converter** (Phase 1d) — the format is now understood well
   enough to do this: parse the chunk table, resolve tile values through the `0x00448450`
   table (linear terrain vs. spawn/candidate markers), and emit tilemap + spawn points +
   candidate-pool JSON. This no longer needs to wait on further RE.

**Ghidra references for continuing this:** `FUN_00414130` @ `0x00414130` in RFIRE.BIN is the
full level loader (decompiled in full during this investigation -- re-run
`tools/ghidra_scripts/DecompileOne.java` with that address to get it again without redoing
the search). Its caller is `FUN_0041e9f0` @ `0x0041e9f0`. The lightweight "just get the
display name for the level-select menu" path is a separate, simpler function,
`FUN_004266d0` @ `0x004266d0`, called from `FUN_00426f70` @ `0x00426f70` (which enumerates
`*.rfm` files via `FindFirstFileA`/`FindNextFileA`).

### 1.6 `ART/ART.CAR` — SOLVED for 96% of cels, converter written and verified

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
  *CORRECTION: an earlier draft listed `0x28B10` / `0x28B20`. Those were wrong.*
- **Two distinct `Flags` values: `0x7FE64400` (1847 cels) and `0x7FE64420` (318 cels).**
  They differ only in bit `0x20`. **RESOLVED:** this is the real 3DO `CCB_BGND` flag
  (confirmed against `trapexit/3doplay`'s `Madam.cpp` — see section 4). It gates whether
  pixel value 0 is treated as transparent for a cel. Neither value here has it set, so
  transparency is on for every cel in this file — consistent with the visual confirmation
  above.
  *CORRECTION: an earlier draft had these two counts swapped.*

**CORRECTION — the packed-cel exception (this matters):**

An earlier draft claimed `PRE0`/`PRE1` are zero for every cel. **That was wrong**, based on
a 7-cel sample. In fact:

- **93 of 2165 cels have non-zero `PRE0`.** For those, `PRE0` bits 0-2 hold the standard
  3DO bit-depth code: `1`=1bpp, `2`=2bpp, `3`=4bpp, `5`=8bpp.
  Histogram among the 93: **8bpp x48, 2bpp x21, 1bpp x15, 4bpp x9**.
- Those cels are **packed (compressed)**, not linear. Proof: cels 120 and 121 are both
  16x16 (256 px) but their source offsets are only `0x77` = 119 bytes apart.
- Independent proof that not every cel is `W*H` bytes: **`sum(W*H)` over all cels =
  1,959,779, but the pixel data region is only 1,761,859 bytes.**

**Consequence:** the converter skips those 93 cels (`tools/convert_car.py` leaves them
transparent in the atlas by default). It is correct for the other 2072.

**Investigation so far (attempted, not solved) — `tools/rfcel.py`:**

This is **not** the literal 3DO hardware `CCB_PACKED` format. That was checked directly
against a MADAM cel-engine reimplementation
([trapexit/3doplay](https://github.com/trapexit/3doplay), `Madam.cpp`): the real
`CCB_PACKED` flag is `Flags` bit `0x200`, and neither of this file's two `Flags` values
(`0x7FE64400`, `0x7FE64420`) has it set. So the PC porting tool is using its own
convention, not carrying the ROM's packed-cel flag through.

What **is** established, by direct byte inspection of cel 120 (16x16, 8bpp, only
`0x77`=119 bytes of data — cross-checked against cel 121's `SourcePtr`):

- `SourcePtr` points to a **table of `Height` little-endian offsets**, one per row —
  1 byte each if `bpp < 8`, else 2 bytes each (this part mirrors the real 3DO
  `offsetl` convention, confirmed in `Madam.cpp`).
- Each entry is either **`0`, meaning the row is fully transparent** (rows 0, 1, and 15
  of cel 120 all read `0`, consistent with a roughly circular/diamond 16x16 icon), or an
  **absolute byte offset from `SourcePtr`** to that row's data. Row 2's entry is exactly
  `32` = the table size (`16 rows x 2 bytes`), i.e. immediately after the table — this is
  strong, checked evidence the table itself is real.
- Per-row byte deltas computed from the table (3, 7, 5, 9, 7, 11, 7, 9, 7, 7, 7, 3 bytes
  for a 16-pixel-wide row) are far too small for literal 8bpp pixel data throughout,
  meaning most of a row's content must be `PACK_TRANSPARENT`/`PACK_REPEAT` runs, not
  literal pixels.

**What is NOT established — the opcode stream itself.** Applying the real MADAM opcode
scheme (2-bit type + 6-bit count, MSB-first bits: `0`=end-of-row, `1`=literal run,
`2`=transparent-skip run, `3`=repeat-pixel run) at each row's table offset decodes without
crashing and consumes a plausible number of bytes for **92 of 93 cels** — but **renders as
color noise (8bpp cels) or near-total transparency (1/2/4bpp cels)**, not recognisable
sprites. Byte-budget plausibility is not sufficient evidence of correctness — it was
checked here and found wanting; **do not trust it as a validation signal for this format.**
Likely wrong assumptions, in rough order of suspicion: bit order within a byte (tried
MSB-first only), the opcode type→meaning mapping, or the row-table's `0` convention.

**Recommended next step: stop guessing, go to Ghidra (Phase 2).** `RFIRE.BIN` contains the
real decoder for this exact format — find it via the `Art\art.CAR` string cross-reference
(or the CCB-array-walking loop it must contain) and read the packed-row logic directly out
of the disassembly. That will settle this in one pass instead of more blind trial-and-error
against 92 cels' worth of noise. `tools/rfcel.py`'s table-discovery reasoning is worth
keeping as a head start once the opcode semantics are confirmed from the binary.

---

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
- Sprites: `Sprite2D`, or `MultiMeshInstance2D` if unit counts justify it.
- Split-screen: one `SubViewport` per player inside `SubViewportContainer`s.
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

**1c. `ART.CAR` → atlas + manifest — DONE for 2072 of 2165 cels.** `tools/convert_car.py`.
2072 unpacked cels packed into a 2048x2048 atlas + `art_atlas.json`; output visually
verified as correct sprite art. **The 93 packed cels (`PRE0 != 0`) are skipped, not
guessed at** — a candidate decoder exists (`tools/rfcel.py`, behind
`--experimental-packed-decode`) but was tried, rendered as noise, and rejected rather than
shipped. See section 1.6's "Investigation so far" for what is and isn't established, and
go to Ghidra (Phase 2) to settle the opcode semantics from the real decoder in
`RFIRE.BIN` rather than continuing to guess.

**1d. `.RFM` → tilemap + entity JSON — DONE.** `tools/convert_rfm.py`. 204/204 real files
converted with zero failures. Per level, emits `<name>.json` (chunk metadata, resolved
`VHCL` params with their source per field, spawn points, candidate pools), `<name>.tiles.bin`
(raw width*height tile bytes, entity cells zeroed to 0), and `<name>.debug.png` (false-colour
terrain + entity markers, for visual sanity-checking rather than trusting the numbers alone
-- this is what caught that "Campgrounds Of America" is a uniform grid of 160 evenly-spaced
`0xDC` candidate markers, which makes perfect thematic sense and was a good confirmation the
extraction is correct, not a bug).

Totals across all 204 files (all consistent with section 1.5's per-file findings): 204 team-0
spawn points (one each, no exceptions), 104 team-1 spawn points (exactly the 2-player files),
641 pool-A candidates, 1560 pool-B candidates. Decoded `NAME` strings were spot-checked
against the source filenames already known from section 1.2/1.5 (`"The Cakewalk"`,
`"Driving School"`) and matched exactly.

**Not yet done: resolving plain terrain tile values into semantic classes** (open question
in section 4) -- the converter currently emits the raw on-disk tile byte for anything that
isn't one of the four special values, which is enough for a correct tilemap but not yet a
classified one (water/land/coastline-variant N). That mapping work is still open.

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
3. Lockstep with input delay first — simple and sufficient for 2 players, and it works
   over all three transports.
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

1. **3DO packed-cel decoding** for the 93 cels with `PRE0 != 0`. The row-offset table
   structure is confirmed (section 1.6); the opcode stream is not — a candidate decoder
   (`tools/rfcel.py`) renders noise, not sprites. Solve via Ghidra, not more guessing.
2. **Highest priority now:** map plain terrain tile values into semantic classes
   (water/land/coastline-variant N). `tools/convert_rfm.py` already separates the four
   *special* values (spawn/candidate markers) from everything else; what's left is
   classifying the ~94 remaining distinct terrain byte values well enough to pick tile art
   and collision. Needed before Phase 4 step 1 (render a level).
3. The coastline-autotiling function `FUN_0042e4f0`, called for tile values `0xC8`-`0xEF`
   (section 1.5) — not yet decompiled. Likely feeds directly into question 2 above.
4. The still-undecoded `.RFM` header body, offsets `0x04`-`0x3F` (minus width/height/
   mode-byte, which are known — section 1.5).
5. The `>>1` "half the candidate-pool count" computation right after the random
   building/target pick in `FUN_00414130` — possibly a win-condition threshold (section 1.5).
6. The `EDTN` chunk tag (section 1.5) — present in every file, 4-byte payload, not decoded.
   Low priority: `tools/convert_rfm.py` round-trips it without understanding it.
7. Purpose of the `count * 8` byte table at `ART.CAR` offset `0x23F24`.
8. Are the 3 `ART.CAR` PLUTs meaningfully different, or near-duplicates?
9. **How is team colouring done?** Palette ranges or separate cels. Blocks section 2.4.3.
10. Is music Redbook CD audio (`mciSendCommandA`) or `SOUND/DRUMS.WAV`?
11. Native framebuffer dimensions and the fixed sim tick rate.
12. Implicit sprite pivots in the original cels — needed for the registry.

**RESOLVED:**
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
