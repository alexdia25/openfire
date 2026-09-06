# Return Fire (1996, Silent Software) — Godot Port Plan

**Status:** planning complete. Phase 1 converters (1a/1b/1c/1d) written and verified. Phase 0
(Godot project scaffold) done, 2026-09-05. Phase 4 step 1e (asset registry + pack emitter,
section 2.4) and Phase 4 step 1 itself (a Godot scene renders a real level's terrain through
a pack, with spawn/candidate markers) are both done as of 2026-09-06 — **the game renders its
first real content**, verified with an actual screenshot, not just "no errors." A real
palette bug found the same day (section 1.6 — a raw pixel byte needs a `-10` index shift
into the shared PLUT that every converter had missed) is fixed; art now matches real
screenshots' colours, not just their shapes.
Phase 4 step 2 (a player-controlled vehicle) is done too, including a real mirroring bug the
user caught and a registry auto-numbering drift bug it exposed (both fixed, section 3/2.4.1).
Phase 4 step 3's single-viewport half (smoothed, edge-clamped scrolling camera) is done as of
2026-09-06 as well — split-screen itself is not started.
Phase 4 step 4 (weapons and projectiles) has a first pass done too (2026-09-06): playable,
not yet authentic, same honesty flag as step 2's movement — see below. Phase 4 step 5
(destructible targets and buildings) has a first pass done the same day: section 1.5's
already-traced candidate-pool mechanism is now real, running gameplay logic, verified by
a 2000-trial unit test plus a full-integration test against a real level. Phase 4 step 6
(enemy AI) also has a first pass done the same day: a from-scratch seek-and-shoot
placeholder (no RE finding to reimplement here — Phase 3's AI backlog item is untouched),
spawned from real per-level spawn data, verified by a deterministic fixed-timestep test.
**Priority as of 2026-09-05: get the core PC-port game actually running before returning to
3DO support (section 4 item 6) or new-goal work beyond what's needed to run it** — the user
explicitly deferred the 3DO disc work until then. Phase 4 step 7 (mission objectives, scoring,
level progression) has a first pass too as of 2026-09-06: reading `FUN_00432710`'s exact
branch logic (not just its summary) pinned down the precise condition for section 4 item 1's
flag-object spawn — a pool's targets being fully exhausted, exactly what `TargetPool.
destroy_active()` already returns `false` for — and `game/flag_marker.gd` makes it real,
verified by a real-scene integration test. Still nothing declares a match won or lost; a
DOSBox-X reference-capture attempt for a related open question (the vehicle turning-sprite
rendering, section 4 item 10) hit a Windows 95 boot blocker (`IOS.VXD`) and was parked, not
resolved.
**Rendering architecture: DECIDED (2026-09-06) — migrate world rendering from flat 2D to a
real Godot 3D scene** (section 2.2, section 4 item 13), prompted by the user pointing out real
footage shows a tilted, moving camera, not a flat top-down map. Phase 0 of that migration
(closing the remaining RE unknowns) is DONE as of 2026-09-06 (section 1.10 point 6): the
camera's tilt is a fixed, algebraically-exact 45°, hardcoded once at construction and never
rewritten anywhere in the binary; the terrain blitter has no rotation/yaw term at all. Phase 1
(scaffolding) has not started yet.
**Audience:** an AI coding agent executing after context compaction. Everything needed is
in this file; do not assume prior conversation is available.

**Converters live in:** `C:\Users\Alex\Documents\code\returnfire-godot\tools\`
**Source data:** `C:\Users\Alex\Documents\returnfire`
**Godot 4.7.2 editor:** `C:\Users\Alex\Documents\code\tools\godot\Godot_v4.7.2-stable_win64.exe`
(outside the repo, like the Ghidra toolchain — not version controlled)

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
  (section 2.4) where the map author places all 4 explicitly. See section 4 item 7.

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
- **CORRECTION (2026-09-06) — a raw pixel byte is not a direct index into this table.** The
  table itself decodes correctly (entry 2 really is `(181, 133, 87)`, confirmed against a
  real screenshot's actual sand colour), but every converter through the whole asset-registry
  effort (section 2.4.1) was indexing it directly, producing plausible-but-wrong-hued output
  that nothing internal ever caught. Traced via `FUN_0041e960` (copies the shared PLUT into
  the game's real active palette, `DAT_0045bb94`, starting at *slot 10*, slots 0-9 reserved/
  black — a standard Win95 static-system-palette convention) and `FUN_0042feb0` (the only
  caller of `IDirectDrawSurface::SetPalette`, a fade routine that installs `DAT_0045bb94` as
  the real screen palette). **The colour actually shown for raw pixel byte `k` is
  `shared_plut[k - 10]`** (black if `k < 10`), not `shared_plut[k]`. Confirmed decisively by
  re-rendering the whole terrain block both ways and comparing against real screenshots
  ([myabandonware.com](https://www.myabandonware.com/game/return-fire-bau), flagged by the
  user) — full trace in `docs/process/20-worked-example-palette-offset.md`. Applies only to
  the shared PLUT (2161 of 2165 cels); the 4 `PRE0==17` own-PLUT cels use a different code
  path (`FUN_00419ea0`, direct fetch) with no evidence of the same shift, decoded unshifted.
  `tools/convert_car.py` fixed; `build/car/art_atlas.png`/`art_effects.png` and
  `packs/original_pc/` regenerated. The registry's *shapes/structure* survive untouched
  (colour doesn't affect geometry); a handful of colour-dependent labels that were wrong
  under the old palette got relabeled (cels 0/1/3/52: sand/forest → open water; 84-86: green
  furrows → wood planks). The confirmed tan/green team-colour finding (section 4 item 5)
  was re-checked against the corrected palette and holds exactly as before.
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
built at load time. This was approach 2 from `docs/process/NEXT_STEPS.md` (trace the
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

### 1.9 Native framebuffer resolution — SOLVED (2026-09-06); fixed sim tick rate — SOLVED (2026-09-05)

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
level is actually running, not during the title sequence).

**Update (2026-09-05): found, and this is the pacing mechanism.** COM vtable calls have no
symbol and no fixed target address, so neither `FindSymbol.java` nor `FindDataXrefs.java`
can find them — a new script, `FindVtableCall.java`, scans every instruction in the binary
for an indirect `CALL [reg + <offset>]` at a given vtable slot byte offset instead.
`IDirectDrawSurface`'s vtable (DirectDraw 1, matching this game's `DirectDrawCreate`-only
import — no `DirectDrawCreateEx`/`IDirectDrawSurface7`) puts `Flip` at slot 11 (offset
`0x2c`; `QueryInterface`/`AddRef`/`Release` take slots 0-2, then `AddAttachedSurface`
through `EnumOverlayZOrders` take 3-10). Running it against offset `0x2c` turns up exactly
one real hit, `FUN_004300e0`:

```c
piVar2 = (int *)(**(code **)(*DAT_00448d28 + 0x2c))(DAT_00448d28,0,1);
if (piVar2 == (int *)0x887601c2) {       // DDERR_SURFACELOST
    FUN_00420ff0();                       // Restore()
    piVar2 = (int *)(**(code **)(*DAT_00448d28 + 0x2c))(DAT_00448d28,0,1);
}
```

This is an exact signature match for `Flip(LPDIRECTDRAWSURFACE lpSurfaceTargetOverride,
DWORD dwFlags)` called as `Flip(NULL, DDFLIP_WAIT)`, retried once after a `Restore()` if the
surface was lost — a check that only makes sense for `Flip`. The same function's other two
branches (offsets `0x14` and `0x1c` on the same `DAT_00448d28` surface pointer) are equally
exact matches for `Blt` and `BltFast` by parameter count and shape, cross-confirming the
vtable-offset table itself. `FUN_004300e0` is the game's one screen-present routine, chosen
per-branch on a display-mode global (`DAT_00448d5c`): **fullscreen modes call the blocking
`Flip(NULL, DDFLIP_WAIT)`**; **windowed modes call `Blt`/`BltFast`** into a rect computed via
`GetClientRect`/`ClientToScreen` instead (no wait flag — a plain copy).

`FindCallers.java` on `FUN_004300e0` closes the loop: one of its callers is `FUN_004312c0` —
the exact per-idle-iteration function section 1.9 already traced from `WinMain`'s message
loop — and it calls `FUN_004300e0(0)` **unconditionally, every single iteration**, right
after (not gated by) the now-identified boot-slideshow dispatch:

```c
void FUN_004312c0(void) {
  if (DAT_0044e0d0 != 0) {
    if (*(int *)PTR_PTR_0044e27c != 0) { /* slideshow state-machine step, see above */ }
    FUN_004300e0(0);   // present -- Flip() if fullscreen, Blt/BltFast if windowed
  }
}
```

**Conclusion: there is no fixed-Hz simulation tick anywhere in this code, and there was
never going to be one to find.** The main loop runs every idle slice it gets and hands each
stage real elapsed milliseconds (consistent with everything traced earlier: no `Sleep()`,
no `WM_TIMER`/`SetTimer`, no fixed-`delta` accumulator). In **fullscreen** display modes,
the loop's own rate is instead governed by the **blocking `Flip(NULL, DDFLIP_WAIT)`
call** — classic exclusive-mode DirectDraw hardware page-flipping does not return until the
next vertical retrace, so the loop is implicitly capped to the display refresh rate (60Hz on
a stock 1996 CRT, not a portable constant) purely as a side effect of how the frame gets
presented, not because any code counts ticks. In **windowed** modes the presentation path
(`Blt`/`BltFast`) has no such wait, so windowed play is uncapped by this mechanism —
consistent with `WaitMessage()` being the loop's only other wait, and that's gated on the
window losing foreground focus, not framerate. **Port implication:** do not look for a
"native Hz" to replicate — there isn't one. Godot's own fixed `_physics_process` tick (see
section 2.1's determinism rules) is a deliberate design choice for this port, not a
recovered original value; pick a rate for gameplay determinism (e.g. 60Hz) rather than
trying to match "the game's real tick rate," because the original's own effective rate was
just whatever the display's refresh rate happened to be while running fullscreen, and
uncapped while windowed.

### 1.10 Object *and terrain* rendering are real perspective-projected 3D, not 2D sprite-pivot rotation or a flat top-down map — SOLVED (2026-09-06), terrain half confirmed 2026-09-06

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

**Point 5 (new, 2026-09-06): the terrain half of point 2 above ("terrain and objects share one
perspective system") is a genuine per-scanline perspective floor projection, not flat top-down
tile blitting** — confirmed by fully decompiling the terrain blitter itself, not just noting it
reads the same table. Prompted by the user pointing out (2026-09-06, from real footage) that the
   original's camera is visibly tilted, not straight overhead, and can move. Read in full,
   `FUN_00408d60` (the real per-frame terrain blitter, section 1.7) does not iterate a fixed
   grid of screen tiles at a constant world-space step — it runs a scanline loop (`local_18`,
   incrementing once per screen row) where **both the starting world-X offset and the
   per-column world-X step size are looked up per row** from `PTR_DAT_00449400` (the exact
   same depth-reciprocal table from point 2, built once by `FUN_0041ae50` alongside the
   heading cosine/sine tables — one shared camera setup, not two systems that happen to reuse
   a table) combined with a hidden x87-float calculation (`FUN_00410c10`, whose real
   parameter is passed on the FPU stack rather than as a normal argument — Ghidra's decompiler
   can't lift it into the pseudo-C parameter list, but the call pattern, `__ftol` conversion
   included, is unambiguous). This is the textbook technique classic "Mode 7"/raycasting-style
   tilted-plane renderers use: precompute `scale(depth) = focal_length / depth` once, then
   drive each screen row's horizontal step and offset from that row's depth — exactly why the
   ground plane looks like it recedes toward a horizon instead of a flat overhead map. A
   second, previously-unnamed function, `FUN_00413d00`, is a generic N-point 3D-to-screen
   projector using this identical table (`screen_xy = ((local_xy + camera_xy) >> 0xe) *
   scale[depth] + screen_center`) — the same formula point 3 above already found driving
   per-object quad corners. **One camera, one perspective table, used by the terrain blitter
   directly and by objects through this generic projector.**

   **Consequence, and it's a bigger one than the vehicle-rotation question:** `terrain_view.gd`
   currently draws the level as a flat, straight-down orthographic tile grid
   (`draw_texture_rect_region` per tile, no depth/scale variation) — section 2.2's rendering
   plan only ever posed the projected-quad-vs-flat-rotation choice for *objects* (Phase 4 step
   2), never revisited the terrain bullet ("`TileMapLayer` built from the 128x128 grid") in
   light of this same section's own point 2 finding that terrain shares the perspective
   system. That's a real gap between what was found and what got built, not a deliberate,
   flagged simplification the way the vehicle-rotation approximation was — see section 4 item
   13 for the resulting open architecture decision. **Not yet determined:** whether the
   camera's tilt/height ever changes at runtime (a real dynamic camera, matching "the camera
   can move" beyond simple panning) or is a fixed constant that only pans as the tracked
   object moves — `DAT_00443000` (the `param_1`/focal-length seed for the whole table) has no
   confirmed write site checked yet, so whether it's a runtime-tunable camera parameter or a
   boot-time constant is still open. **Resolved by point 6 below.**

**Point 6 (new, 2026-09-06): Phase 0 of the rendering-migration plan — the tilt is a fixed
45°, hardcoded once, never rewritten.** Rereading `FUN_0041ae50`'s caller (`FUN_004092d0`,
game init) and the shared object constructor everything in this rendering system funnels
through (`FUN_00416cb0`) closes point 5's open question:

- **`DAT_00443000` (focal length) is exactly `0x012C0000` = 300.0 in 16.16 fixed point.**
  (Correction: point 5 above previously mis-stated this as "raw value 76800" — a hand-hex
  slip. The real byte dump, `00 00 2c 01` read little-endian, is `0x012C0000`. A clean round
  300.0 is itself small evidence this is a deliberately chosen constant.)
- **`FUN_00416cb0`** — the one shared constructor used to build the level/terrain-camera
  object (`&DAT_0048b270`; confirmed to be the object whose "draw" callback is `FUN_00408d60`
  itself, the terrain blitter, via `FindCallers.java` on `FUN_00408d60` resolving to
  `FUN_004184d0`, a thin dispatcher that just invokes whatever `param_1[0x30]` points to) and
  every individual object (same field layout, operated on by `FUN_00416900`/`FUN_00416ab0`) —
  **hardcodes the tilt as a literal**: `param_1[9] = 0x200000`. The sin/cos helpers
  (`FUN_00410be0`/`FUN_00410dc0`: `fcos(angle * DAT_0043d000 * DAT_0043d028)`) decode their two
  double-precision scale constants to exactly `2π / 0x1000000`, confirming `0x1000000` raw
  units = one full turn (matching the 64-heading loop's step size) — so `0x200000` is exactly
  **45.0°, algebraically exact, not estimated.**
- That literal is written exactly once, at construction, from a call in `FUN_004092d0` that
  only ever runs at game init (`FUN_00416cb0(&DAT_0048b270, 0x480d50, 0, 0, DAT_00480d40,
  DAT_00480d24)`). No other call site targets this object, and `FUN_00408d60` never writes
  back to the angle field itself — it only reads the two derived fixed values that constructor
  produced once (`param_1[8]` = `0x10E0000` = 17.875 fixed; `param_1[10]` =
  `-round(cos(45°)*65536)` = -46341). Together with the already-established "no write site to
  `DAT_00443000`" finding, this closes Phase 0's central question: **the tilt is a genuine
  fixed constant, not a dynamic camera parameter** — "the camera can move" (the user's
  original observation) refers only to X/Z translation tracking the vehicle, not a changing
  pitch/FOV.
- **No rotation/yaw term exists in the terrain blitter itself** — `FUN_00408d60` never reads a
  per-frame heading field, only the two fixed constants above, mechanically confirming Phase
  1's `Camera3D` assumption (fixed pitch, zero yaw, X/Z-only translation) directly from the
  decompile rather than from absence of counter-evidence.
- **The exact per-row depth-index formula**, read directly off `FUN_00408d60`'s setup code —
  recorded for documentation/validation, not reimplementation (Godot's own `Camera3D` replaces
  this table outright): `idx(row) = (46341 * local_20(row) - 1,114,112) >> 16`, where
  `local_20` advances by 32 per screen row. This is the concrete arithmetic behind point 5's
  "per-row scale/offset lookup" — a linear relationship between screen row and world depth,
  exactly what a real tilted camera produces and a flat top-down blit cannot.
- **What Phase 0 leaves open, honestly:** the precise effective vertical FOV/eye-height a
  `Camera3D` needs to visually match this table (as opposed to just "some 45° tilt") isn't
  algebraically derived here — that would mean tracing several more layered fixed-point
  constants (`DAT_00480d40`/`DAT_00480d24` screen dimensions, the tile-origin setup) for a
  number better pinned by the plan's own stated fallback: matching a real windowed screenshot
  against the user's reference footage once Phase 2 has something to screenshot. A deliberate
  scoping choice, not a gap that blocks starting Phase 1.

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

**DECIDED (2026-09-06): migrate world rendering from flat 2D to a real 3D scene, 2D UI
overlay.** Section 1.10 (points 1-5) established that RFIRE.BIN renders terrain *and* objects
through one unified real perspective camera (64 discrete headings, a shared 1/z scale table) —
not a flat top-down map with sprites on it, which is what Phase 4 steps 1-7 actually built.
Prompted by the user pointing at real footage showing the camera's visible tilt (section 4 item
13), and the user's own observation that this affects "everything else," rather than patch the
gap incrementally into the flat architecture:

- **Terrain:** a `MeshInstance3D` ground plane, textured by baking the existing (unchanged)
  `terrain_view.gd` tile-drawing code into a `SubViewport` and applying that texture as the
  plane's albedo. No shader/projection math to write — a real `Camera3D` viewing a real 3D
  plane does the perspective for free.
- **Vehicles, projectiles, the flag marker:** each becomes a `Node3D` positioned at
  `(world_x, height, world_y)` with a child `Sprite3D` in billboard mode. `Vehicle`'s existing
  `_frame_for_heading()` (quadrant-mirror logic, fixed and verified this session — document 25)
  is reused **unchanged**; only the final draw call changes from `draw_texture_rect_region` to
  setting the `Sprite3D`'s texture region. This works because each heading's pre-rendered art
  is already "as seen from the fixed camera angle" — a plain billboard reproduces it directly,
  without needing the original's own quad-corner CCB projection (section 1.10 point 4), which
  was solving a problem specific to *its* pipeline that a real 3D engine doesn't have.
- **Camera:** a `Camera3D` at a fixed tilt/height (derived from the real `DAT_00443000`=76800
  focal-length constant and the depth-reciprocal table, section 1.10 point 5 — confirmed
  read-only, so very likely a boot-time constant, not something that changes at runtime),
  translating in X/Z to follow the tracked vehicle with the same smoothing already built for
  the current `Camera2D` (section 3 Phase 4 step 3).
- **Gameplay logic is unaffected.** Movement, `TargetPool`, hit-testing, spawn positions, the
  flag-spawn trigger — all already operate on plain world X/Y and don't change; only how those
  numbers become pixels does. Existing gameplay tests must keep passing unmodified through this
  migration as the regression guard.
- **Split-screen** (section 0, section 4 item 7): a `Camera3D` + `SubViewport` per player is,
  if anything, a more natural fit in 3D than the 2D equivalent — same "design the layout to
  scale to 4 from the start" guidance as before applies to the `SubViewportContainer` grid.
- **UI/HUD** stays exactly as section 2.6 already planned: ordinary 2D `Control` scenes in a
  `CanvasLayer` on top of the 3D viewport — a standard, common Godot pattern, not a new problem
  this migration introduces.
- Palette: bake to RGBA8 at conversion time, or keep indexed and apply the palette in a
  fragment shader if palette-cycling or team-colour swapping turns out to need it.
  Any such shader must be WebGL2-compatible — **no compute shaders, no storage buffers**.

**Phased implementation plan (not yet started — see section 4 item 13 for status):** Phase 0
closes remaining RE unknowns (dump the full depth-reciprocal table and fit the real tilt/FOV;
confirm no rotation term exists in the terrain blitter, i.e. the camera only pans, never
yaws). Phases 1-5 build the 3D scene *alongside* the existing flat one (kept fully working
throughout, per this project's "keep every step playable" rule) — scaffolding, terrain,
vehicles, then projectiles/markers, each with a real screenshot verification before moving on
— and only cut over once every phase is individually proven. Full plan retained at
`C:\Users\Alex\.claude\plans\tingly-booping-wall.md` for the executing agent's reference; that
file is outside this repo and not guaranteed to survive a fresh clone, so treat this summary
as the durable record and re-derive phase details from the principles above if that file is
ever unavailable.

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

#### 2.4.1 The asset ID registry — DONE (first pass, 2026-09-06), coarse precision by design

The engine must reference art by **stable semantic ID** (`vehicle.helicopter.rotor.f03`,
`terrain.water.edge.ne`, `ui.hud.fuel_gauge`), never by cel index. `packs/registry/asset_ids.json`
now maps **all 2165 `ART.CAR` cels** to a semantic ID — every cel has an entry, Phase 4 is
unblocked.

**This was genuine classification work, done in two precision tiers by explicit user
direction (2026-09-06).** The first ~205 cels (the terrain tileset, all 89 effect masks, the
4 target-lock reticles) were classified precisely, cross-checked against the code-level
findings in sections 1.6/1.7. Confirming per-cel precision for the remaining ~1960 (mostly
vehicles, buildings, weapons, VFX, UI, font) at that same rigor would have taken far longer
than the payoff justified before anything is actually rendering in Godot, so the user chose
a **coarse pass now, refine later**: cels are grouped by object + a sequential part/frame
number (`vehicle.hovercraft.hull.07`, `effect.burst_red.114`), with confidence recorded
per-cel as `"confirmed"` (traced through code), `"visual"` (a specific, fairly certain read
of the pixels), or `"visual_group"` (bucketed by an obvious visual family; the exact part
name is a placeholder, not a claim). ~1880 of 2165 entries are `"visual_group"` — expect
many of these IDs to get more precise names once real rendering makes it possible to verify
against actual gameplay, without needing to touch the numeric cel indices anything else
references.

Where a run of cels was too large or too repetitive to eyeball reliably (the trooper-run
animation's tan/blue split, ~180 near-identical VFX burst frames), classification was done
**programmatically from mean pixel colour** rather than transcribed by hand — see
`dominant_team_colour()` and `_colour_bucket()` in `tools/registry/classify_bulk.py`.

**New findings surfaced during classification, not yet confirmed against code:**
- **Possible team-colour lead** (open question, item 3 below): the hovercraft's hull/cab
  pieces (cels 167-209) recur in matching tan and cyan pairs. Consistent with per-team
  *duplicate art* rather than a runtime palette swap, at least for this vehicle — the
  opposite of what section 2.4.3 requirement 3 currently assumes as the likely mechanism.
- **A full on-foot infantry unit exists** (cels 655-754, ~100 frames, tan/blue): a running/
  walking animation, at real scale, not just a portrait. Nearby cels (821-827, 845-846,
  863-869) read as rescue/POW-camp dressing (red-cross-like markers, barred cage panels, a
  doorway) and cels 801-820 as a chaotic multi-figure clash animation. Together these suggest
  a rescue-hostages mechanic that isn't in section 0's feature list — plausible for a 1996
  military action game, but this hasn't been checked against `.RFM` entity data or the
  renderer, so treat it as a lead, not a confirmed mechanic.
- **A handheld weapon sprite exists** (cel 1940, olive-green rifle silhouette, plus matching
  ammo-crate parts at 1942-1947) — consistent with the infantry unit being a real playable or
  AI-controlled ground unit, not just scenery.
- **The HUD numeric font is in `ART.CAR`**, not a separate resource: cels 2146-2155 are a
  clean 0-9 digit set (`font.hud_digit.0` .. `.9`).

Registry entries are versioned implicitly by git history for now; `packs/registry/asset_ids.json`
has no internal `version` field bump process yet — add one (semver minor for additions, major
for removals/renames) before any external pack starts depending on ID stability.

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

### 2.6 Menu / UI system: everything is custom Godot UI, nothing is a native dialog

**No game-flow screen can be a native OS dialog or Win32 control — all of it has to be built
as ordinary Godot `Control` scenes.** Two different reasons converge on the same answer for
two different kinds of screen:

- **In-game flow (main menu, level select, mode/player-count select, options, pause,
  results):** the original **doesn't use Windows dialogs for these either** — `RFIRE.BIN`'s
  own import table (section 1.2) has no `COMDLG32` and no `DialogBox`/`CreateDialog` family
  call anywhere, only `GetKeyboardState` from `USER32`. Its level-select screen is a
  self-rendered menu drawn through its own software rasterizer: `FUN_00426f70` enumerates
  `*.rfm` files directly with `FindFirstFileA`/`FindNextFileA` and `FUN_004266d0` reads each
  one's display name for the list (section 1.5) — the same engine that draws gameplay draws
  this screen, there's no OS chrome involved at all. That means there's no Win32 dialog to
  "replace" so much as an entire bespoke UI renderer (input handling, layout, the bitmap art
  it draws) that has no Godot equivalent and must be designed fresh — this is real new work,
  not a swap. Reasonable default: build these as Godot `Control` scenes, themed via the asset
  pack (section 2.4) like everything else — including custom packs, which is what makes a
  full replacement asset pack a legitimate reskin of the menus too, not just gameplay art.
- **Engine-level pickers that have no original analogue at all** — chiefly the first-run
  "point me at your `returnfire` install" flow (Phase 0 step 4): a native OS folder picker
  (Godot's `DisplayServer.file_dialog_show`, or a `FileDialog` node) is fine and appropriate
  here on desktop, since this is genuinely a new, one-time, out-of-game-flow operation with
  no in-universe screen to be faithful to. It does not exist on web at all (section 2.5.1) —
  the web build skips it entirely and ships a bundled pack instead.

Concrete screens Phase 4 step 9 needs to actually deliver, not just "menus and HUD" as one
undifferentiated line item: main menu, 1-4 player / team-count select (ties directly into
the 4-player goal, section 4 item 7 — this screen is where that participant count actually
gets chosen), map/level select (reading pack manifests, section 2.4, not raw `.rfm` files
directly — the pack layer is the one thing standing in for `FUN_00426f70`'s directory scan),
options (video/audio/controls, including the 4:3-vs-widescreen choice from section 2.3),
pause, and results/scoreboard. None of this needs Ghidra to build; it's ordinary Godot UI
work, gated only on the pack format (section 2.4) existing first so level-select has
something real to list.

**Visual style: base the menus on the 3DO original, not the PC port — user direction
(2026-09-06), not derived from RE work.** The *flow*/*behaviour* findings above (level-select
scanning files directly, no OS dialogs, self-rendered) come from `RFIRE.BIN` and still apply —
but the actual look or the menus should draw shows the 3DO version's UI, not the PC port's own
menu bitmaps already sitting in `ART/*.RFA` (`PS240.RFA`, `NEWREQLG.RFA`, `1PBSCRH.RFA`, etc. —
section 1.3). **This creates a real dependency this project doesn't have yet:** the 3DO base
game disc (promised, not yet provided) or the already-in-hand "Maps o' Death" expansion disc
(section 1.11) would need their UI assets extracted before authentic 3DO-styled menus can be
built — currently blocked behind the same 3DO extraction work section 4 item 6 already
deprioritizes until the core PC-port game runs. Phase 4 step 9 can still build the *screens*
(layout, flow, state) against placeholder/PC-port styling now without waiting on this; treat
the final visual skin as a separate, later pass once 3DO assets are in hand.

---

## 3. Execution phases

### Phase 0 — Repo setup — DONE (2026-09-05)

1. Godot 4 project at `C:\Users\Alex\Documents\code\returnfire-godot`, separate from data. ✅
   `project.godot` created (GL Compatibility renderer per section 2.2, 60 tick/s default per
   section 1.9's conclusion that there's no original rate to match), plus a placeholder boot
   scene (`game/main.tscn`/`main.gd`) so there's something real to open. Verified headless
   (`godot --headless --path . --import` and a 5-frame run) both exit 0, no errors. The
   editor itself lives at `C:\Users\Alex\Documents\code\tools\godot\` — outside the repo,
   like the Ghidra toolchain, not version controlled.
2. Structure: ✅ (folders already existed as placeholders; `project.godot` now makes
   `/game/` and `/src/` real Godot-recognized paths)
   ```
   /tools/            Python converters + pack validator (Phase 1 lives here)
   /src/              simulation code — GDScript, not GDExtension (section 2.1: GDExtension
                      has no Godot 4 web export, so the sim itself must be GDScript)
   /game/             Godot scenes, scripts, shaders
   /packs/            content packs + the asset ID registry
   /docs/             this plan + format notes as refined
   /build/            converter output — GITIGNORED, and excluded from Godot's own project
                      filesystem via `build/.gdignore` (that one file is tracked; everything
                      else under `/build/` stays ignored — see `.gitignore`)
   ```
3. `.gitignore` must exclude `/build/`, every converted asset, and any copy of original
   data. ✅ (`/build/*` + `!/build/.gdignore` negation, so the ignore marker survives a
   fresh clone + fresh convert run)
4. First-run flow asking the user to point at their `returnfire` install (native OS folder
   picker is fine here — desktop-only, section 2.6). **Not started** — needs the pack
   builder (Phase 1 already emits converted assets to `/build/`; nothing yet turns that into
   an installed content pack under `/packs/`, section 2.4.2) before this flow has anywhere
   real to write its output.

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

**1e. Asset ID registry — DONE (2026-09-06, section 2.4.1); pack emitter — DONE for
sprites/terrain (2026-09-06, section 2.4.2).** `tools/build_pack.py` reads
`build/car/art_atlas.json` + the registry and emits `packs/original_pc/` (gitignored, like
`/build/` — it embeds real extracted pixel data): `pack.json`, `sprites/sprites.json` (all
2165 registry IDs, reusing the existing atlas PNGs as pages rather than re-slicing into
individual files — section 2.4.2 allows this), `terrain/tileset.json` (art id 0-111 → sprite
id + a coarse `terrain_class` guess). `tools/validate_pack.py` (section 2.4.3 requirement 7)
checks it — currently 2165 sprites, 0 errors. Verified end-to-end by rendering sprites from
nothing but the pack's own files, not `build/`.

**What's honestly still missing, not silently papered over:**
- **Pivots are a flat centre-of-cel default** (`pivot_source: "default_center"`), not
  recovered real pivots (section 2.4.3 item 2 is still open). Fine for now since nothing
  renders yet to notice; revisit once Phase 4 step 1/2 makes a wrong pivot visible.
- **`terrain_class` is a coarse string-prefix guess** off the registry ID, not derived from
  gameplay data — good enough to pick a rendering path, not to trust for gameplay logic.
- **No `animations.json`, `audio/`, `fonts/`, or `ui/` yet.** Grouping the coarse-pass
  registry IDs into real animation sequences needs those IDs refined first in most cases
  (section 2.4.1); audio/font/UI packs need their own converters, which don't exist yet.
  None of this blocks Phase 4 step 1 ("render terrain + static objects").
- **Team colour is declared but not consumed by anything**: `pack.json` has a
  `team_colours: {team_a: tan, team_b: green}` field (section 4 item 5) with nowhere yet to
  read it — the actual mechanism (separate cels vs. palette swap) is still open.

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
- **Terrain passability per vehicle type** (new, 2026-09-06, user-flagged as needed for
  parity) — which terrain classes block/slow which vehicle types (e.g. water/mountains
  impassable to ground vehicles, traversable by a helicopter). Not started. See section 4
  item 10.
- Weapon damage, rate of fire, ammo capacity, projectile speed.
- Building and target hitpoints, destruction rules.
- Scoring and mission completion conditions.
- AI state machines and target selection.
- The fixed simulation tick rate.

Record each in `/docs/constants.md` with the address it came from. These become **gameplay
data**, kept separate from art packs (section 2.4.3 item 5).

### Phase 4 — Godot implementation

Keep each step playable, and load everything through the pack layer from step 1:

1. **Load a level, render terrain + static objects — DONE (first pass, 2026-09-06).**
   `game/pack.gd` (`Pack`) and `game/level_data.gd` (`LevelData`) load a content pack and a
   converted `.RFM` level purely via runtime `FileAccess`/`Image` calls — never `res://`
   preload, never `build/` or `*.RFM`/`*.CAR` directly, per section 2.4's boundary.
   `game/terrain_view.gd` (now the project's main scene, replacing the Phase 0 placeholder)
   draws the level's full art-id grid through the pack's `tileset.json` + `sprites.json`, plus
   spawn-point and candidate-pool markers (spawn colour uses the tan/green pair from section 4
   item 5). Verified two ways: a headless `--import`/`--quit-after` pass exits clean, and a
   debug screenshot hook (`RF_DEBUG_SCREENSHOT` env var) produced a real rendered frame of
   `RFMAP001` matching the registry's own contact-sheet renders of the same cels — a
   recognisable coastline, a structure tile placed mid-level, both markers in the right spot.
   **What this first pass doesn't do yet:** no real camera (a temporary debug-only
   overview camera fits the whole map on screen; Phase 4 step 3 replaces this), static
   *objects* are just coloured markers for spawn/candidate positions, not real building/
   target art (building-candidate resolution happens at match-start per section 1.5, so
   there's no fixed art to place from the file alone yet), and there's no menu — pack/level
   are hardcoded `@export` vars on `TerrainView`, to be wired to section 2.6's level-select
   screen once that exists.
2. **One player-controlled vehicle — DONE (playable, not yet authentic; 2026-09-06).**
   `game/vehicle.gd` (`Vehicle`) spawns at the level's team-0 spawn point and moves with
   accel/brake/friction + a turn rate, rendered through the pack's real rotation cels
   (`vehicle.hovercraft.rotation.tan/green`, cels 218-240 — a tank/hovercraft-style tracked
   vehicle with a cannon, per cel 202's side view; re-identified after the section 1.6
   palette fix made the shape unambiguous, replacing an earlier looser "hovercraft" guess).
   Verified with a debug input-override hook (`RF_DEBUG_DRIVE`, off by default) plus a
   screenshot showing real position and heading change over 90 frames, not just "no errors."

   **Fixed (2026-09-06): a real mirroring bug the user caught ("the sprite looks very wrong
   after moving").** The 4-quadrant mirror scheme in `_frame_for_heading()` paired flips
   inconsistently — the base quadrant flipped vertically when it shouldn't have, and the
   270°-360° quadrant didn't flip at all when it needed to — producing a visibly wrong,
   discontinuous sprite at every quadrant crossing. Fixed and verified across 16 headings via
   a new `RF_DEBUG_HEADING` test hook: smooth, continuous rotation now. Tracing it also
   surfaced why the registry still said "cyan"/"teal" for the confirmed-green families
   (section 4 item 5) despite that being settled two sessions earlier: `classify_bulk.py`'s
   auto-numbering re-seeded from the on-disk registry on every re-run, so each of its many
   re-runs saw its own previous output as "already used," causing unbounded drift (one family
   reached `.81`-`.88` instead of `.01`-`.08`) and silently undoing an earlier post-hoc
   "cyan → green" rename every time the script ran again. Fixed at the root (seeding now
   excludes each call's own indices) and at the source (the `"cyan"`/`"teal"` id strings
   themselves, not a patch after the fact) — re-running the script is now provably
   idempotent. This also closes a latent bug that had never actually triggered:
   `vehicle.gd` already expected a `"green"` sprite family for team 1, which would have
   found nothing and silently failed to render, since `RFMAP001`'s only spawn is team 0.

   **Two things this deliberately isn't yet:**
   - **Not authentic movement.** The accel/brake/friction/turn-rate constants are reasonable
     placeholders, not traced from `RFIRE.BIN`. The `.RFM` `vehicle_params` fields
     (`A`/`H`/`J`/`M`/`T`/`unk4`, section 1.5) were decoded structurally but never
     semantically identified, and are almost always `"default"` anyway — tracing the real
     movement-update code is separate, not-yet-started work.
   - **Not the real rendering technique, and the quarter-turn/mirror assumption is
     UNCONFIRMED (checked 2026-09-06, inconclusive).** Section 1.10/2.2 established the
     original does real perspective-projected-quad rendering across 64 discrete headings;
     this uses the 8-9 real sprite frames covering what was *assumed* to be one quarter-turn
     (wide-to-thin), mirrored into the other three quadrants — the "simpler visual target"
     option section 2.2 flagged as acceptable, but the assumption itself was never verified
     against real data, only inferred from how the frames look. Attempted to confirm it
     properly: `FUN_0042dd90` (the per-object render dispatcher) does use a real, data-driven
     "facing table" (entries mapping a heading sub-range linearly onto a run of cel indices,
     `cel = base + (heading - range_start)`, plus a genuine mode-based variant selector —
     groups of 2/4/8 alternate entries chosen by a per-object state byte, a plausible
     candidate for how team colour gets picked at the table level). But a full `.data`-segment
     scan for the inferred 24-byte record layout (`tools/ghidra_scripts/FindFacingTable.java`,
     `FindFacingPair.java`) found nothing conclusive — either the byte layout inferred from
     the decompile is wrong, or the table is built at runtime (`FUN_0042d640` looks like an
     object/entity constructor, not a static-table reader) rather than stored as fixed data.
     **Accepted as a known gap for now** (user's call, 2026-09-06) rather than chased further —
     revisit once more of the game is running and a wrong frame would actually be visible/
     testable in context, or if `FUN_0042d640`'s construction logic gets traced for other
     reasons.
   - **Open question worth checking later:** Return Fire is popularly known for an attack
     helicopter, and box art suggests one may exist as a separate playable unit. Nothing
     found so far in the (coarsely classified) registry has been confirmed as a helicopter
     specifically — worth a deliberate look once more of the ~1960 coarse-pass cels
     (section 2.4.1) get refined.
3. **Camera, scrolling — DONE for a single viewport (2026-09-06); split-screen — NOT
   STARTED.** `TerrainView`'s `Camera2D` follows the vehicle with built-in position
   smoothing (speed 6.0) and `limit_left/top/right/bottom` pinned to the level's real pixel
   bounds (`limit_smoothed` on). Verified with real numbers (a debug hook logged vehicle vs.
   camera position every 30 frames while driving dead straight for thousands of frames): the
   vehicle travelled to nearly 3x the map's width while the camera held flat at the clamped
   edge for hundreds of frames — not just "no errors," an actual measured clamp. **Split-
   screen itself (multiple viewports) is not started** — it needs either a second local
   player or the 4-player goal (section 4 item 7) to exist first before there's anything to
   split the screen between.
4. **Weapons and projectiles — first pass DONE (playable, not yet authentic; 2026-09-06).**
   `game/vehicle.gd`'s `Vehicle` gained a `fired` signal: holding `ui_accept` (or
   `RF_DEBUG_FIRE=1`, off by default) fires a projectile from a fixed muzzle offset ahead
   of the vehicle's nose, gated by a fire-cooldown timer. `game/terrain_view.gd` connects
   that signal and spawns `game/projectile.gd`'s `Projectile` as its own sibling (not a
   child of the vehicle, so its transform doesn't inherit the vehicle's rotation/position
   after launch) — a straight-line mover that self-frees after a fixed lifetime. Verified
   two ways: `RF_DEBUG_DRIVE=1 RF_DEBUG_FIRE=1` plus a screenshot shows multiple
   projectiles visibly in flight along the vehicle's curved path, and a debug print (the
   same pattern as `RF_DEBUG_CAMERA_LOG`) logged real fire events — heading and muzzle
   position at each shot, confirming the cooldown actually gates firing to roughly once
   per `FIRE_COOLDOWN_SEC` of elapsed time rather than once per rendered frame.

   **Two things this deliberately isn't yet**, flagged the same way step 2 flags its own
   movement constants:
   - **Not authentic weapon stats.** `FIRE_COOLDOWN_SEC`, `MUZZLE_OFFSET_PX`,
     `Projectile.SPEED` and `Projectile.LIFETIME_SEC` are reasonable placeholders, not
     traced from `RFIRE.BIN`. Weapon damage, rate of fire, ammo capacity and projectile
     speed are still Phase 3's untouched backlog item ("Extract gameplay constants" —
     `DirectDrawCreate`/input-mapping anchors haven't been visited yet either, section
     2 item 2 of the Ghidra checklist above).
   - **Not a real projectile sprite.** No cel in `packs/registry/asset_ids.json` has been
     confirmed as an in-flight shot — only mounted, static `prop.missile_pod.*` /
     `prop.missile_rack.*` decoration cels exist. Rather than guess an unverified sprite
     id, `Projectile._draw()` reuses `terrain_view.gd`'s existing flat-colour-marker
     approach (team-coloured filled circle) already used for spawn/candidate markers.
   - **No collision yet.** Projectiles don't hit terrain, vehicles, or targets — there's
     nothing to hit until step 5 (destructible targets/buildings) exists. This is
     "fire input produces a moving, visible, self-expiring projectile," nothing more.
5. **Destructible targets and buildings — first pass DONE (playable, not yet authentic;
   2026-09-06).** New `game/target_pool.gd` (`TargetPool`) reimplements section 1.5's fully
   -traced candidate-pool mechanism directly — not a guess, the algorithm was already known
   from the `FUN_00432600`/`FUN_00432710`/`_DAT_0048ca20` trace: build one `TargetPool` per
   pool id from `level.candidate_pools`, each picking one candidate at random as its active
   target and starting with a replacement budget of `candidates.size() >> 1`; when the
   active target is destroyed, decrement the budget and — if budget and another intact
   candidate both remain — activate a new random one, exactly `FUN_00432600`'s behaviour;
   otherwise the pool goes silent for the rest of the match. `terrain_view.gd` wires this
   to the Phase 4 step 4 projectiles: any projectile within `TARGET_HIT_RADIUS_PX` of a
   pool's active target destroys it. The debug marker rendering (originally just a hollow
   outline per candidate, all identical) now distinguishes the pool's one live target
   (bright filled square) from remaining intact candidates (hollow outline) from spent ones
   (dim X) — a real gameplay-state read, not just a static rect.

   **Verified two ways**, deliberately not relying on real vehicle aim (not practical to
   make deterministic in a short automated run): a standalone `TargetPool` unit test
   (2000 random trials x candidate counts 0-19) confirmed budget decrements by exactly 1 per
   destruction, replacement only activates an intact, previously-inactive candidate, the
   pool never goes silent early while budget and an intact candidate both remain, and never
   takes more than `budget + 1` destructions to go silent. A second, full-integration test
   loaded the real scene, read a real level's (`RFMAP110`, 11 candidates/pool) actual active
   target position, spawned a projectile directly on it, and confirmed
   `TerrainView._check_target_hits()` destroyed it and activated a different real candidate
   from the same level file, budget 5 -> 4. Also spot-checked pool construction against
   several real levels via a debug print (`RF_DEBUG_TARGET_LOG=1`): `RFMAP001` (1 candidate
   in pool B, budget 0 — the single-candidate levels this project has mostly been testing
   against so far never exercise the replacement path at all) and `RFMAP110` (11/11,
   budget 5/5) both matched section 1.5's formula exactly.

   **Two things this deliberately isn't yet**, flagged the same way steps 2 and 4 flag
   their own placeholders:
   - **Not authentic hit detection or hitpoints.** `TARGET_HIT_RADIUS_PX` is a placeholder
     — targets die in exactly one hit here. RFIRE.BIN's real building/target hitpoints and
     destruction rules are still Phase 3's untouched backlog item.
   - **Not real target/building art.** This was flagged as a known gap back in step 1
     ("building-candidate resolution happens at match-start... so there's no fixed art to
     place from the file alone yet") — now that match-start resolution is real, rendering
     is still the same flat-colour-marker approach as spawn points, not real building art.
     The asset registry does have plausible candidates worth tracing next —
     `structure.bunker.tan.*`/`structure.bunker.teal.*` and a 20-frame
     `structure.building_wall_damaged.*` sequence (a strong hint the "intact" bit-field
     state this project already decoded, `tile & 0x3f80 == 0xb00`, is one of several
     progressive-damage frames, not a binary intact/gone flag) — but which cel(s) `FUN_0042e4f0`
     or its neighbors actually pick for these tiles hasn't been traced. Left open rather than
     guessed at.
   - **No win/lose condition.** Section 4 item 1 is still open — nothing declares a
     match-won/lost state when a pool's budget is fully spent. This step only makes the
     pools themselves behave correctly, not what (if anything) happens when both go silent.
6. **Enemy AI — first pass DONE (playable, not yet authentic; 2026-09-06).** Unlike step 5,
   this is a from-scratch placeholder, not a reimplementation of anything found in
   `RFIRE.BIN` — Phase 3's "AI state machines and target selection" backlog item is still
   completely untouched, no anchor has even been picked yet. `game/vehicle.gd`'s movement/
   rendering/firing code was refactored to expose two overridable seams, `_get_controls()`
   and `_wants_to_fire()` (default implementations unchanged: real input or the existing
   debug hooks) — everything else (movement integration, rotation-frame rendering, firing,
   cooldown) is shared, not duplicated. New `game/enemy_vehicle.gd` (`EnemyVehicle extends
   Vehicle`) overrides just those two seams with a seek-and-shoot placeholder: idle beyond
   `DETECT_RANGE_PX`, otherwise turn toward the target and close in, firing once aimed
   within `AIM_TOLERANCE_DEG` and inside `FIRE_RANGE_PX`. `terrain_view.gd` spawns one
   `EnemyVehicle` per spawn point whose team differs from the player's, targeting the
   player vehicle directly — which means 1-player levels (no second spawn point in the
   file at all) correctly spawn nothing extra, and 2-player levels get exactly one
   opponent, straight from real level data, no special-casing needed.

   Verified two ways: a deterministic test drove `EnemyVehicle._process()` directly at a
   fixed 1/60s timestep (headless mode doesn't hold a stable frame rate, so real
   `await get_tree().process_frame` timing isn't reliable for a rate-dependent physics
   check) against a real level's (`RFMAP110`) real spawn data, confirming it turned from a
   90-degree misaim to face a repositioned target within tolerance and fired 6 times over
   2 simulated seconds, then confirmed it went fully idle (zero turn, zero thrust) the
   instant the same target was pushed just past `DETECT_RANGE_PX`. A second, live-scene
   run with both vehicles moving for real (`RF_DEBUG_DRIVE=1` driving the player,
   `RF_DEBUG_AI_LOG=1` logging the enemy's own targeting state every 30 frames) showed the
   enemy actively steering toward a real, continuously-moving player position, not just a
   static test target.

   **This is a placeholder in every dimension, not just movement/rendering** (flagged the
   same way steps 2/4/5 flag their own gaps): no pathfinding (it drives straight at the
   target regardless of terrain or obstacles), no cover or squad behaviour, no difficulty
   tuning, and no vehicle-vs-vehicle damage yet either — an enemy's shots can hit a
   destructible target's active position exactly like the player's can (step 5's hit-test
   is target-agnostic), but nothing yet lets a projectile hit a *vehicle*, player or enemy.
   That's a real gap for "opposes the player" to eventually mean something, not an
   oversight being glossed over.
7. **Mission objectives, scoring, level progression — first pass DONE for the flag-spawn
   trigger only (2026-09-06); everything past that is still missing.** Reading
   `FUN_00432710`'s exact branch logic (section 4 item 1) rather than just its "gates
   whether..." summary found the precise condition: in real (non-debug) play, where
   `DAT_00442b00` is confirmed to stay 0 forever (no code anywhere writes it except the
   hidden debug menu itself), the function falls through to spawn its dedicated object
   exactly when a pool's active target is destroyed **and no replacement is available**
   (budget exhausted, or no intact candidate left) — precisely the condition
   `TargetPool.destroy_active()` (Phase 4 step 5) already returns `false` for, with no
   changes needed to that class at all. New `game/flag_marker.gd` (`FlagMarker`) makes this
   real: `terrain_view.gd`'s `_check_target_hits()` spawns one, using the confirmed
   `marker.capture_flag.<team>` art (section 4 item 1 / document 24), exactly when a pool
   goes silent. Verified with a real-scene integration test against `RFMAP001` (whose pool
   "b" has a single candidate and budget 0, so one hit exhausts it immediately): confirms
   exactly one `FlagMarker` spawns, at the destroyed target's position, with real sprite
   frames loaded, and that firing again doesn't spawn a second one.

   **What this deliberately isn't:** the flag marker doesn't move, can't be picked up by any
   vehicle, there's no "carry" state, no home-base check, and nothing declares a match won or
   lost — section 4 item 1's "explicitly not yet found" list is unchanged. Which physical
   pool ("a" tile `0xB4` vs "b" tile `0xDC`) corresponds to which team's flag colour is also
   still unconfirmed; `POOL_FLAG_COLOURS` picks a fixed, arbitrary mapping purely so two
   pools in the same level are visually distinguishable. This is the spawn *trigger* made
   real and precisely verified, not mission objectives/scoring/level progression as a whole.
8. Audio: SFX and music.
9. Menus and HUD — all custom Godot `Control` UI, no native dialogs; see section 2.6 for the
   concrete screen list and why the original gives no shortcut here (it's self-rendered too).

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
   section 2.2) quietly assume exactly 2 (section 0's 4-player goal, section 4 item 7).
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

1. **What ends a match? MAJOR NEW LEAD (2026-09-06): a capture-the-flag mechanic, tied
   directly to the candidate-pool buildings section 1.5 already fully traced.** The user
   (who owns and has played the original) reported the real win condition is returning an
   enemy flag to your own base, plus a separate life system — prompting a fresh anchor
   search rather than continuing to push on the dead-end `FUN_0042c4d0` trail below.

   **Confirmed, from a hidden developer debug menu still shipped in the binary:**
   `FindSymbol.java flag` turned up `s_Flag_in_first_building:_%s_00442a84` — a debug string
   reading literally "Flag in first building: %s". It's one of 4 items in a debug-menu
   table at `0x00442b38` (`FUN_004065c0`, a generic menu-widget renderer reused for several
   hidden debug screens — this one also has "Display FPS: %s", an "AUDIO SCREEN" sub-menu
   link, and "EXIT"; a wider string dump nearby also found "Objects: Free %3d, Active %3d,
   Inactive %3d, Useless %3d", another live debug readout). The "Flag" item's live-value
   slot is `DAT_00442b00`.

   **Confirmed, from the asset registry:** `marker.capture_flag.01`-`.16` (cels ~1829-1848,
   already found during document 19's classification pass and originally noted only as "red
   flag on a pole... possible capture-point marker") is actually **two team-coloured
   waving-flag animations** — rendered and looked at directly (document 6's rule 1): ~13
   frames in an orange/red palette, ~7 in green. That's a real, confirmed two-team flag
   prop, not a guess anymore.

   **Confirmed, the direct code link — this is the part that matters most:** `FUN_00432710`
   is the *exact same function* section 1.5 already traced as the candidate-pool
   destruction handler (decrements a pool's replacement budget, calls `FUN_00432600` to
   activate a replacement target — precisely what `game/target_pool.gd`'s `TargetPool`
   reimplements, Phase 4 step 5). It reads `DAT_00442b00` — the debug menu's own "Flag in
   first building" value — via `bVar6 = DAT_00442b00 == 0;`, checked *before* decrementing
   the budget, and gating whether destroying the active target falls through into a
   `FUN_0042c290(0x44e3c0, pool_index, ...)` object-spawn call. `0x44e3c0` (a 6-field
   object-type descriptor: an art/CCB pointer, three callback function pointers, and a
   template pointer) has **exactly one cross-reference in the entire binary** — this call
   site — meaning it's a dedicated, unique object type, not a shared/generic effect. Its
   callbacks: `FUN_004328f0` clears `&DAT_0045ae48[team]` (the same per-team tracking array
   used elsewhere for locked-on-target/reticle state, section 4 item 5's lead) if this
   object was the one tracked there; `FUN_00432920` is a real per-frame *homing* update —
   it computes a heading through `&DAT_00481390`/`&DAT_00481394`, the same cosine/sine
   lookup tables section 1.10 found driving vehicle heading math, moves the object along
   that heading every frame, and sets a global status bit (`_DAT_0048c77c |= 0x200`) when
   its own team-index field differs from another tracked object's.

   **The exact trigger condition — SOLVED (2026-09-06), read from `FUN_00432710`'s full
   decompile rather than just its summary.** `DAT_00442b00` has **exactly 2 code
   cross-references in the entire binary**: this read, and one more inside `FUN_004065c0`
   itself (the debug-menu renderer reading its own live value to display it) — **no write
   site anywhere**, confirmed by exhaustive `FindDataXrefs.java` search. The debug menu's
   generic widget-navigation code *can* increment/decrement it (through an indirect
   `*(int**)(item+0x1c)` pointer, the same mechanism every live-value menu item uses), but
   only while that hidden menu is open — nothing in normal gameplay code ever touches it.
   Its raw file bytes are `00 00 00 00` (confirmed zero at rest). Put together: **in every
   real, non-debug game, `DAT_00442b00` is always 0**, and `bVar6 = (DAT_00442b00 == 0)` is
   therefore always `true`. Reading the actual branch under that condition (not just its
   gloss) gives the precise rule: the flag-object spawn (`FUN_0042c290(0x44e3c0, ...)`) is
   reached exactly when **the destroyed tile was the pool's tracked active target, AND no
   replacement is available** — either the budget was already exhausted before this
   destruction, or `FUN_00432600` finds no remaining intact candidate to activate. (A
   nonzero `DAT_00442b00`, reachable only by a developer leaving the debug menu forced on,
   skips replacement checking entirely and always falls through to the flag spawn — a
   plausible manual test hook for the flag object itself, not something a real match ever
   exercises.) This is *exactly* the condition `game/target_pool.gd`'s `TargetPool.
   destroy_active()` (Phase 4 step 5, already fully verified against this same traced
   algorithm) returns `false` for — no reinterpretation needed, the existing class already
   computes the right answer. **Read together, this is no longer just a hypothesis about a
   code link: it's a precisely known, verified trigger condition** — a pool's flag object
   appears exactly when that pool's destructible targets are fully used up. Made real in
   Phase 4 step 7's first pass (`game/flag_marker.gd`, section 3).

   **Explicitly still NOT found, so still not a closed case overall:** what actually
   places/drops/picks up the flag object once spawned (only the *spawn* trigger is now
   precisely known), any "carried by vehicle" state on a vehicle object, a "home base"
   position check, or an actual win/lose declaration anywhere. `FUN_0042c4d0` was still
   checked and **ruled out** as the win trigger (see below, unchanged) — the flag lead is a
   different, better-supported trail than that dead end, not a replacement finding for the
   same code path.

   **Also from the user, not yet investigated at all: a life system.** A raw byte search
   (`FindBytes.java`) for literal `"Life"`, `"Lives"`, and `"LIVES"` anywhere in the binary
   came back with **zero hits** — if a life system exists, it isn't debug-labelled with
   text anywhere, so string-anchoring (this session's whole approach) won't find it. The
   registry's `ui.icon.vehicle_mini.01`-`.20` (tiny vehicle silhouettes, already tagged
   "likely minimap/HUD unit marker") are a plausible but unconfirmed alternative rendering
   for a lives readout (a row of small vehicle icons, no text needed) — worth checking
   first before picking a colder anchor (e.g. tracing what happens when a vehicle's health/
   destruction state reaches zero, `FUN_0042c4d0`'s callers, from the *vehicle* side this
   time rather than the *building* side).

   **Original dead end below, still accurate, kept for the record:** the previous next hop,
   `FUN_0042c4d0`, was checked and **ruled out** (2026-09-06) — it's a generic object-death
   utility called from 35+ unrelated sites, not a win-condition trigger. The trail from
   there runs into a large general AI-targeting/combat subsystem with no clear "declare
   victory" anchor.
2. The coastal table's (`0x00447038`) `+9` "height_seed" byte and the runtime tile value's
   elevation-ish bits 25-27, set by `FUN_0042e4f0` — dumped but not chased; likely
   physics/movement, not rendering (section 1.5). (Bits 14-15 are no longer part of this
   question — see RESOLVED below.)
3. The two small constant `.RFM` header fields `0x04`-`0x07` (`"TM\0\x05"`) and `0x0C`-`0x0D`
   (`01 01`) — confirmed constant across all 204 real files, exact meaning still a guess
   (section 1.5). Very low priority.
4. Purpose of the `count * 8` byte table at `ART.CAR` offset `0x23F24`.
5. **How is team colouring done?** Palette ranges or separate cels? Still open at the
   mechanism level, but **the two team colours themselves are now settled: tan and green**
   (confirmed by the user, who owns and has played the original, 2026-09-06 — not something
   this project derived independently, but cross-checked against art before accepting it, see
   below). The "4 `PRE0==17` cels are a team-colour swatch" lead from section 1.6 is
   **RULED OUT (2026-09-06)**: rendered and eyeballed (per section 5's own rule — never trust
   code alone), the 4 cels are visibly a 16x16 concentric-ring bullseye (purple/black/yellow,
   one ring recoloured red/blue per cel) — a target-lock reticle, not a colour swatch.
   `FindConstant.java` found no literal reference anywhere in the binary to any of their 4 cel
   indices (1969-1972) or the equivalent CCB byte offset, consistent with an animated HUD
   overlay whose frame index is computed at runtime rather than hardcoded per-frame. The
   `GetNearestPaletteIndex`-built masked-translation-table infrastructure (section 1.6) is
   still a plausible *mechanism*, but there is no lead pointing at *where* it's invoked.

   **Tan/green confirmed independently by art, not just recalled (2026-09-06).** Registry
   classification (section 2.4.1) had labeled several duplicate-coloured art families
   "blue"/"cyan"/"teal" by eye. When told the real colours are tan and green, this got
   checked against actual pixel data rather than just renamed on faith: three large,
   completely independent cel ranges — the running-trooper animation (`character.trooper_run`,
   44/44 cels), the trooper head/shoulders rotation (`character.trooper_head.rotation`, 22/22),
   and the hovercraft's in-level rotation silhouette (`vehicle.hovercraft.rotation`, 9/9) —
   are **100% green-dominant by mean pixel colour, zero exceptions**. The earlier "cyan" label
   came from a colour heuristic that only ever compared blue against red and never checked
   green at all, so real green art was mislabeled throughout; registry IDs corrected (~90
   cels renamed, see `tools/registry/classify_bulk.py`'s team-colour-fix section).

   **One specific earlier lead walked back.** The hovercraft hull-*icon* pieces at cels
   173/178/193/198 (batch 3, section 2.4.1) — previously flagged as *the* team-colour lead
   because they duplicate in tan and a second colour — are genuinely **blue**-dominant when
   checked (not green). They don't match the confirmed tan/green pair, so that specific lead
   is no longer good evidence for anything about team colouring; still real duplicate-coloured
   art, purpose unknown. The tan/green evidence above (found afterward, in unrelated cel
   ranges) is what actually confirms the colour pair.

   **Still open:** the *mechanism*. Is tan/green done via separate pre-built cel sets (the
   pattern the still-valid trooper/hovercraft-rotation duplication is consistent with) or a
   runtime palette swap? Needs a fresh Ghidra anchor, most likely starting from wherever a
   vehicle's or trooper's CCB is queued per-frame (candidate: `FUN_0042dd90`, already known
   to do heading-based frame selection off the same `ART.CAR` CCB array, section 1.10) to see
   whether team is read there. Blocks section 2.4.3 requirement 3's pack-format decision
   (palette-range field vs. separate team-mask texture) only in the sense that knowing the
   *real* mechanism would justify supporting just one instead of both defensively — not
   otherwise a hard blocker.
6. **3DO support: base game + "Maps o' Death" expansion extraction** (section 1.11, new
   2026-09-05; scope widened 2026-09-05) — **deliberately deprioritized (2026-09-05): the
   user wants the core PC-port game running first** before this gets picked back up.
   `trapexit/3doplay` is already cloned for reference at
   `C:\Users\Alex\Documents\code\tools\3doplay\` (outside the repo, not committed, nothing
   from it copied into this project) for whenever this resumes. A whole new goal, not a
   single question, and
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
   are the same platform and (almost certainly) the same asset formats. **Also now a
   dependency for menu visual styling** (2026-09-06, section 2.6, item 8) — the user wants
   the menus based on the 3DO version's look, not the PC port's, so this extraction work
   eventually unblocks that too, not just the "Maps o' Death" goal.
7. **4-player support** (section 0, new 2026-09-05) — a whole new goal, not a single
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
8. **A custom Godot UI system for all game-flow screens** (section 2.6, new 2026-09-05) — not
   a decompilation question, an engineering goal: no native OS dialog can carry menus, level
   select, mode/player-count select, options, pause, or results, because the target platforms
   (Linux/ARM/web) have no shared native-dialog story to lean on even if the original used
   one. It doesn't, as it happens — `RFIRE.BIN` renders its own level-select screen through
   its own rasterizer (`FUN_00426f70`/`FUN_004266d0`, section 1.5), so there is no Win32
   dialog being "replaced," just an entirely bespoke original UI with no Godot equivalent to
   reuse. Needs: the concrete screen list in section 2.6, each built as a themed `Control`
   scene; level-select reading pack manifests (section 2.4) rather than scanning `.rfm` files
   directly; and the player-count screen wired to whatever the 4-player goal (item 7) lands
   on. Blocked only on the pack format existing first — no Ghidra work required here at all.
   **Visual style directive (2026-09-06, user):** base the look on the 3DO original, not the
   PC port's own menu bitmaps — see section 2.6's new note. Adds a real dependency on the 3DO
   disc extraction work (item 6) for the actual skin, though the screens themselves (layout,
   flow, state) don't need to wait on it.
10. **Real vehicle-rotation rendering ("the turning sprites") — RE-PRIORITIZED (2026-09-06,
    user request); one real bug found and fixed, the deeper architecture question still
    open.** Previously recorded in section 3 Phase 4 step 2 as "accepted as a known gap for
    now" — the current renderer mirrors 8-9 real sprite frames across 4 quadrants under an
    *unconfirmed* assumption that they cover one real quarter-turn, and a full `.data`-segment
    scan for the inferred facing-table layout (`FindFacingTable.java`/`FindFacingPair.java`)
    found nothing conclusive.

    **A real bug, found from a user-supplied screen recording of the glitch (2026-09-06).**
    Extracted and tracked the vehicle sprite across the video frame-by-frame (ffmpeg +
    a colour-threshold tracker): during a turn, the sprite genuinely breaks into disconnected
    fragments (a thin "hook" shape, then a lone sliver) for several frames right around the
    90-degree quadrant boundary, not just a rendering-tool artifact. Comparing the raw
    `vehicle.hovercraft.rotation.tan` cels (218-225, non-transparent pixel counts 220, 166,
    69, 34) directly against `.green` (232-240, 9 frames) found the root cause: **tan only had
    8 registered rotation frames where green has 9** — cel 226 (11 non-transparent pixels,
    same hue/shape family, a clean continuation of tan's thinning sequence) had been
    misclassified by the original bulk pass as `prop.debris_faint.420` (cels 227-231 checked
    the same way and are genuinely blank padding, confirming 226 is the real last frame).
    `vehicle.gd`'s `_frame_for_heading()` was therefore stretching tan's last frame (225,
    already a disconnected-looking "hook") across a wider heading range than green's
    equivalent, and mirroring that same broken-looking frame across the quadrant seam.
    **Fixed**: registry corrected (cel 226 → `vehicle.hovercraft.rotation.tan.09`,
    `tools/registry/classify_bulk.py`'s established correction-block pattern), pack
    regenerated — no code change needed, `Vehicle.setup()` already builds `_frames` by
    scanning the pack for every matching id. Verified with a headless script dumping
    `_frame_for_heading()`'s heading-to-frame mapping directly: frame `.08` (the "hook") now
    covers only heading `[74,85)` instead of running to the exact 90-degree seam, and the new
    `.09` (an 11-pixel sliver) is confined to `[85,90]` — a measured, not just eyeballed,
    improvement. Full writeup: [document 25](process/25-worked-example-turning-sprite-video.md).

    **What this does and doesn't fix.** This closes one real, confirmed asymmetry bug, but
    the deeper question is unchanged: this whole approach is a flat-sprite-mirror
    approximation of a technique section 1.10 already found isn't how the original renders
    vehicles at all (real perspective-projected 3D quads, 64 discrete headings). Fixing the
    frame-count bug makes the approximation less bad; it doesn't make it authentic.

    **Attempted (2026-09-06), blocked, not resolved: a real reference capture via DOSBox-X.**
    `C:\DOSBox-X` has a pre-built Windows 95 install (`hdd.img`, `win95.conf`) with the real
    game already copied to `C:\Games\Return Fire\RFIRE.BIN` — confirmed present via `IMGMOUNT`
    and `dir` (401,920 bytes, matching the known file size). Booting Windows 95 itself
    (`cd \windows`, `win`) consistently stops at "Cannot load a device file... 
    C:\WINDOWS\SYSTEM\VMM32\IOS.VXD" — not a cosmetic missing-driver warning like the other
    VXD messages this project has seen; `IOS.VXD` is Windows 95's core 32-bit disk-access
    supervisor. Pressing a key sometimes appeared to let DOSBox-X exit entirely with no crash
    logged (no Windows Event Viewer entry), and on a later attempt did not advance past the
    message at all even after confirming DOSBox-X had real keyboard focus — a genuine boot
    blocker with this specific disk image/config pairing, not something to keep retrying blind.
    **Parked, not chased further this session** (user's call, 2026-09-06) — next real attempt
    should start from *why* `IOS.VXD` fails to load in this `hdd.img` (a corrupt/incomplete
    Windows 95 install, a DOSBox-X IDE/CPU-type config mismatch with this particular image, or
    a missing file that needs restoring from the original install media) rather than repeating
    the same boot sequence again.
11. **Terrain-based vehicle passability — NOT STARTED, new backlog item (2026-09-06,
    user-flagged as needed for parity).** Different vehicle types (helicopter, tank,
    support/jeep, armoured car — section 3 Phase 3's own list) should be restricted or slowed
    by terrain type (e.g. water/mountainous terrain impassable to ground vehicles, crossable
    by a helicopter) — currently every vehicle can drive anywhere the map allows. **Likely
    connects to already-dumped-but-unchased data**: section 4 item 2's coastal-table `+9`
    "height_seed" byte and the runtime tile value's elevation-ish bits 25-27 (`FUN_0042e4f0`,
    section 1.5) were flagged as "likely physics/movement, not rendering" back when first
    found — this is probably exactly that mechanism, now with a concrete gameplay reason to
    chase it instead of just a loose end. Also needs the coarse `terrain_class` field
    (section 2.4.2, currently a string-prefix guess "good enough to pick a rendering path,
    not to trust for gameplay logic") turned into something a passability rule can actually
    read. No anchor work done yet.
12. **Is there an on-foot infantry / rescue mechanic?** (new 2026-09-06, from asset ID registry
   classification, section 2.4.1) — not previously suspected; not in section 0's feature list.
   `ART.CAR` cels 655-754 are a ~100-frame running/walking human animation (tan/blue team
   colours) at real gameplay scale, not a portrait or icon. Nearby cels read as rescue/POW-camp
   dressing: red-cross-like markers (821-825, 858), barred-cage panels (826-827, 845-846), a
   doorway (863), building-wall dressing (834-838, 855-857, 864-869), and a chaotic multi-
   figure clash animation (801-820) that could be a capture/melee struggle. A handheld weapon
   sprite (cel 1940, olive rifle silhouette + ammo-crate parts at 1942-1947) suggests the unit
   is a real controllable/AI actor, not just scenery. **None of this is traced through code
   yet** — it's a pixel-level reading of the art alone. Needs: checking `.RFM` entity/spawn
   data (section 1.5) for an entity type this could correspond to, and/or a Ghidra anchor on
   whatever renders a non-vehicle CCB at human scale. If confirmed, this is a real feature
   addition to scope, not just an art-classification footnote — the original 2-player PC port
   may have had a rescue objective type never mentioned in this plan before now.
13. **Should Godot replicate the original's perspective-projected terrain rendering, or keep
    the flat `TileMapLayer` approximation? DECIDED (2026-09-06): replicate it, via a real 3D
    scene — not yet implemented.** Section 1.10 point 5 confirms (by fully decompiling the
    terrain blitter, not just noting it shares a table) that the original's ground plane is a
    genuine per-scanline perspective projection — the same real 3D camera system vehicles
    already use (section 1.10 points 1-4) — not a flat top-down map with 3D objects on top of
    it. This is a materially bigger authenticity gap than the vehicle-rotation question
    (section 4 item 10): it's the single most visually defining trait of this game's look (the
    tilted, horizon-receding island view the user's screenshot shows), and it affects every
    level, not one sprite family.

    **The decision:** migrate world rendering to a real Godot 3D scene (`Camera3D` + a textured
    `MeshInstance3D` ground plane + billboard `Sprite3D`s for vehicles/objects) rather than
    hand-porting the original's fixed-point per-scanline reciprocal-table math into a custom 2D
    shader — Godot's own camera pipeline does the actual perspective projection for both
    terrain and objects "for free," which was judged lower-risk and less custom math than
    reimplementing a non-affine 2D warp by hand. Full rationale and a 6-phase implementation
    plan (RE unknowns first, then scaffolding/terrain/vehicles/objects/cutover, each
    independently screenshot-verified, existing flat rendering kept working throughout) are in
    section 2.2 and `C:\Users\Alex\.claude\plans\tingly-booping-wall.md` (outside this repo —
    section 2.2's summary is the durable record if that file is ever unavailable).
    **Phase 0 DONE (2026-09-06) — see section 1.10 point 6.** The tilt is a genuine fixed
    constant, not a runtime camera parameter: exactly 45.0° (`0x200000` raw angle units,
    algebraically exact via the confirmed `2π / 0x1000000` angle scale), hardcoded as a literal
    inside the one shared object constructor (`FUN_00416cb0`) and written exactly once at game
    init — no other call site touches it, and the terrain blitter itself never writes back to
    it. `DAT_00443000` (focal length, exactly 300.0 fixed — corrected from an earlier "76800"
    slip) remains read-only everywhere checked. No rotation/yaw term exists in the terrain
    blitter at all. This confirms Phase 1's `Camera3D` assumption (fixed pitch, zero yaw,
    X/Z-only translation) directly from the decompile. The one number Phase 0 leaves for
    Phase 2 to pin by screenshot-matching rather than algebra: the exact effective FOV/eye
    height (see section 1.10 point 6 for why that's a deliberate scoping call, not a gap).
    **Phase 1 (scaffolding) not yet started.** Gameplay logic (movement, `TargetPool`,
    hit-testing, the flag-spawn trigger) does not change — this is scoped as a rendering-layer
    migration only.

**RESOLVED:**
- **The fixed sim tick rate** — **section 1.9** (2026-09-05). There isn't one, and there was
  never going to be one to find: `FindVtableCall.java` (new script — COM vtable calls have no
  symbol to search for) located the `IDirectDrawSurface::Flip` call at vtable offset `0x2c`
  in `FUN_004300e0`, the game's one screen-present routine, called unconditionally every
  iteration by `FUN_004312c0` (already known from the `WinMain` idle-loop trace). Fullscreen
  display modes call the blocking `Flip(NULL, DDFLIP_WAIT)`, which doesn't return until the
  next vertical retrace — so the loop's effective rate in fullscreen is just "whatever the
  display's refresh rate is," a side effect of presentation, not a counted tick. Windowed
  modes present via `Blt`/`BltFast` instead, with no wait, so windowed play isn't rate-limited
  by this mechanism at all. Combined with the earlier no-`Sleep()` and no-`SetTimer` results,
  all three classic pacing mechanisms are now accounted for, and none of them is a fixed-Hz
  quantum. Port implication: pick a physics tick rate for Godot's own determinism needs
  (section 2.1); there is no "real" original rate to match.
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
