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

**Not fully resolved:** exactly which bytes the rotate touches. Cel 90/91 are ordinary (`PRE0 == 0`) cels, so their on-disk `PLUTPtr` is the shared palette's file offset (`0x282CC`, document 20); reading that region as 4-byte RGBQUAD entries and reading it as
individually-addressable 16-bit RGB555 words (as this code does, and as document 74's HUD bars separately do for their own small colour tables) don't obviously agree, so the **runtime** layout of whatever `PLUTPtr` resolves to for these cels at load time is not
pinned down. What is certain from the disassembly alone: seven colour slots, rotated one place every ~6.83 ticks, only while parked in dock position. The exact seven colours are not reproduced.

## Applied in the port

- **Registry**: cels 90/91 renamed and correctly described (above).
- **Debug overlay default flipped**: `game/terrain_view_3d.gd` now needs `RF_DEBUG_MARKERS=1` to show the spawn/pool markers; they no longer cover real art by default.
- **A visible "dock ready" cue**, since the exact original animation's colours aren't known: `game/dock_ready_indicator_3d.gd` draws a border around the home pad, visible exactly when `MatchController.can_dock(vehicle)` is true (the same eligibility test
  document 77 already uses, independent of whether a button is actually pressed — matching the original's own condition for calling `FUN_0040b400`), stepping through a small colour sequence at the **traced rate** (`65536/0x2666` ticks a step). The colours
  themselves (yellow, orange, red, white, near-black) are this port's own guess at "hazard lights," not the original's pixels — marked as such in the file's header and in the untraced-choices list.
- **A text cue** in the placeholder HUD (`[DOCK READY - press fire]`) for the same condition, since the placeholder HUD already exists as an honest stand-in for the untraced real interface.
- Checked by screenshots (the ring present and cycling colour at four different frames while parked, absent while driving away) and the existing test suite (unaffected: `can_dock` was already there, only new callers were added).

## Not done

The exact colours and byte layout of the real animation; the camera-flag bit set in the function's last few lines; the Heli's own docking readiness look identical to the ground vehicles' in this pass (its tolerance is simply larger, 32 units, per document 77) —
nothing suggests the Heli's indicator differs, but that isn't confirmed either.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
