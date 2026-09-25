# 98. Worked example: the music: where it is, how the original chooses it, and the "announcer" that was never one

**Question:** the port has no music, and documents 14 and 71 left two open ends: `SOUND\Score.WAV`, the file the game opens for music, is a 20-byte stub on the install, and the "announcer" of document 71 (18 "voice lines" chosen by a state machine) had no audio file anywhere. Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the audio is on the CD image, and the two mysteries are one

The CD image (`RFIRE US.iso`) contains the real **`SCORE.WAV`: 222,709,512 bytes, 44.1 kHz stereo 16-bit, 21 minutes** (its ISO9660 record: LBA 9904). The offset table that `FUN_00403ef0` indexes is 26 dwords at `0x449470` (`DumpDwords.java 0x449470 40`): byte offsets into the sample data, the start of "track n" at dword n (`0`, `0`, `0xdd6004`, `0x3316008`, ..., `0xd44094c`; the last is within 16 KB of the file's end). Cut there, the file is 24 tracks of 0.7 s to 221 s (`tools/extract_music.py`; the energy of the audio drops to silence at the boundaries of the short ones, as track ends do).

The 18 "voice lines" of document 71's table at `0x4463b8` (0x2c bytes each) are **music lines**: their names are "Tank 1", "Tank Death", "Flag Discovery", "Bunker", "Win"..., because each names a *piece of music* chosen by the game's situation. Their fields, decoded (`DumpDwords.java 0x4463b8 210`, `DisasmForce.java 0x40efe0`):

| offset | meaning |
| --- | --- |
| `+0` .. `+3` | line id, `lowest`, `highest` (a window used when two requests tie), `enabled` (bit 0: plays even with the music option off) |
| `+4` | name pointer |
| `+9` | default transition type 0-3; `+0x10` a list of `(previous line, type)` pairs that override it |
| `+0x14` | flags: **bit 1 = a sting** (plays once); otherwise the line loops |
| `+0x18`, `+0x1c`, `+0x20` | **start track, alternate track, end track** (negated CD track numbers; `FUN_004051c0` looks them up as `table[n]`) |

The line plays tracks `start` up to but not including `end` (the file range `table[start]` .. `table[end]`); when it ends a looping line starts again at `alt` (`FUN_0040f600` sets `DAT_004462f8 = 1`, which selects the alternate start). Examples: **Tank 1** tracks 8-11 (7 min), then repeats 10-11; Tank 2 starts at 9, repeats from 8; Jeep 1 track 13 (81 s) forever; MSV 1 track 5; **Heli 1** tracks 1-3, repeating from 2; the deaths are single short tracks (Tank 11, Jeep and generic Death 22, MSV 6, Heli 3); Flag Discovery track 15 (11 s), Flag Pickup 17 (194 s, loops), **Bunker** track 20 (29 s, loops), Sub track 24. Line 17, "Drums", reads a second offset table (`0`, `0x13e004`, ...) and is the `SOUND\DRUMS.WAV` that has sat in the SOUND folder unexplained since document 14; the only request for it is in the front-end handler `0x422160` (`0x422229`, priority `0x32`); that this line's file is `DRUMS.WAV` is inferred from the second table's size, not read.

## Step 2: which line plays: the request queue, `FUN_0040f1c0`

Decompiled (`DecompileMany.java 0x0040f1c0 0x0040f600`):

```c
FUN_0040f1c0(int line, int priority, int source) {
  entry = line >= 0 ? &DAT_004463b8 + line * 0x2c : NULL;
  if (entry && option_off && !(entry[3] & 1)) entry = NULL;          // the music option mutes the lines without the enabled bit
  if (entry == DAT_0048c740) return 0;                               // already the requested line
  if (priority < DAT_0048c780) return -1;                            // refused: a lower priority than the current one
  if (DAT_0048c780 == priority) {                                    // a tie: the new line's window must contain its own id
    if (entry == NULL) { requested = NULL; prio = floor = 0; return 0; }
    if (line < entry[1] || entry[2] < line) return -1;
  }
  if (entry == NULL) { requested = NULL; prio = floor = 0; return 0; }
  DAT_0048c780 = priority;  DAT_0048c740 = entry;  DAT_0048c750 = priority - 0x28;   // the floor the priority decays to
}
```

Once a tick `FUN_0040efe0` lowers the priority by one until it reaches that floor (so a line is protected for 40 ticks against equals, then only a real higher one displaces it), and if the requested line is not the playing one it starts the change. The **transition** is the line's list entry for the playing line, else its default byte: type 0 (`0x40ef00`) fades the old one out, then starts the new; type 1 and 2 (`0x40ef60`, `0x40ef90`) start it at once. Deaths cut the current theme (type 2), a theme replaces the same theme immediately (type 1).

## Step 3: what asks for each line: `FUN_0040f3c0`, a state machine (`DisasmForce.java 0x40f3c0 0x40f5f0`)

Once a tick, with the interface bits `_DAT_0048c77c` set by the game (document 71 listed them; the last unknown ones are now placed):

| trigger | request | state |
| --- | --- | --- |
| the player's vehicle died (`DAT_0048c78c`, set by the wreck's init `FUN_0040c7e0`) | its own death line (the byte table at `0x4466e4`: Tank 3, Jeep 5, MSV 7, Heli 10) if a theme was playing (state 4), otherwise the generic Death (15); priority `0x80` | 9 |
| bit `0x100`: a flag was created (`FUN_00432710`) | Flag Discovery (11), `0xfe` | 7 |
| bit `0x1000` (set at `0x434b35`, a submarine object) | Sub (16), `0x8a` | 6 |
| bit `0x200`: a flag is carried by the other team, set **every tick** by the flag's update (`FUN_00432acb`) | Flag Pickup (12), `0x8a` | 5 |
| bit `0x400`: set **every tick** while the player's vehicle exists (the first instruction of the vehicle's state handler `FUN_0040b980`) | the vehicle's theme `FUN_0040f2f0`, `0x80` | 4 |
| `players <= DAT_0048c734`, the count of players on the vehicle-choice screen (`+1` in `FUN_00418290`) | **Bunker** (14), `0x68` | 3 |
| nothing playing while the state is above 1 | silence, `0x64` | 0 |

