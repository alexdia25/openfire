# 80. Worked example: what the home pad really looks like, and how the original tells you you're in position to dock

**Question:** the user asked how a player is meant to know they're positioned to dock, and pointed out the home pad renders as a plain beige circle. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the "beige circle" was never the pad — it was hiding it

The circle is `game/debug_marker_renderer.gd`'s spawn-point marker (`TEAM_COLOURS[0] = Color(0.82, 0.71, 0.55)`, a flat debug primitive, its own header says plainly "**none of this is real game art**"), baked onto an always-on overlay plane
(`DebugMarkerOverlay3D`) that document 44 already gated behind an env var — but the wrong way round: `RF_DEBUG_NO_MARKERS=1` had to be set to **hide** it, so every ordinary run showed it **on top of** the real terrain, including the home tile.
Underneath it the whole time was cel **90** (91 for the other team), the level's actual `HOME_ART_BASE` ground art. Extracting it directly (`packs/original_pc/sprites/art_atlas.png` at its sprite rect) shows a **bolted grey hatch with a yellow-and-black
hazard-striped border**, a brown (green for team 1) centre panel split down the middle like a two-leaf door — a hangar entrance, not a "bullseye" as the registry had it (`marker.target.bullseye_green/cyan`, `confidence: visual`, evidently written without a close
look). Corrected by hand (`packs/registry/asset_ids.json`, matching `AUDIT10` in `classify_batch2.py`): `structure.hangar_hatch.tan` / `.green`. Document 44, which had *already* correctly called it "the spawn tile's striped pad" in passing, gets a correction note pointing here.

**Fixed:** `DebugMarkerOverlay3D` now defaults off (`RF_DEBUG_MARKERS=1` to opt in, replacing the old opt-out `RF_DEBUG_NO_MARKERS=1`), so the real art shows in ordinary play. A screenshot confirms the hatch, hazard stripes and all, right where the tank sits.

## Step 2: the readiness signal — `FUN_0040b400`

Document 77's dock trigger (the shared per-tick check: `if (moving) skip; if (wrong tile) skip; if (out of tolerance) skip; if (a fire button is held) dock; else FUN_0040b400(player)`) has exactly one caller (`FindCallRel.java 40b400`: only
`0x40bfb4`, inside that same check) and exactly one call site downstream from the "not pressing anything" branch. So **`FUN_0040b400` runs precisely when a vehicle is stationary, on its own pad, within docking tolerance, and not currently pressing a button** —
which is exactly "you are in position; a fire press would dock you now." Decompiled:

```c
void FUN_0040b400(int player) {
   accum[player] += dt * (0x2666/65536);              // ~0.15 a tick
   while (accum[player] > 1.0) {
      cel = celtable[player == 0 ? 90 : 91];           // this player's own home pad cel
      plut = *(int*)(cel + 0xc);                        // the cel's PLUTPtr, dereferenced: a runtime colour-table pointer
      // rotate 7 consecutive 16-bit colour words at plut+0x30..plut+0x3c by one slot
      saved = word_at(plut, 0x3c);
      for (each of the 6 pairs, highest to lowest) word_at(plut, off+2) = word_at(plut, off);
      word_at(plut, 0x30) = saved;
      accum[player] -= 1.0;
   }
   if (a camera is following this player) camera.flags = (camera.flags & ~0x1300) | 0x2c80;   // a UI/state bit, not chased further
}
```

**A colour-cycle animation, run only while parked and ready.** The accumulator reaches 1.0 every `65536/0x2666 ≈ 6.83` ticks, so it steps **about 9.1 times a second** — a fast strobe, consistent with a hazard-light border. This is the game's actual answer to
"how do you know you're in position": **the pad's warning-stripe border visibly animates while you sit there, and stops the instant you drive off or the moment you dock.** Nothing else marks a stationary, correctly-placed vehicle; there is no separate HUD
readout for it in anything traced so far.

## Step 3: pinning down the exact bytes, and finding they aren't the hatch's own colours

Cel 90/91 are ordinary (`PRE0 == 0`) cels, so `PLUTPtr` is a file offset into the **shared** palette (`0x282CC`, document 20), and the load-time fixup (`FUN_004248c0`, decompiled: `if (field != 0) field += buffer_base` for `NextPtr`/`SourcePtr`/`PLUTPtr`
alike, no reformatting) just adds the loaded-file's base address to it — so the bytes the rotation touches at runtime are, byte-for-byte, the same bytes sitting in `ART.CAR` at file offset `0x282CC + 0x30` through `+0x3D`. Reading them directly:

```
+0x30..+0x3D:  92 bf 75 00 89 b5 71 00 83 ac 6c 00 7d a2
```

