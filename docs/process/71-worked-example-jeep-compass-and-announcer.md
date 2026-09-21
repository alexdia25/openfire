# 71. Worked example: the Jeep's compass, and how the announcer chooses its lines

**Question:** documents 68 and 70 left two interface items: what drives the Jeep panel's element of kind 8 (`state + 0x5c`), and what triggers the voice lines. Scripts and field names are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Part A: the compass

### Step 1: the writer of `state + 0x5c`

The Jeep's state handler `FUN_0040d990` (document 57 met it for the capture check) is also the only writer. Decompiled (`DecompileMany.java 40d990`), reduced to what matters (`obj` = the Jeep, `param_3` its state block,
`other` = the flag of the *other* pool: `(&DAT_0045ae48)[owner == 0]`):

```c
if (other != 0) {
  if (other.carrier == obj) {                          /* we carry it */
     if (home tile reached) { FUN_004225d0(owner); return; }      /* the capture of document 57 */
  } else {                                             /* not carried by us: point at the flag */
     bearing = FUN_00422e70(obj.pos, other.pos);       /* 22-bit heading, rounded down to 64 steps */
     m = magnitude(bearing - obj.heading);              /* below */
     if (m >= 0) { value = -m;  goto store; }           /* a flag target is negative */
  }
}
bearing = FUN_00422e70(obj.pos, home);   home = *(&DAT_0048c8b4)[owner * 0x34]
m = magnitude(bearing - obj.heading);  value = max(m, 0)               /* a home target is positive */
store:
  state + 0x60 = (value == -16);  play 0x44b928 the first time it becomes -16
  if (state + 0x5c != value) { state + 0x5c = value; FUN_00412cb0(panel, 0x200); }   /* redraw slot 9 */
```

`magnitude(d)`, with `d = (bearing - heading) & 0x3fffff` (22-bit turns):
`if ((d & 0x3e0000) == 0) return 16;` then fold `d` to its absolute value (`if d > 0x1fffff: d = -d & 0x3fffff`); `if d < 0x100000 (90 degrees): return min((0x10000 - (d >> 6)) >> 12, 15)`; else `-1`.

Translated: the value says **how well the Jeep points at its target**, not which way to turn: 16 when the target is 0 to 11.25 degrees *clockwise* of the nose (the mask test only catches small positive differences: a target just to
the other side gives 15, a quirk kept), 15 falling to 12 as the target moves out to 90 degrees, and beyond 90 degrees a flag target is dropped for **home** (positive), which shows 0 when home is also behind. Negative =
the flag, positive = home; `-16` chimes.

### Step 2: the element (kind 8, `FUN_00412960`) and its cels