`FUN_0040b980`'s activation block, run once when a vehicle is created, also asks at once for the record's own line: the bytes `+0x2bc` / `+0x2bd` of the four vehicle records (`0x445974`, `0x445c5c`, `0x445f44`, `0x44622c`) are line 0 / 4 / 6 / 8 and priority `0x80`. `FUN_0040f2f0` (decompiled) then picks the actual theme: a Tank gets **theme 2 if its own flag is carried or the other flag is within 128 units** (the squared distance `FUN_0042cda0 < 0x4000`), theme 0 if its stock byte is 2, else theme 1 when a random 0-7 is above 3, otherwise 0; a Jeep and an MSV the record's line; a Heli 8 (stock 2, or a roll below 4) or 9. The window makes Heli 2 (`lowest` 8, `highest` 3) unable to replace Heli 1 at the tie, so a Heli always plays theme 1.

The game also asks for Bunker (priority `0x80`, counter set to the player count) at the start (`0x420b34`) and when the choice screen is set up (`0x421da8`): **Bunker is the hangar's music.** That sets document 71's open question ("`DAT_0048c734`, probably remaining targets") straight: it is the number of players on the choice screen.

When a line's tracks are all played (`FUN_00405480`'s thread calls `FUN_0040f600`): a looping line asks for itself again from its alternate track; a **sting** clears the priority and asks for the previous line at priority 100 if the player's mode is the game view, else for Bunker at `0x40`. So after a Tank's death sting, in the loss sequence (not the game view), the hangar theme plays until the choice, and after Flag Discovery the theme comes back. At the end of the match `FUN_00405660` asks for silence at `0x100`.

