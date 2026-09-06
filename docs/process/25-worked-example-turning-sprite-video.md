# 25. Worked example: a user's screen recording, tracked frame-by-frame, finds a real registry bug

Every anchor before [document 24](24-worked-example-capture-the-flag-lead.md) started from
something already sitting in the binary or the asset registry. This one starts from a
**video** — the user recorded the game running and said "this shows the turning display
issue," with no more detail than that. Turning a 16-second screen recording into an actual
root cause needed a small pipeline that didn't exist in this project yet: extracting frames,
finding a tiny sprite inside them automatically, and reading its pixels precisely enough to
tell a real rendering bug apart from a video-compression artifact.

## Building a way to *see* the bug

`ffmpeg` wasn't on this machine (only a codec-stripped build bundled with Playwright, unable
to open an MP4 at all) — installed the real thing via `winget install Gyan.FFmpeg` rather than
guessing from compressed thumbnails. The vehicle sprite is a handful of pixels against a large,
mostly-static terrain background, and the camera drifts (smoothed following, section 3 Phase 4
step 3) enough that it isn't reliably centred — so a fixed crop window wasn't good enough.
Wrote a small colour-threshold tracker (`numpy`+`Pillow`, both freshly installed): find pixels
matching the vehicle's dark reddish-brown, take their centroid, and if a frame's match is too
weak to trust (fewer than 30 pixels — often true mid-turn, see below), keep the previous
frame's position rather than jumping to noise. This produced a stable per-frame crop across
all 247 extracted frames (15 fps) with no manual scrubbing.

## The video showed something real, not a compression artifact

Tiling the cropped, upscaled frames into contact sheets (rather than reading the (`ffmpeg
tile`) filter, brittle) showed exactly what the user meant: for several frames around
`t≈4.1s`, the sprite isn't a thinning silhouette, it's **two or three disconnected fragments**
— a hook shape, then a lone diagonal sliver — before snapping back to a coherent body. The
tracked centroid positions across that stretch moved smoothly (no jump a bad crop could
explain), which ruled out the obvious "my tracker just grabbed the wrong pixels" explanation
before spending any more time on it — document 6's rule about verifying before trusting,
applied to a debugging tool built in this same session rather than to decompiled C.

## Comparing against the source art directly, not the compressed video

The video is H.264-compressed at a small sprite size — not reliable evidence for "is this
shape actually broken" on its own. The real check is the uncompressed source: rendered
`vehicle.hovercraft.rotation.tan.01`-`.08` (cels 218-225, `build/car/art_atlas.png`) directly
at 12x scale. Frames 7 and 8 **are** already sparse, disconnected-looking shapes in the actual
extracted game art — so the video wasn't lying, but it also wasn't yet clear this was a *bug*
rather than just how the original's thin edge-on frames look.

## The real find: counting pixels caught an asymmetry eyeballing had missed

`vehicle.hovercraft.rotation.green` has 9 frames (cels 232-240); `.tan` only had 8 (218-225).
There was no reason for the two teams' rotation sets to differ in length, so this got checked
properly rather than shrugged off: counting non-transparent pixels per cel gives a clean,
monotonically-thinning sequence for tan — 220, 166, 69, 34 — and cel 226, sitting right after
tan's registered range, continues it exactly: **11 non-transparent pixels, same hue, same
silhouette family.** Cels 227-231 were checked the same way and are genuinely, completely
blank (0 pixels) — confirming 226 is the real last frame, not a fluke worth chasing further.
Cel 226 had been classified by the original bulk pass (`tools/registry/classify_bulk.py`) as
`prop.debris_faint.420` — a reasonable-looking guess for an 11-pixel fleck in isolation, wrong
once placed next to its actual neighbours. The same category of mistake as document 24's four
misfiled flag frames and document 21's cyan/green mislabeling: a coarse classification pass
skims past something that only looks wrong once you line it up against what's actually next
to it.

## Why this specific asymmetry produces exactly the video's symptom

`Vehicle._frame_for_heading()` spreads however many frames `Vehicle.setup()` finds into equal
slices of the 0-90 degree quarter-turn, then mirrors that same set into the other three
quadrants. With only 8 tan frames, the last one (225, already a disconnected "hook") was
stretched across the *widest* end of the range and sat immediately at the quadrant boundary —
so as heading crossed 90 degrees, the same broken-looking frame was shown, mirrored, and shown
again, exactly the "falls apart right as it turns" effect visible in the video.

## The fix needed no code change

`Vehicle.setup()` already builds its frame list dynamically:

```gdscript
var prefix := "vehicle.hovercraft.rotation.%s." % team
for id in pack.sprites.keys():
    if id.begins_with(prefix):
        _frames.append(id)
```

So the whole fix is data: reclassify cel 226 as `vehicle.hovercraft.rotation.tan.09`
(`tools/registry/classify_bulk.py`'s established correction-block pattern — append, don't
rewrite the original `seq()` call — plus a direct hand-patch of
`packs/registry/asset_ids.json`, per document 21's known `classify_bulk.py` re-run bug), then
regenerate the pack. `Vehicle` picks up the 9th frame automatically on the next load.

## Verifying the fix with numbers, not another video

Rather than re-recording and re-tracking a second video (slow, and still only as precise as
the compression allows), a small headless script (`SceneTree`-based, this project's usual
pattern for logic-only checks — see [document 22](22-worked-example-weapons-and-targets.md))
called `_frame_for_heading()` directly for every integer heading 0-90 and printed which frame
covers which range:

```
heading [74, 85) -> vehicle.hovercraft.rotation.tan.08
heading [85, 90]  -> vehicle.hovercraft.rotation.tan.09
```

Before the fix this would have read `heading [79, 90] -> tan.08` — the disconnected-looking
frame running all the way to the mirrored seam. After: it's confined to 11 degrees ending
*before* the seam, with the genuinely-sparse frame (`.09`, 11 pixels) taking over for only the
last 5 degrees. A real, measured improvement — not a claim that the glitch is gone, since
`.09` is still a near-invisible sliver whenever it *is* shown.

## What this does and doesn't settle

This fixes one confirmed, real bug: an accidental frame-count asymmetry between the two teams.
It does **not** touch the deeper question section 3 Phase 4 step 2 already flagged as
unconfirmed — whether flat-sprite-quadrant-mirroring is even the right technique at all, given
section 1.10 already found the original does real perspective-projected 3D quad rendering, not
sprite-frame switching. A flat, unwarped 32x32 texture sampled at a near-edge-on angle will
always look thin and sparse; the original likely never shows these source textures un-warped in
the first place. **Next, per the user:** DOSBox-X already has Windows 95 installed and can boot
`RFIRE.BIN` directly — a real side-by-side capture of the original's actual turning behaviour
would replace guessing about `.data`-segment table layouts with a ground-truth reference,
and would settle whether refining the mirror approach further is worthwhile or whether the
projected-quad technique needs implementing for real.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