Running the **exact** rotate the disassembly performs (save the word at `+0x3C`, shift the other six up by one slot, drop the saved word into `+0x30`) in Python for all 7 steps returns to the starting bytes exactly at step 7, confirming the period-7 read is
right. Interpreting the RGBQUAD entries these bytes belong to (`tools/convert_car.py`'s own `read_palette`, entries 12-14) gives a real, reproducible 7-step sequence — entry 12 alone cycles `(117,146,191) -> (191,125,162) -> (162,0,108) -> (108,131,172) ->
(172,0,113) -> (113,137,181) -> (181,0,117) -> (117,146,191)`, a blue-grey/magenta flicker, not the yellow/black of a hazard stripe.

**Then the check that mattered:** does cel 90's own 32 x 32 indexed bitmap use palette entries 12-15 (pixel byte values 22-25, after the documented "`shared_plut[byte-10]`" rule) *anywhere*? Extracting its raw indexed pixels (not the already-converted PNG) and
scanning all 1024 of them for byte values 22-25 found **none** — the hazard-stripe border actually uses a *different* repeating 7-value pattern (`39, 62, 65, 66, 61, 38, 39`, i.e. entries 29, 52, 55, 56, 51, 28, 29), nowhere near entries 12-15. **So `FUN_0040b400`
provably does not touch the hatch's own colours.** It rotates a real, identifiable palette region — just not this one's. What (if anything) on screen actually uses entries 12-15 is not known; it may be some other decoration, a rarely-visible UI element, or
even something with no on-screen effect in an ordinary match. This is a stronger and more honest result than "the exact colours aren't pinned down" (document 80's first pass): the mechanism is fully traced: trigger, cadence, and the precise 7-word rotate and its
real resulting colour sequence; only *what it's for* remains open.

## Step 4: a second bug, in the hangar screen's own pointer — invented, not the original's

While screenshotting the hangar screen (document 78) for this, two small red pointer ticks turned up floating in open dirt, well outside the selected bay. The pointer's *position* data (table `0x4491c0`, re-dumped in full to be sure) was correct and matched
what was already in `tools/extract_selector.py` exactly. The bug was in `game/selector_screen.gd`'s own drawing code: it mirrored the pointer for the two right-hand bays (Tank, Jeep) using a **negative-width destination `Rect2`** passed to
`draw_texture_rect` — a common Godot flipping trick, but one that **doesn't scale correctly through an `AtlasTexture`** in this engine version: the texture draws at its native 1x size instead of the intended 2x, so the flipped copy's bounding box lands
far to the right of where it should. That mirroring was never traced from the code in the first place (document 78 only read "two red ticks", nothing about a flip flag in the table), so it's simply **removed**: the pointer now draws identically for all four
bays.

That fix landed the pointer roughly in the right area, but still visibly low and a touch right of where it belonged. The hangar cel (2075) itself has the answer: its bottom rail is carved with **seven small square recesses**, 5 pixels apart (found by scanning
the raw pixel row: three dark pixels, two lit ones, repeating). The pointer sprite (35 x 2, cels 2091-2093) has its two red ticks exactly 15 pixels apart — three of those 5-pixel recesses — so it's built to seat two of the seven slots at once, lit up. Both the
pointer's `(0.4, 1.0)` nudge and the vehicle picture's `(2, 3)` nudge turned out to be **exactly that: invented nudges**, added without checking against the art, and both wrong. Compositing the real cels in Python at the *raw*, un-nudged table positions —
no adjustment at all — dropped both ticks precisely into two of the seven recesses and sat every vehicle flush on its tray, confirmed against all four bays. Both nudges are now removed; the port draws these at the exact traced coordinates.

## Applied in the port

- **Registry**: cels 90/91 renamed and correctly described (Step 1).
- **Debug overlay default flipped**: `game/terrain_view_3d.gd` now needs `RF_DEBUG_MARKERS=1` to show the spawn/pool markers; they no longer cover real art by default.
- **A visible "dock ready" cue** — since the traced animation demonstrably isn't a hatch effect, there is nothing left to faithfully reproduce here, so this is now documented as a full invention rather than an approximation of something known: `game/dock_ready_indicator_3d.gd`
  draws a border around the home pad, visible exactly when `MatchController.can_dock(vehicle)` is true (the same eligibility test document 77 uses, independent of whether a button is actually pressed — matching `FUN_0040b400`'s own trigger condition), cycling a
  made-up hazard-light palette at the **traced cadence** (`65536/0x2666` ticks a step, ~9.1/s). Neither the ring shape nor its colours are the original's; the file's header says so plainly.
- **A text cue** in the placeholder HUD (`[DOCK READY - press fire]`) for the same condition, since the placeholder HUD already exists as an honest stand-in for the untraced real interface.
- **The hangar pointer's invented mirroring is removed** (Step 4); `_blit`'s `flip` parameter is gone with it, and its and the picture's invented pixel nudges are removed too — both now draw at the raw traced table coordinates, which line up exactly with
  the hangar art's own carved slots and trays.
- Checked by screenshots (the dock-ready ring cycling through four colours while parked, absent while driving away; all four hangar bays' pointers seated in their slots and every vehicle flush on its tray) and the existing test suite (unaffected).

## Not done

What (if anything) on screen actually displays palette entries 12-15, so the real visual effect of `FUN_0040b400` remains unknown; the camera-flag bit set in the function's last few lines; which of the seven rail slots the original actually lights (this port's
alignment happens to land on slots 2 and 5 of 7, since that's where the raw table coordinates put it — nothing traced says those two specifically matter over another matching pair); whether the original mirrors its hangar pointer at all for the right-hand bays;
the Heli's own docking readiness shown identically to the ground vehicles' in this pass (its tolerance is simply larger, 32 units, per document 77) — nothing suggests it should differ, but that isn't confirmed either.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