## Applied in the port

`tools/extract_music.py` reads the offsets and the line table from `RFIRE.BIN` and the WAV from the CD image and writes `music/track_NN.ogg` (18 MB) and `music/music.json` into the pack (gitignored). `game/music_director.gd` is the logic above, function for function (`request`, `tick`, `segment_ended`, `vehicle_line`); `game/music_manager.gd` feeds it the interface bits by watching the match and plays the result:

```gdscript
func _tick() -> void:
	if mc.match_finished:
		return   # the end-of-match handler has replaced the game view's loops that run the director (document 92)
	director.bit_flag_carried = _flag_carried_by_other_team()
	director.bit_vehicle = _vehicle_exists()   # FUN_0040b980 sets the bit every tick the vehicle's handler runs
	director.tick(_vehicle_theme)
```
```gdscript
if bit_flag_carried:
	request(LINE_FLAG_CARRIED, 0x8a)
	state = STATE_FLAG_CARRIED
	_clear_bits()
	return
```

A line becomes a gapless `AudioStreamPlaylist` of its tracks; a type-0 transition fades the old one out (0.75 s: **untraced**, the original's mixer command 6) before the new starts. `GameSettings.music_enabled` (`user://settings.cfg` `[audio] music`, `RF_NO_MUSIC=1`) turns it off. Scripted checks: `tools/tests/music_director_check.gd` (25 checks: the theme choice, the priority decay to its floor, Flag Discovery cutting in and the theme returning, a sting ending outside the game view starting Bunker, loops, the Tank's death line versus the generic one, Heli 2 never displacing Heli 1, Bunker yielding to a theme) and `music_manager_check.gd` (the pack loads; Tank 1 is a playlist of tracks 8-11 of the right 417 s; Bunker is track 20; a loop restart begins at the alternate track). In the real scene (with the dummy audio driver, so nothing was heard) `RF_DEBUG_MUSIC=1` prints the sequence: at a forced death `theme 0 -> Tank Death (3), cut -> Bunker (14)`; in the autoplay `theme 0 -> Flag Discovery (11) -> Flag Pickup (12)` and silence at the win.

## Not done / untraced

- **Not listened to by me**: the decisions are checked, the sound itself is not. Volume (`-6 dB`, the original's mixer word is `0x7fff`, the maximum) and the type-0 fade length are the port's.
- **The source-object rule:** a line requested with a source object (a vehicle's theme) is cancelled when that object's serial changes (`FUN_0040efe0`: `FUN_0040f1c0(-1, 0x7fffffff)`), i.e. the music stops the instant the vehicle is destroyed; in the port the death line replaces it in the same tick.
- **The port starts inside the vehicle**, so it opens on the theme; the original opens on the hangar screen with Bunker. Priority `0x80` Bunker at the start and at each choice is only reproduced for the choice (`choosing`).
- **Win (13)** has no caller among the traced request sites (the win screen's own sound is the `Win*.stm` stream of document 92); **Sub (16)**: the submarine object that sets bit `0x1000` (`0x434b35`) is not in the port; **Drums (17)** is the title screen's.
- Two-player rules, the CD-audio (MCI) path, pause behaviour, and a tiny gap where a looping line restarts (each pass is a new playlist).
- The per-type lines and death lines are constants in `music_manager.gd` (`RECORD_LINE`, `DEATH_LINE`); they belong in the vehicle definitions (plan 2.7.6) and are noted for the framework's owner.

**Corrections:** [document 14](14-worked-example-music-mechanism.md) (the real `Score.WAV` is on the CD image, and the game folder's `DRUMS.WAV` is line 17's file), [document 71](71-worked-example-jeep-compass-and-announcer.md) Part B (the table is the music, not an announcer), and the untraced-choices entries that say the announcer is untraced.

**Next:** [the next-steps doc](NEXT_STEPS.md).
