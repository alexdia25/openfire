# 49. Worked example: the explosion frames are animation clips

Document 48 ended with the explosion cels (1084 upward) owned by no draw descriptor, and the tables at
`0x44aa80` turned out to be render-mode tables (blend/shadow modes passed to the part drawer), not
frames. The frames are referenced from a second part layout inside ordinary descriptors.

> **Correction (document 51):** the flags bytes below were misread here. Byte 0 is the *start* progress, byte 1
> the *end* progress, byte 2 the *fade-start* progress, and byte 3 a variant selector; `frames` and `timing`
> in `tools/data/effect_animations.json` are now `end` and `fade`. The clip boundaries and the renaming
> stand (they came from the cels themselves).

## The animated part layout

Some descriptors (for example the one at `0x443e00`: corner count `0x0c`, corners `0x443cf0`, 3 parts at
`0x443d80`) use parts of **6 dwords** instead of 8: `[cel, flags, corner idx x 4]`, where `flags` packs
three bytes: byte 0 the draw mode (1, 5, 9, 13, 14, 18...), **byte 1 the frame count**, byte 2 a timing
value. The cel is the first frame; frames are the consecutive cels after it. The descriptor above is a
composite of three clips at once (a 25-frame smoke column from cel 1084, an 18-frame fireball from 1109,
a 24-frame smoke puff from 1123), each drawn on its own corner quad.

`tools/ghidra_scripts/ScanAnimParts.java` finds every such part in the data segment (byte-1 frame count
2-64, four consecutive corner indices): 68 parts using 33 distinct start cels. Rendering the cels between
consecutive start cels as strips (`tools/data/effect_animations.json`) shows clean, continuous
animations with no gaps or overlaps: fireballs with smoke tails (1084, 1109, 1172, 1210, 1380-1504),
flame bursts and columns (1139, 1251, 1291), thin smoke (1123, 1159, 1275, 1523-1529), shockwave rings
(1197), cyan water rings and splashes (1537-1580), and tan sand explosions and puffs (1580-1714).
The same clip is used with different frame counts and timings by different objects (1210: 25 and 18
frames; 1484: 19 and 20), so frame count belongs to the use, not to the clip.

## Registry

Cels 1084-1739 (626 non-blank) were `effect.burst_red/brown/green.NNN`, a per-colour numbering that cut
straight across clips. They are now `effect.anim.<look>.<frame>` (for example `effect.anim.explosion_large.00`,
`effect.anim.water_splash.03`); the first frame of each clip is `code_verified`, the rest `visual`. Blank
cels stay `reserved.blank`. Hand-edited with a `put()` block in `classify_batch2.py`; the pack rebuilt.
Cels 1745-1776 continue the `effect.burst_red` run and are not referenced by any part found (still
unresolved), as is the second sequence inside the 1210 and 1291 strips (a fire loop from about 1308 and a
second fireball from about 1222): the scan only lists starts that some part uses.

## Not done

Which object plays which clip (the descriptors at `0x443b50-0x445020` are effect objects reached from
tile records and projectile impacts); the timing byte's unit; playing any of these in the port (the tile
destruction and vehicle death have no explosion animation yet). `look` names are visual, not from the
binary.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
