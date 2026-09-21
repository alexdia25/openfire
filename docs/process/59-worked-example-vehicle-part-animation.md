# 59. Worked example: how the original animates its vehicles

**Question:** the port draws the MSV and Jeep as still pictures. How does the original make their parts move
(wheels, canisters, rotor)? **Answer in one line:** every animation is done by a small *draw callback* per vehicle
type that edits the part list just before drawing. This document shows how we found and read those callbacks; keep
the [tracing cheat sheet](TRACING_CHEATSHEET.md) open for the field names and the scripts.

## Step 1: find where animation could live

[Document 39](39-worked-example-real-turret-and-barrel.md) had already decoded a vehicle's *descriptor*: a table of
parts (a part = one textured quad: cel, flags, four corner indices). The generic drawer `FUN_0041b2b0` does only
this for each part: `cel + (team variant if flag 8)`, then draw it. There is nothing about time in it, so **any
animation must change the descriptor's data before the drawer runs**.

The descriptor's first dword is a function pointer. Dumping the four vehicle descriptors:

```bash
... -postScript DumpDwords.java 0x43ea18 16     # Tank   ->  00402dc0 first
... -postScript DumpDwords.java 0x43fd78 16     # Jeep   ->  00402fc0
... -postScript DumpDwords.java 0x43f358 16     # MSV    ->  00402ec0
... -postScript DumpDwords.java 0x440b70 16     # Heli   ->  00403550
```

Those four are the **draw callbacks**. Each descriptor also has an **init callback** at `+0x24` (`0x402d20` for
Tank/Jeep/MSV, `0x4034c0` for the Heli). Everything below is read from these six functions.

## Step 2: the Jeep's wheel strip (callback `0x402fc0`)

The audit in [document 46](46-worked-example-registry-audit.md) had found five look-alike Jeep cels 457-461 and
guessed "wheel animation". To test that, we looked for code that writes the cel of the two parts that use cel 457
(parts 9 and 10). The parts array starts at `0x43f9f8` and each part is `0x20` bytes, so part 10's cel word is at
`0x43f9f8 + 10*0x20 = 0x43fb38` and part 9's at `0x43fb18`:

```bash
... -postScript FindPointerRefsMulti.java 43fb38 43fb18
```

Both are referenced by the instructions at `0x402fe5` and `0x402fea`. Reading them (`DumpDisasm.java 0x00402f40 ...`):

```
00402fd4  MOV EAX,dword ptr [ECX + 0x40]     ; EAX = field 0x40 of the vehicle object
00402fd7  AND EAX,0x30000                     ; keep bits 16-17
00402fdc  SHR EAX,0x10                        ; -> 0..3
00402fdf  ADD EAX,0x1c9                       ; + 457
00402fe4  MOV [0x0043fb38],EAX                ; part 10's cel
00402fe9  MOV [0x0043fb18],EAX                ; part 9's cel
```

So the cel is `457 + (field 0x40 mod 4, in whole units)`. What is field `+0x40`? The vehicle-destroyed code at
`0x40bba0`-`0x40bbad` pushes `[ESI+0x40]`, `[ESI+0x44]`, `[ESI+0x48]` as the arguments of "spawn a wreck object":
that is x, y, z. **So the frame is the vehicle's integer world x modulo 4**: the strip steps once per unit driven
along x, and does not change when driving along y (an oddity of the original that we keep). Frames 457-460 are
used; 461 never.

## Step 3: the MSV's canisters (callback `0x402ec0`)

Disassembly (abridged):

```
00402ed8  MOV EAX,dword ptr [EAX + 0x60]     ; the player's state block
00402edb  MOV EDI,dword ptr [EAX + 0x50]     ; gun elevation
00402ede  MOV EAX,dword ptr [EAX + 0x58]     ; weapon counter n
00402ee3  JGE 0x00402eef                     ; n >= 0: keep it
00402ee5  SUB EDX,EAX                        ; n < 0: EDX = -6.0 - n, then n = 0
00402eef  MOV ECX,0x146                      ; 326
00402ef4  MOV [0x0043ed70],EDX               ; a corner y (base table)
00402efa  SUB ECX,EAX                        ; 326 - n
00402f07  MOV [0x0043f2c0],ECX               ; the cel of part 13
```

