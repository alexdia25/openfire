# 92. Worked example: what happens after the flag comes home (the end-of-match sequence and the victory ribbon)

**Question:** documents 57 and 65 traced the flag completely: who can take it (only the Jeep), how it hangs from the carrier, the capture test that ends the match (`FUN_0040d990` calls `FUN_004225d0(player)` when a Jeep carrying the other pool's flag stands on its home art). The port's placeholder for what follows was a line of text, "TAN WINS - flag captured". This document traces what the original does next. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

(A correction to my own earlier note: the "Still open" list said the flag pickup/carry/return and the win test were untraced. They are traced, in documents 57 and 65; what was untraced is this: the sequence *after* the win.)

## Step 1: the win switches the game to a handler

`FUN_004225d0`, decompiled (`DecompileMany.java 0x004225d0 0x00422680`):

```c
void FUN_004225d0(int winner) {
  FUN_00401420();
  PTR_LAB_00449510 = &LAB_004222a0;   // the game's per-tick handler becomes the end-of-match handler
  FUN_0042fdd0(0, 1000);              // fade the screen to level 0 over 1000 ms
  DAT_00449518 = 0;                   // the handler's state
  DAT_00458d14 = winner;
  DAT_00449528 = 1;                   // game over
}
```

The handler at `0x4222a0` is a seven-state machine (a jump table at `0x4225a8`, state in `DAT_00449518`; `DisasmForce.java 0x4222a0 0x4225d0`; Ghidra never made it a function). Its states, read from the disassembly:

| state | what it does |
| --- | --- |
| 0 | sets the window's menu controls (messages `0x3e9`..`0x401` to the control-toggle function `[0x48e714]`, a Windows front-end detail), then `FUN_00430620(winner, [0x442fc0])`, and `FUN_004056a0`; if the winner is not player 0 or 1 it goes to state 6 instead |
| 1 | keeps the fade to black going (`FUN_0042fdd0(0, 1000)`) and waits until the fade level `[0x44e0d8]` reaches 0, then `FUN_00430400` / `FUN_00430870` (load the ribbon bitmap and its palette) |
| 2 | fades back up to full (`FUN_0042fdd0(0x10000, 500)`) |
| 3 | `FUN_00405690` (waits for the announcer queue), `FUN_00405660` (flush it) |
| 4 | `FUN_00431370(winner, 0)`: starts the **ribbon sequence** (below) |
| 5 | `FUN_004312c0` each tick until the sequence is over (`[0x44e0d0]` = 0) |
| 6, 7 | a last fade to black (`0x42fdd0(0, 1000)`), then the handler ends with state -1 and `[0x48cd98] = 1` (back to the front end) |

## Step 2: the ribbon bitmaps and the jingle

`FUN_00430620(winner, level_byte)` picks *what* to show, decompiled:

```c
void FUN_00430620(byte winner, int level_byte) {
  level_byte = clamp(level_byte, 0, 9);
  DAT_00458fe8 = table_0x44e120[level_byte];   // {0,1,1,1,1,2,2,2,3,3}
  if (DAT_00458fe8 > 3) DAT_00458fe8 = 3;
  DAT_004593fc = winner;
}
```

`[0x442fc0]` is a level byte (which field of the level it is is **untraced**); `DAT_00458fe8` is a tier 0-3 and picks a victory jingle from the table at `0x44e110`, whose four strings sit at `0x44e090` (`DumpDwords.java`, decoded to ASCII): `TITLE\Win.stm`, `TITLE\Win3.stm`, `TITLE\Win2.stm`, `TITLE\Win1.stm`. The ribbon is chosen by `FUN_004306b0` / `FUN_00430870` (identical loading code, one also loads the bitmap's palette):

```c
uVar1 = winner + (DAT_00448d5c == 5 || DAT_00448d5c == 1 ? 2 : 0);      // display mode: low or high resolution
name  = PTR_s_TITLE_BanBL_bmp_0044e148[uVar1];    // [0] BanBL  [1] BanGL  [2] BanBH  [3] BanGH  (strings at 0x44e050-0x44e080)
...
x = table_0x44e158[tier * 8]  (-1 = centred: (screen_w - bitmap_w) / 2);   y = table_0x44e15c[tier * 8] = 0xb4 = 180  (doubled in the high-res mode)
```

So the winner picks a **brown (tan) or green ribbon**, drawn centred with its top edge at y = 180. The four files are on the install (`TITLE\BANBL.BMP`, `BANGL.BMP` 180 x 52; `BANBH.BMP`, `BANGH.BMP` 360 x 104): a ribbon with a yellow shield, a flag and two laurels. The jingles `WIN.STM`, `WIN1-3.STM` are on the CD image only (in the ISO's `TITLE` directory: 20.5, 3.0, 6.8 and 6.2 MB); their header is `auds`, an audio stream, not video. **Their format is not decoded.**

## Step 3: the ribbon sequence (`FUN_00431370`)

`FUN_00431370(winner)` (decompiled) sets the step pointer to the table at `0x44e240` and starts it; `FUN_004312c0` calls the current step once per frame with `(entry, frame_number, time)` and moves on when it returns 1. The table has two 5-dword entries: `{0x430b10, 0, 0, 0, 500}` and `{0x431120, ...}`. `FUN_00430b10` (`DisasmForce.java 0x430b10 0x430da0`):

```
00430b1d  JNZ 0x00430cab              ; frame 0 only: load the ribbon (as above), set the fade-in from entry+0xc (0 = at once)
00430c9c  CALL 0x00435010              ; open the jingle stream for the tier (table 0x44e110), FUN_00435ee0 starts it
00430cae  CALL 0x004361c0              ; every frame: pump the stream
00430cb3  CALL 0x004306b0              ; every frame: draw the ribbon (a Blt of the bitmap at x, y)
00430cd7  CALL 0x00436520 ; JNZ hold    ; FUN_00436520 = "the stream is still playing": while it is, keep showing the ribbon
00430ce4  ...                          ; when it has ended: fade out over entry+0x10 = 500 ms, free the bitmap, return 1
```

`FUN_00436520` is `return DAT_0045a4f0 != 0 && DAT_00459a48 != 0`, the stream object's "playing" flag. **In short:** the game fades to black (1 s), the winner's ribbon appears at once on the cleared screen while the jingle plays, the ribbon stays for as long as the jingle lasts and fades out over 0.5 s, then the screen goes black once more and the handler returns to the front end.

## Applied in the port

`tools/extract_win_banners.py` writes the four bitmaps into the pack (`hud/win_banner_{tan,green}_{low,high}.png`; gitignored like everything extracted). `game/win_ribbon.gd` is the sequence, and `PlaceholderHud.show_win` starts it:

```gdscript
const FADE_OUT_S := 1.0        ## FUN_0042fdd0(0, 1000)
const RIBBON_FADE_IN_S := 0.5  ## port choice
const TOP_FRACTION := 180.0 / 240.0
const SCALE_HIGH := 1.5
...
_black.color.a = clampf(_t / FADE_OUT_S, 0.0, 1.0)
_ribbon.modulate.a = clampf((_t - FADE_OUT_S) / RIBBON_FADE_IN_S, 0.0, 1.0)
_ribbon.position = Vector2((vp.x - _ribbon.size.x) * 0.5, vp.y * TOP_FRACTION)
```

The debug autoplay's win screenshot (`RF_DEBUG_AUTOPLAY_SHOT`) shows the game gone to black and the brown ribbon centred low on the screen, the shape and position of the original's.

## Not done / untraced

- **The jingle** (`Win*.stm`, an `auds` stream on the CD image) is not played: the format is not decoded, and the four files are not part of the game folder the pack is built from.
- **What the port does after the ribbon is a placeholder:** it waits for Enter and restarts the level. The original holds the ribbon for the jingle's length, fades out, and returns to the front end (states 6-7 and `[0x48cd98]`); what the front end does next (the next level, a menu) is untraced.
- The high-resolution bitmap at 1.5x (so it matches the low-res one at the port's 3x scale), the 0.5 s fade-in of the ribbon and the plain black behind it (the sequence has no scene draw between the fade and the bitmap; nothing else was seen) are the port's choices, marked in `win_ribbon.gd`.
- What `[0x442fc0]` is (the level byte that picks the jingle tier) and whether `0x44e120`'s tiers correspond to the level's difficulty.
- The loss case (winner not 0 or 1) takes state 6 directly (a fade and out); the port's loss handling is document 88's sequence, whose end is the same handler, not yet compared.
- Correction to [document 15](15-worked-example-resolution-and-tick-rate.md): it called this function family (`FUN_00430b10`, `FUN_00431370`, the table at `0x44e240`) "the boot-time logo slideshow ... not gameplay". The same machinery is also the end-of-match ribbon: the boot tables at `0x44e178` and this one at `0x44e240` share the step functions.

**Next:** [the next-steps doc](NEXT_STEPS.md).
