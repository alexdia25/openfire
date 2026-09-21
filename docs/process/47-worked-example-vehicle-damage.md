# 47. Worked example: how a hit reaches a vehicle

**Question:** when a shell or an explosion touches a vehicle, how much damage does it do and what happens next?
[Document 45](45-worked-example-traced-vehicle-movement.md) guessed that the Tank record's `+0xe8` (100.0) was hit
points. It is not; this document finds where health really lives. Field names and scripts are in the
[tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: find the function that runs when something hits a vehicle

Every kind of object has a **class descriptor**: a table of function pointers (init, destroy, update, draw, hit...).
We already knew the vehicle's init function, `FUN_0040b700` (document 45). Searching the raw bytes for that pointer
finds the vehicle class descriptor at `0x445438`:

```bash
... -postScript FindBytes.java 00b74000        # 0x40b700 little-endian
```

Reading the descriptor's slots:

| Slot | Function | Role |
| --- | --- | --- |
| `+0x08` | `FUN_0040b700` | init (spawn) |
| `+0x0c` | `FUN_0040b8b0` | destroy |
| `+0x10` | `FUN_0040b980` | update |
| `+0x14` | the Tank draw descriptor | drawing |
| **`+0x3c`** | **`FUN_0040c460(victim, hitter, damage)`** | **hit callback** |

We confirmed `+0x3c` is "someone hit me" by looking at its callers: the projectile hit code `FUN_00414e60` calls
`victim_class->+0x3c` with the projectile type's damage (document 45), and the explosion-damage code `FUN_0042dd20`
calls it with `-(rate x dt)` every tick. Shells and explosions both end up in `FUN_0040c460`.

## Step 2: read what the hit callback reads

`FUN_0040c460` reads its numbers through `state[0]`, a pointer from the player's state block (`0x458100 + n*0x140`)
back to the vehicle's type record. The fields it touches:

| Record offset | Meaning | Tank | Jeep | MSV | Heli |
| --- | --- | --- | --- | --- | --- |
| `+0x24` | armour | 0.3 | 0 | 0.5 | 0.2 |
| `+0x28` | **hit points** | **22** | **1** | **26** | **15** |
| `+0x234` | dying handler (0 = spawn a wreck object at once) | 0 | see below | | |
| `+0x238` | hit-reaction callback (optional) | none | | | |

The rule the function follows:

1. If `damage - armour` is less than one raw unit (1/65536), **nothing happens**.
2. Otherwise `hp -= damage - armour`, and the vehicle records "hit until tick now + 10" in `state+0x4c`.
3. While `hp > 0` the optional reaction callback runs.
4. At `hp <= 0` the vehicle either switches to the dying handler `record+0x234`, or spawns a wreck object (class
   `0x4453e8`) and is destroyed. A very negative hp (below -40) also flags the wreck.

Checking the rule with real numbers: a Tank shell (damage 1.0) does 1.0 - 0.3 = 0.7 to a Tank, so **32 shells** kill
it (22 / 0.7 = 31.4). A rocket of damage 2 does 1.7 (13 rockets); a damage-4 shot does 3.7 (6 shots). The Jeep (1 hit
point, no armour) dies to any shot.

Document 45's `+0xe8` (100 / 250 / ? / 200) is something else: it sits in a block copied to the state at `+0xe0`, a
speed-tilt or fuel-like quantity that is still untraced. Reading it as health was wrong.

**The hit flash.** The `state+0x4c` "hit until" time was guessed here to be the yellow variant cels flashing for 10
ticks (0.16 s), unconfirmed. [Document 59](59-worked-example-vehicle-part-animation.md) later read the draw
callbacks and confirmed it: while `state+0x4c` is still in the future the vehicle is drawn with variant 2.

## Step 3: water (a side finding)

`FUN_0040cef0` (record `+0x4c`) reads `state+0x70`; nonzero means "in water".

- Value 2 (deep) sinks the vehicle: it swaps the drawn descriptor to `record+0x154` and installs the sinking handler
  `FUN_0040cf90`, unless it is a type-1 vehicle with `state+0x84 == 1.0` (the amphibious Jeep case).
- Value 1 (shallow) with speed above half the terrain-scaled maximum switches to the wading descriptor `record+0x14c`
  and the handler `FUN_0040d150`.

This is where document 45's "in water" speed caps come from. Not modelled.

## Step 4: explosion objects are bytecode scripts, not sprite lists

While following the explosion damage path we found that an explosion object (class `0x44bb70`, name string "Expl")
is a tiny interpreter. It runs a byte-coded script (record entry `[0]`, for example `0x4450d0`) on a progress counter
that grows by `record[5]` per tick up to a duration `record[3]` (25 ticks for `0x445138`, 90 for `0x444ee8`).

- Byte 0 ends the script, 1 stops, 2 waits until the progress reaches the next byte.
- Every other byte indexes the handler table at `0x44bae0`: play a sound (`FUN_0042d360`), spawn or replace a tile
  (`FUN_0042d3f0`), damage the tile at an offset (`FUN_0042d850` / `d8d0`, 255 damage, document 44), swap the draw
  descriptor (`FUN_0042d4e0`, `d610`), set a light or quad (`FUN_0042d640`), draw a decoration list (`FUN_0042d790`),
  loop or branch (`FUN_0042d540`, `d950`).

These are the tile destruction sequences that coastal entries and projectile impacts spawn (`FUN_0042e080`). They
reach their art through draw descriptors, so the explosion cels can be found by extracting each script's descriptor
references, a mechanical job done in documents 49-51.

## Applied in the port

- `Vehicle` gets `hp = 22`, `ARMOR = 0.3`, `take_damage()`, `alive` and `destroyed`.
- `Projectile` carries `damage` and `shooter` (a shot never hits its own shooter, as in `FUN_00414e60`).
- `MatchController` tests projectiles against living vehicles with a 12-unit radius (**placeholder**: the real
  collision shape came later, in [document 53](53-worked-example-collision-shapes.md)) and respawns a destroyed
  player at the start point (**placeholder**: no life system is traced). A dead enemy just stops and is hidden.
- Checked by a scripted run: 31 shots leave 0.3 hp, the 32nd kills; self-hits are ignored; the player respawns.

## Not done

Per-type stats for the Jeep, MSV and Heli (added later in document 57), the dying handler, water sinking, and
explosion damage to vehicles.

**Next:** back to [the next-steps doc](NEXT_STEPS.md).