`0x43f2c0` is part 13's cel (`0x43f120 + 13*0x20`), the canister part. Where does state `+0x58` change? Searching for
writers (`FindDispOps.java 0x40b000 0x410800 "+ 0x58],"`) finds the fire code at `0x40d6e4`-`0x40d702` and the
per-tick function `0x40d790`:

```
0040d6e4  MOV EAX,[ESI + 0x58] ; INC EAX ; MOV [ESI + 0x58],EAX   ; each rocket: n += 1
0040d6eb  CMP EAX,0x3 ; JL ...                                     ; third rocket: fall through to
0040d702  MOV [ESI + 0x58],0xfffa0000                              ; n = -6.0 (reload)
0040d7be  LEA EAX,[EAX + EDI*0x2] ; MOV [ESI + 0x58],EAX           ; each tick n rises (0.15 per tick)
```

So during the salvo `n` is 0, 1, 2 and the cel is 326, 325, 324 (the registry's canisters_3, _2, _1: the audit's
"1/2/3 blue canisters"). After the third rocket `n` runs from -6.0 up to 0 in 40 ticks and two corners (`0x43ed64`
and `0x43ed70`, the y of corners 48 and 49 of the rack) slide from y = 11.25 to 5.25. That is the base value -4.5
replaced by `-6.0 - n`, plus the fixed offset 11.25; at rest y = 5.25, not the descriptor's static 6.75.

## Step 4: the Tank and the two init callbacks

The Tank callback `0x402dc0` (decompiled in documents 39 and 40) only turns the turret by state `+0x58` and pitches
the barrel by `+0x50`. It touches no track part; the track cels 182/183 are the tan and green variants of one image
(descriptor flag 8), so **the Tank's tracks are not animated by its own drawing code.**

The init callbacks were never disassembled by Ghidra (they are only pointed to from data), so we wrote
`tools/ghidra_scripts/DisasmForce.java` and ran `DisasmForce.java 0x402d20 0x402dc0`:

```
00402d28  MOV ECX,[ESP+0x10]         ; the vehicle object
00402d2f  MOV [ECX+0x64],EAX          ; EAX = the clock: "last drawn at"
00402d32  CMP [class],0x6 ; JZ        ; class 6: plain team variant
00402d3a  MOV EDX,[0x480d38]          ; the clock
00402d40  CMP [state + 0x4c],EDX ; JC ; state+0x4c is the "hit until" time (document 47)
00402d48  MOV [draw+8],0x2             ; still hit: variant 2   <-- third colour
00402d51  MOV EAX,[ECX+0x10] ; MOV [draw+8],EAX   ; otherwise the team index (0 tan, 1 green)
00402d68  MOV [draw+0x1c],[obj+0x4c]  ; heading
```

This is the **hit flash**: for 10 ticks after a hit (document 47: `state+0x4c = now + 10`) the vehicle is drawn with
variant 2 instead of its team variant. The registry's "yellow" cels (`vehicle.jeep.p422.yellow`) are these.
The Heli's init (`0x4034c0`) does the same and also copies object `+0x70` and state `+0x88` (rotor angles, both
22-bit) into the draw object at `+0x20` and `+0x30`. The Heli callback `0x403550` shifts a list of corners by
`(1 - state +0x58) * 18` units while `+0x58 < 1.0` (landing gear or similar). Not applied: the Heli does not fly yet.

## What the port does now

- `game/vehicle_render_3d.gd` keeps each part's mesh and rebuilds only the animated ones when their state changes:
  the Jeep's wheel frame from its x position; the MSV's canister cel and sliding corners from
  `Vehicle.salvo_index()` and `salvo_reload_remaining()`.
- Check: screenshots with `RF_VEHICLE=msv RF_DEBUG_FIRE=1` and `RF_DEBUG_SCREENSHOT_DELAY_FRAMES` = 5, 70, 140, 200
  show three canisters, fewer mid-salvo, the rack sliding on reload, and three again. The Jeep's strip is thin and
  its change is hard to see in stills; the rule is the traced one.

## Not done, and why

| Item | Reason |
|---|---|
| Hit flash (variant 2) | Traced here; needs a third sprite id per part and the hit time on `Vehicle` (next) |
| Tank turret aim and barrel pitch | Independent aim was deferred by you |
| Jeep water look (immersion table `0x43fb78`, descriptor `0x43fcb8`) | No water mode yet |
| MSV rack elevation (corners 44-51 rotate by state `+0x50`) | Needs the raised-gun state |
| Heli gear and rotor | The Heli cannot fly yet |

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