Kind 8 draws one fixed cel and picks a palette by `|value|` (the two tables `DAT_00449654` / `DAT_00449658`, 17 entries each, sit in the cel's PLUT pointer field `+0xc`): `celtable + 0x20b04` for a negative value and
`celtable + 0x20b8c` for a positive one. Dividing by the record size (`0x44`) gives cels **1969** and **1971** (I first mis-divided these offsets and thought the table had a 4-byte shift; it has not: `0x20b04 = 1969 * 0x44`).
By their pictures they are two 16 x 16 target rings (purple and yellow, a blue centre / a red centre). It is drawn at the record's position (69, 6) on the Jeep panel: a recess exactly its size (checked by screenshot). **The per-value
palettes are not read** (the tables are filled at run time), so the port draws the two cels as stored.

The same offset error corrected two earlier claims: `0x203d8` (document 66) is cel **1942** (the 124 x 50 panel interior with the Jeep's controls), and the sixteen cels at `celtable + 0x2052c` (document 68) are cels **1947-1962**, which are 32 x 32 rings
of growing size: the radar's *ping*, chosen by a distance (`FUN_00410b70`), for any object of class 1 (a vehicle; the test `**(obj+0x14) == 1` is on the object's class record, not the Jeep's type record) that did something in the last 64 ticks. **It is not the
Jeep's direction arrow**; that role belongs to the compass above.

### Applied in the port

`MatchController.compass_value(v)` and `game/hud_panel.gd` (the Jeep's panel draws the ring; the radar is hidden for the Jeep, as in the original). Checked by `tools/tests/compass_values.gd`: a flag due east, heading 0 gives -16, 5 gives -15
(the asymmetric quirk), 12 gives -15, 30 -14, 60 -13, 89 -12, 91 falls back to home (0 here, home being behind); carrying the flag with home due west and the nose west gives 16. **Untraced**: the home position (taken as the spawn; the original reads a pointer at
`0x48c8b4 + player * 0x34`), and the per-value palette.

## Part B: the announcer (`FUN_0040f3c0`, table `0x4463b8`)

### The table

`DumpDwords.java 0x4463b8 200` plus the strings gives 18 entries of `0x2c` bytes: `{byte index, byte lowest, byte highest, byte enabled, name pointer, ..., sound list pointer, ...}`. The names (the voice lines):

| # | name | # | name | # | name |
| --- | --- | --- | --- | --- | --- |
| 0-2 | Tank 1, Tank 2, Tank 3 | 6 | MSV 1 | 11 | Flag Discovery |
| 3 | Tank Death | 7 | MSV Death | 12 | Flag Pickup |
| 4 | Jeep 1 | 8, 9 | Heli 1, Heli 2 | 13 | Win |
| 5 | Jeep Death | 10 | HELI Death | 14 | Bunker |
| | | | | 15 | Death |
| | | | | 16 | Sub |
| | | | | 17 | Drums |

Each entry has a list of sound ids (pairs such as `0x100, 0x101, 0x102, 0xff`: the lines of one speaker / a random pick); which audio file each id is is **not traced**, so what is *said* is unknown from the code.
`FUN_0040f1c0(line, priority, source)` queues a line: it refuses an unknown line, ignores the line if it is already playing, and lets a new one interrupt only when its priority is at least the current one (`DAT_0048c780`) and the
line's [lowest, highest] window allows it. Lines are muted when the "voices" option (`DAT_00443008`) is off, except entries whose *enabled* byte has bit 0 (Flag Discovery, Win, Sub, Drums).

### The trigger logic (`FUN_0040f3c0`, run once per frame from `0x4096ba` / `0x409adc`)

A small state `DAT_0048c73c` (0 idle ... 9) and the interface bits `_DAT_0048c77c`:

| condition | line (priority) | state |
| --- | --- | --- |
| `DAT_0048c78c != 0` (the player's vehicle died; written at `0x40c7f5`): the death line of the vehicle (`[record + 0xaf]`), or Death (15) | (0x80) | 9, bits cleared |
| bit `0x100` (a flag has appeared: set by `FUN_00432710`) | 11 Flag Discovery (0xfe) | 7 |
| bit `0x1000` | 16 Sub (0x8a) | 6 |
| bit `0x200` (a flag is carried by the other team's vehicle: set by the flag update) | 12 Flag Pickup (0x8a) | 5 |
| bit `0x400` and the player has a tracked object of the current owner | the vehicle's line from `FUN_0040f2f0` (0x80) | 4 |
| `DAT_0048c734 >= players` (a counter that starts at level set-up and is incremented/decremented at `0x41837b` / `0x418077`) | 14 Bunker (0x68) | 3 |

`FUN_0040f2f0` picks the vehicle line: Tank: line 2 ("Tank 3") if its own flag is carried or the other flag is within `0x4000` units, else 0 or 1 by whether a random 0-7 is above 3 (and 0 when the tracked byte at `0x48c938` says 2); Jeep and MSV: a byte of the record
(`+0x2bc`); Heli: 8 or 9 (random), 8 when that byte is 2. "Win" (13) is queued from `0x420b34...` (match end). Only the *decision structure* is read; the meaning of the counter `DAT_0048c734` ("Bunker": probably the count of remaining
targets reaching the number of players) and of bits `0x400` / `0x1000` is **not traced**.

### Not applied

The port has no voice lines (no audio yet) and does not invent captions for them. The table and triggers are recorded here for the audio pass.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
