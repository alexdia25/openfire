# 88. Worked example: the loss sequence and the laughing skull

**Question:** the user remembered "a death screen with a laughing skull" after losing *any* vehicle. Document 87 traced
what a death does to the vehicle and the wreck, and found no sound and no screen in `FUN_0040c460`. `Laugh` was the
last unexplained cue with an obvious owner. Where is the screen, what does it draw, and how long does it run?

## Step 1: `Laugh` has exactly one play site

`FindPointerRefsMulti.java 44b790` (the `Laugh` descriptor) finds one code reference, `0x4188aa`:

```
004188a5  PUSH 0x1 / PUSH 0x0 / PUSH 0x44b790 / PUSH 0x1
004188b0  CALL 0x004232d0            ; the sound queue
```

inside the handler at `0x418830`. That handler is one phase of the *player's mode state machine*: the player struct
(`0x458100 + n * 0x140`, document 47) holds the current phase function at `+0xc0`, and each phase assigns the next
(`param[0x30] = &LAB_...`). The same struct's `+0xbc` is the view's brightness (the port's `view_fade`: 1.0 clear,
0.0 black -- `FUN_00422e00` turns it into a full-view darkening, and `0x4189a0` fades at `0x11eb` a tick, the same
0.07 the port already had for the choice screen's fade).

## Step 2: how the wreck starts it

Document 87 stopped at two tail calls in the wreck's init, `FUN_0040c7e0`:

```c
FUN_004146d0(*(int *)(**(int **)(param_2 + 0x60) + 0x260),   // delay = type record +0x260
             (int)pcVar9, iVar4 << 0x10, iVar5);             // pcVar9 = FUN_0040b5a0 or FUN_0040b5c0
```

`FUN_004146d0` inserts a callback into a delta-ordered queue. Its delay is the type record's `+0x260`:
**Tank, Jeep and MSV 120 ticks (0x78), the Heli 200 (0xc8)**. Both callbacks end in `FUN_00418440(player)`; the
`b5c0` variant (also called by the drowning handler `FUN_0040cf90`) first checks the stock and may send the player
straight to `0x418390` (the game-over handler) instead. That also settles something document 87 could not: the wreck
*does* lie there for two to three seconds first, and the Heli's longer delay fits its longer fall.

## Step 3: the phases

`FUN_00418440` (init) sets `+0xc8 = now + 30` and `+0xd4 = 0x28f`, and each phase below runs every tick:

| Phase | Function | What it does |
| --- | --- | --- |
| 1 | delay | the wreck lies (120 / 200 ticks, above) |
| 2 | `0x4184d0` | the skull spins in over the live view until 30 ticks have passed |
| 3 | `0x418830` | `+0xbc -= 1310` a tick (50 ticks to black, mirrored to `+0xe0`); at 0: **`Laugh`** |
| 4 | `0x4188c0` | `+0xd8 += 0x4ccc` (0.3) a tick, the mouth-table index; past `0x3bffff` (201 ticks) ask `FUN_0040b260` (any vehicle left?): none = `FUN_0040b370(-1)`, the match-end banner of document 57's machinery, at once |
| 5 | `0x4189a0` | the skull fades out at `0x11eb` a tick (~15), then `FUN_00418290` installs `FUN_00417ad0`, the vehicle choice (document 76) |

`0x418a50` / `0x418af0` / `0x418b50` are the two-player variants (they redraw the four vehicle-type icons); not traced.

## Step 4: the skull itself, `FUN_00418510`

Every phase calls this to draw. Reading it:

```c
if (scale < 0x13333) { scale += delta * 0x666; if (scale > 0x13333) scale = 0x13333; }   // 0x28f -> 1.2
if (scale != 0x13333 || angle != 0) {
    angle += delta * 0x28000;                        // 0x400000 = a turn: 14.06 degrees a tick
    angle = (angle < 0x400000 || scale < 0x13333) ? angle & 0x3fffff : 0;   // ends upright
}
cel = 0x84d + table_0x449270[timer >> 16] + (player_index == 0 ? 7 : 0);      // 2125 + f (+7)
quad = corners at 0x4492b0 (-32..31, a 64 x 64 square) turned by the angle's 64-step matrix, scaled, at the view
       position (+0x10, +0x14); FUN_00422f70 sets the transparency (the fade-out's level, else opaque)
```

The mouth table (`0x449270`, 64 bytes, index = whole part of the timer) is
`1 2 2 3 3 4 4 5 6 6 6 5 5 5 6 6 5 4 5 6 7 7 6 5 4 5 6 7 7 6 4 5 6 7 6 5 3 4 5 7 7 7 6 6 6 5 5 4 4 3 3 2 2 1 1 1 1 1 1 1 0 0 0 0`:
frame 1 closed, 7 widest. The cels are the ones the registry had called `character.trooper_portrait.NN`
("helmeted face portrait, repeated with minor variation" -- a visual guess): **2126-2132 are the tan-helmet skull,
2133-2139 the green-helmet skull**, both with a jaw that drops. Renamed `ui.death_skull.{tan,green}.f1..f7`
(registry hand-edited plus a `put()` block in `classify_batch2.py`, pack rebuilt). Cel 2125 (a 7 x 7 red cross, was
`ui.icon.checker_yellow.01`) is the cross the icon rows draw; as `f = 0` of player 1's set it is never reached.
The `+7` gives player 0 the *green* skull and player 1 the tan one: the skull is the **other** team's, laughing at you.

## Applied in the port

`MatchController._on_player_destroyed` used to respawn at once. It now starts `death_phase = 1`; `_update_death` runs
whole ticks and `_death_tick` follows the table above, with the skull's raw state (`skull_scale_raw`, `skull_angle_raw`,
`skull_timer_raw`) advanced by `_skull_step` exactly as `FUN_00418510`:

