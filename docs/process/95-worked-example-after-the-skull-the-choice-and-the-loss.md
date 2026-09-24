# 95. Worked example: after the skull: the vehicle choice, and what losing the last vehicle does

**Question:** documents 73 and 88 traced the vehicle stock and the loss sequence (wreck, skull, darkening, laugh). Two ends were left as port placeholders: after the skull the port respawned a vehicle at once ("the replacement is the same type when the stock allows"), and with no vehicle left it showed an invented banner. What does the original do? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md). (The "life system" of the old backlog is the stock of document 73: the level's T, J, A, H counts, one spent per vehicle created, one returned per dock, and the level is lost when the player has no Jeep left, step 2. There is no separate lives counter: no string and no field for one was found.)

## Step 1: what the skull hands over to

Phase 5 of document 88 ends by installing `FUN_00418290`. Disassembled (`DisasmForce.java 0x418290 0x418390`):

```
0041829d  MOV [ESI+0xcc],0xff                 ; the cursor: none yet
004182a7  MOV ECX,[ESI+0x68]                  ; the player's base pointer
004182aa  CMP byte ptr [EAX+ECX+0xb8],DL      ; stock byte of type EAX == 0 ?
004182b1  JNZ  found                           ; the first type with stock left ...
004182b3  INC EAX ; CMP EAX,4 ; JL loop
004182bb  found: MOV [ESI+0xcc],EAX            ; ... is the cursor (0 if there is none)
004182d7  MOV [ESI+0xc0],0x417ad0             ; the mode handler becomes the vehicle CHOICE (document 76)
004182e1  MOV [ESI+0xd0],0x6e0000 ; ... zero the fade (+0xbc), timer (+0xc8), ...
```

So after a death the game opens **the same choice grid as after a dock** (`FUN_00417ad0`, documents 76 and 78), the cursor on the first type with stock, on the black screen the darkening left. The dead vehicle's stock was spent when it was created (`stock--` in the creation code, document 73), so nothing is taken here; the choice spends the chosen one. The sister handler `0x418390` (which document 73 called "the lost condition" and document 88 "the game-over handler") is the same thing without the skull: it fades the view out (`+0xbc -= const` a tick) and calls `FUN_00418290` when the fade reaches 0. That is what `FUN_0040b5c0` (the drowning handler's callback, document 88) may install when the player is out of stock; it is a fade to the choice, not a game over.

## Step 2: what losing the last vehicle does

In phase 4 (document 88) the skull code asks `FUN_0040b260(player)` (its only caller, `0x4188ea`) whether the player has anything left. Decompiled (`DecompileMany.java 0x0040b260 0x0040b400`), and **it counts Jeeps, not vehicles**:

```c
uVar2 = (param_1 != 0);                                  // the player index
uVar4 = (byte)(&DAT_0048c939)[uVar2 * 0xd0];             // 0x48c880 + 0xb9 = the JEEP stock byte (type order Tank, Jeep, MSV, Heli; document 73)
iVar1 = (&DAT_0048c7b8)[uVar2];                          // the player's current vehicle object
if (iVar1 != 0 && serial matches && class == 1 (vehicle) && record.type == 1 (Jeep)) uVar4++;   // a live Jeep under the player counts too (the dead vehicle is taken as not counting: its object is gone when the check runs; inferred, not read)
if (uVar4 != 0) return 3;                                // a Jeep left: carry on
if (DAT_00442fbc < 2) return 0;                          // one player: no Jeep = lost
... (two players: the other player's four stock bytes: return 1 or 2)
```

and the caller (`DisasmForce.java 0x4188c0 0x4189a0`): `0` -> `FUN_0040b370(-1)`, `1` -> the two-player handler `0x418a50`, anything else -> phase 5 (the skull fades and the choice opens). The reason is the flag rule of document 57: only a Jeep can carry the flag home, so a player with no Jeep can no longer win, whatever else is left. **The one-player loss condition is "no Jeep in stock and none alive", not "all four stock bytes zero" (document 73 read the other sites, `0x40b330` / `0x40b694`, and the port used its rule).** With 0 the skull code calls `FUN_0040b370(-1)`, which is `FUN_004225d0(-1)`: the same end-of-match switch as the win of [document 92](92-worked-example-what-happens-after-the-flag-comes-home.md), with the winner **-1**. Document 92's state machine treats a winner that is not player 0 or 1 by going straight to state 6: two fades to black (`FUN_0042fdd0(0, 1000)`) and out to the front end. So **there is no "you lost" message, banner or bitmap: the screen goes black and the level is left.**

## Applied in the port

`MatchController._finish_player_death` opens the choice instead of the placeholder respawn, on the black screen, with the vehicle held under the pad like a docked one:

```gdscript
func _finish_player_death() -> void:
	var t := _tile_of(_player_spawn_px)
	_pad_centre = (Vector2(t) + Vector2(0.5, 0.5)) * pack.tile_size_px
	vehicle.respawn(_pad_centre)
	vehicle.z = DOCK_MIN_DEPTH   # held under the pad like a docked vehicle until the choice is confirmed
	vehicle.docked = true
	view_fade = 0.0
	_open_selection()            # the cursor on the first type with stock (FUN_00418290); confirm_selection spends the chosen one
```

The confirm runs the undock script and the pad rise of document 89 exactly as after a dock. `PlaceholderHud.show_lost` no longer shows a message: only the restart hint (the original returns to the front end, which the port has not). The loss test is the traced one: `_jeep_left()` (`vehicle_stock[1] != 0`) replaces the port's "any stock left". `tools/tests/stock_check.gd` confirms the cursor's type after every death: from the level's stock (Tank 2, Jeep 8, MSV 3, Heli 3 after the first Tank) two Tanks then eight Jeeps are used, and **the 11th death loses the level with 3 MSVs and 3 Helis still in stock** (it used to take 17); `death_sequence_check.gd` sees the choice open at the end (timing unchanged: Tank 418 ticks, Heli 498). A screenshot after `RF_DEBUG_KILL` shows the hangar grid on black with the Tank count at 2.

## Not done / untraced

- **The wreck** is the vehicle body reused, so it vanishes when the choice opens (under black); the original leaves a separate wreck object on the map (document 87).
- **The `0x418390` path** (the skull skipped): what makes `FUN_0040b5c0` choose it (`state+0x3a`, the flag at wreck `+0xf`) is not traced; the port always plays the skull.
- **Two-player:** the other player's stock check in `FUN_0040b260` and the two-player phases of document 88 (`0x418a50`...) are not modelled.
- **The front end** the loss and the win return to is untraced; the port restarts the level on Enter.

**Next:** [the next-steps doc](NEXT_STEPS.md).
