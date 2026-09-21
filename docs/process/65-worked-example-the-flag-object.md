# 65. Worked example: the flag itself: how it is drawn, how it waves, how it hangs from a Jeep

**Question:** document 57 traced who can pick the flag up and how a match is won, and left the flag's own behaviour open: its art, its
animation, how it attaches and moves with the carrier, and what happens to it in water. The port drew a flat placeholder decal.
Field names and scripts are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the object and its two descriptors

The class table `0x44e3c0` (`DumpDwords.java 0x44e3c0 24`) gives: class 12, init `0x4328c0`, destroy `0x4328f0`, update `0x432920`,
draw descriptor `0x440448`, priority `0xc9` (201), object-collision callback `0x432d00`. A second descriptor, `0x440318`, is swapped in while
the flag is carried (`obj+0x3c`, set by the update). Dumping both (descriptor, corners and parts):

| | ground `0x440448` (draw `0x403300`) | carried `0x440318` (draw `0x4032a0`) |
| --- | --- | --- |
| part 0 | cel `0x759` = 1881, corners 4-7: the base plate, 6.5 x 4 at z 0 | cel `0x73f` = 1855 (+ variant), corners 4-7: the cloth from above, 4.5 wide, 11.25 long, z 10.5 |
| part 1 | cel `0x725` = 1829 (+ variant), corners 0-3: the cloth with its pole, x -3..17, z 16 at the top to 0, leaning 4 units | cel `0x70b` = 1803 (+ variant), corners 0-3: the cloth from the side, y 0..11.25 behind the pole, z 4.5..12.5 |

Both draw callbacks (disassembled with `DisasmForce.java 0x403300 0x403350` and `0x4032a0 0x403300`) compute the variant the same way:
`variant = whole(obj+0x5c) + (obj+0x10 != 0 ? 13 : 0)`, so **each set is 13 wave frames per team**: 1803-1815 tan and 1816-1828 green, 1829-1841 and
1842-1854, 1855-1867 and 1868-1880. A contact sheet of the cels agrees (frame 0 is the folded rest frame, 1-9 wave, 10-12 settle). The registry had them
as terrain patches, dirt trails and a "gem" (mislabelled); they are now `marker.flag.*` (hand-edited with a matching `classify_batch2.py` block).
The ground callback also sets a camera-dependent tilt of the cloth (`(cam+0x24 + 0xffe70000) >> 3`, read from the camera record): **that tilt is not
reproduced** (listed under untraced choices); the carried callback sets no tilt.

## Step 2: the update `FUN_00432920` (decompiled)

- **The frame counter `obj+0x5c`** grows by `0x2aaa` a tick (1/6 of a frame). With the "wave" flag set (**a dropped flag always; a carried one only while its
  carrier's speed is above 0**) it counts up to 10 and then wraps by multiples of 6 to stay in [4, 10): frames 0-3 once, then a loop of frames 4-9 (36 ticks).
  Without the wave flag a running counter continues to 13 and resets to 0: the flag settles through frames 10-12 and rests at frame 0.
- **The heading `obj+0x4c`** starts at `0x100000` (90 degrees) and eases toward `obj+0x6c` by `0x4ccc` a tick (1.69 degrees) the short way round. On the ground the target is 0.
  Carried, it is the carrier's heading clamped to `[0x471c7, 0x3b8e39]` (25 to 335 degrees) and then kept out of 155-205 degrees (below 180 it is at most `0x1b8e38`,
  above at least `0x2471c7`): the flag never points straight up or down the screen.
- **Attachment:** the flag is a child of its carrier (`FUN_0042cc50` links it in the carrier's child list, `flag+0x2c` = carrier). Each tick the update moves the flag
  (`FUN_0042c830`) to the carrier's position plus the triple `0x440260` = **(3.75, 6.75, -2)** turned by the carrier's heading matrix, so it hangs behind and beside the
  Jeep with no lag; the flag's height is the carrier's minus 2.
- **Dropped** (`+0x2c == 0`): on land (`FUN_0042f280` = 0) it falls to z 0 and stops; **in water it drifts toward its last safe position**: its speed follows `0x1999`
  (0.1 units a tick) by `0x36` a tick, in the direction `FUN_00422e70(pos, last_safe)` (the heading from a point toward another, rounded down to 64 steps like the
  Jeep missile's). The last safe position (`DAT_00459a20 + team * 12`) is written whenever the flag stands on a "land" tile (`FUN_0042f730` = 0: terrain art 0 or 3, or above
  `0x33`), while carried as well as dropped, and at spawn.
- **Detach on death:** see document 57 (`FUN_0042c0f0` detaches all children when the carrier is destroyed).
- **The interface bits.** The update sets `_DAT_0048c77c |= 0x200` when a flag is carried by a vehicle of the other team, and the spawn function (`FUN_00432710`) sets `|= 0x100`; those
  are interface state (a flag exists / a flag is being carried). The spawn also attaches a "child" with `FUN_00413100(flag, 0x4404b0, 10000)`: **that is a radar blip**, not
  part of the flag's own drawing (`FUN_00413100` writes marker pixels into the radar bitmap from a list of (dx, dy) byte pairs), and the update swaps its descriptor between
  `0x4404b0` and `0x4404c0` every 15 ticks: the blinking flag marker on the radar. Document 57's "flutter child sprite" was that blip. It belongs with the interface (document 66).

## Applied in the port

`FlagMarker` implements the counter, the heading and the water drift (`advance_frames`, `advance_heading`, the controller's `_update_flags`); `FlagMarker3D` draws the two
descriptors from `tools/data/flag.json` (extract_flag.py) with the frame sprites in `markers/flag.json`, turned by the flag's heading. Checked by a scripted run (a waving flag shows
frames 0-3 then loops 4-9; a stopped one runs on to 13 and rests at 0; the green frame is +13; the heading targets for eight carrier headings; a flag dropped in deep water drifts back to its last
safe spot) and by screenshots (a flag on the ground with its base and green cloth; a Jeep carrying it, the cloth trailing behind). The level playthrough still passes.

## Not done

The camera tilt of the ground cloth; the object spawned next to the flag when the other team has a vehicle within 320 units (`FUN_004161e0`, unidentified); the radar blip (interface);
the sounds (grab, drop); the flag's collision shape moving with its heading (the box of document 57 is used unrotated).

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