```gdscript
func _skull_step() -> void:
    if skull_scale_raw < SKULL_SCALE_MAX_RAW:
        skull_scale_raw = mini(skull_scale_raw + SKULL_SCALE_STEP_RAW, SKULL_SCALE_MAX_RAW)
    if skull_scale_raw != SKULL_SCALE_MAX_RAW or skull_angle_raw != 0:
        var a := skull_angle_raw + SKULL_SPIN_RAW
        if a < 0x400000 or skull_scale_raw < SKULL_SCALE_MAX_RAW:
            skull_angle_raw = a & 0x3fffff
        else:
            skull_angle_raw = 0
```

Phase 3 lowers `view_fade` (the HUD's existing black overlay draws it) and emits `Laugh` when it reaches 0; phase 4
ends the match when no stock is left (else phase 5, then the old placeholder replacement, `_finish_player_death`).
`game/death_skull_view.gd` (added to `PlaceholderHud` above the fade) draws the frame with the traced angle (64 steps),
scale and alpha. `tools/tests/death_sequence_check.gd` confirms the timing (Tank: skull at tick 120, dark at 202,
laughing 202-403, respawn at 418; Heli: +80), the single `Laugh`, and the upright 1.2-scale end state;
`stock_check.gd` now runs the sequence between deaths; screenshots (`RF_DEBUG_KILL=<frame>`,
`RF_DEBUG_SCREENSHOT_WAIT_DEATH=<phase>`) show the skull spinning in and laughing on black.
`Laugh` is now wired: 35 of 42 cues.

## Still open

- **Untraced port choices:** the skull's screen position (the player's `+0x10/+0x14`; centred here), its rotation
  direction (clockwise here), the brightness starting at 1.0 when the sequence begins, and the delta queue's unit
  (taken as ticks).
- The two-player phases and the remaining-vehicle icon rows (`FUN_00418b50`, table `0x449308`); the `b5c0` gating
  (`state+0x3a`, the flag at wreck `+0xf`); the drowning path is routed through the same sequence without checking.
- After the skull the original opens the vehicle *choice* (`FUN_00417ad0`); the port still respawns by placeholder.
- The registry's other "trooper portrait"-style visual-group guesses deserve the same suspicion.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
