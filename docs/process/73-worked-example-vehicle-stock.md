# 73. Worked example: how many vehicles a player has (the level's T, J, A, H), and what spends them

**Question:** document 66's panel element `FUN_004116a0` draws a count per vehicle type from bytes at `0x48c880 + player * 0xd0 + 0xb8 + type`, and the ammo code (document 72) mentions a reserve at `+0xbc`.
Where do those numbers come from, and what changes them? Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: the source: the level's `VHCL` values

`docs/PORTING_PLAN.md` section 1.5 had decoded the `.RFM`'s six `VHCL` bytes (or the `[A3H5T2]` filename suffix) as `A, H, J, M, T` and an unknown, "never traced for meaning". Their parser `FUN_00413f00`
(decompiled again) ends with the answer to *where they go*:

```c
DAT_00443030 = local_9;  DAT_0044301c = local_9;   /* T */
DAT_00443031 = local_8;  DAT_0044301d = local_8;   /* J */
DAT_00443032 = local_7;  DAT_0044301e = local_7;   /* A */
DAT_00443033 = local_6;  DAT_0044301f = local_6;   /* H */
if (M == 0xff && players == 2) M = 0;   DAT_00448e80 = M;   DAT_00448e84 = unk4;
```

with defaults `T 3, J 8, A 3, H 3, M 0xff, unk4 0xff` and limits `T, A, H < 10`, `J` 1-9, `M < 201`. The four bytes are stored **in vehicle-type order (0 Tank, 1 Jeep, 2 MSV, 3 Heli)**, so `T` = Tanks,
`J` = Jeeps, `A` = MSVs (by position; the letter itself is not explained), `H` = Helicopters: **the number of vehicles of each type the player has for the level** (level 1 uses the defaults: 3, 8, 3, 3).
`M` is a separate count (`FUN_0042a030(M)` at match start, or a level-derived count when `M` is `0xff` and the level's `LEVL` is above 5): **not the mine reserve**; what it spawns is untraced.

## Step 2: what spends and returns them

The per-player bytes at `+0xb8 .. +0xbb` are those four counts. Three sites (found with `FindDispOps.java 0x401000 0x440000 "0xb8]"`):

- **Creating a vehicle** (`FUN_0040b6xx`, disassembled at `0x40b833`): `if (stock != 0xff && stock != 0) stock--`. **255 is "unlimited"** and 0 never goes negative.
- **A vehicle docking at its base** (`0x42f1b0-0x42f1d2`, the function that runs when a vehicle reaches its base tile): `if (stock != 0xff) stock++`, and for an MSV (`type == 2`) it first adds the vehicle's remaining mines
  (`state + 0x40`) to the player's byte `+0xbc` (a **mine reserve**).
- **The last vehicle**: `0x40b330` / `0x40b694` test whether all four bytes are 0; when a vehicle is lost with nothing left the player's state handler is set to `0x418390`: **the lost condition**. (What that handler shows is untraced.)

The creation code also gives an MSV `min(reserve, 10)` mines from the reserve byte `+0xbc` (`0x40ba61`: `puVar1[0x10] = min(reserve, rec[+0x1dc])`, reserve `-=` that), and the reserve is initialised to 0 (`0x4095e7`): so in the
original an MSV's mines may come from that reserve, filled by returning MSVs (and, probably, pick-up crates, `0x42f1bb` context). **The port keeps giving an MSV its full 10 mines** (untraced choice) until the reserve's other writers are read.

## Step 3: the panel element

`FUN_004116a0` (document 66) is therefore the *vehicle-choice* readout: it draws, for the type in its slot parameter, that vehicle's mini icon (cels 2163, 2161, 2164, 2162: Tank, Jeep, MSV, Heli in that order,
which settles the earlier doubt about the silhouettes), the **count left** (`+0xb8 + type`), and the vehicle's ammunition capacity (150, 16, 100, 100) with the second weapon's (Heli 50; MSV: the mine reserve `+0xbc`). What makes the game show it (the trip
back to the base, template slot 2's frame cel 1940) is not traced.

## Applied in the port (placeholders marked)

`LevelData.vehicle_params`; `MatchController.vehicle_stock` (from T, J, A, H; the starting Tank costs one), `_take_stock` / `_return_stock` with the 255 rule; the port's stand-ins: the `V` switch returns the current vehicle and
takes the next type in stock, a destroyed player vehicle is replaced from stock (same type, else the first type left), and with none left `out_of_vehicles` ends the match (a placeholder banner). A placeholder text line shows the counts.
`tools/tests/stock_check.gd`: with 2, 8, 3, 3 after the first Tank, 17 losses run through Tank, Jeep, MSV and Heli stock in turn and then end the match. **All of the choice logic above is untraced**; only the numbers, the spend/return rule
and the lost condition are from the code.

**Correction (document 95):** the loss test the loss sequence actually runs (`FUN_0040b260`) looks at the Jeep stock byte and a live Jeep only, not all four bytes; see [document 95](95-worked-example-after-the-skull-the-choice-and-the-loss.md).

**Next:** sounds.
