# 70. Worked example: the panel of each vehicle: base picture, fuel bar, ammo bars, compass, radar

**Question:** documents 66 and 68 found the panel machinery (a template plus elements added per vehicle by `FUN_00412cd0`). What does each of the four vehicles actually put on its panel, and is there a health readout?
Scripts and field names are in the [tracing cheat sheet](TRACING_CHEATSHEET.md).

## Step 1: who calls the element factory, and with what

`FindCallRel.java 412cd0` lists every call site: `0x40ba1b, 0x40ba3d, 0x40ba95, 0x40bac3, 0x40bae3` (the vehicle set-up, disassembled in document 68), `0x417919 ... 0x41797d` (a *reset* routine that clears slots 5-9
to kind 0 and puts kind 2 back in slot 4) and `0x418339, 0x418349` (slots 3 and 2). Reading the pushes of the set-up (arguments are pushed right to left) gives its slot plan:

| panel slot | kind comes from | its parameter block | the state field it shows |
| --- | --- | --- | --- |
| 5 | record `+0x214` | record `+0x1fc` | fuel (`state + 0x14`) |
| 6 | record `+0x1ac` | record `+0x194` (weapon slot 0's block) | ammunition of weapon 0 (`state + 0x24`) |
| 7 | record `+0x1e0` | record `+0x1c8` (weapon slot 1's block) | ammunition of weapon 1 (`state + 0x34`) |
| 9 | record `+0x270` | record `+0x270` block | radar or compass |
| 8 (Heli only) | 9 | | |

## Step 2: the four records' blocks (`DumpDwords.java 0x4456b8 2980`, record stride `0x2e8`)

Each block: `{max value, kind, top, bottom, left, right, speed}`, rectangles in whole pixels relative to the panel (the record stores them 16.16):

| vehicle | fuel bar (slot 5, kind 5) | weapon 0 (slot 6) | weapon 1 (slot 7) | slot 9 |
| --- | --- | --- | --- | --- |
| Tank | max 400: x 88-127, y 12-15 | max 150, **kind 4 bar**: x 76-115, y 31-34 | none | **kind 6 radar** at (19, 11), 32 x 32 |
| Jeep | max 500: x 15-50, y 10-12 | max 16, **kind 7** (16 pips) | none | **kind 8**, at (69, 6), 16 x 16: the compass |
| MSV | max 320: x 19-63, y 26-28 | max 100, kind 4: x 29-73, y 11-13 | max 10, kind 4: x 29-73, y 41-43 | kind 6 radar at (89, 9), 39 x 34 |
| Heli | max 400: x 9-33, y 25-27 | max 100, kind 4: x 55-103, y 45-47 | max 50, kind 4: x 110-135, y 25-27 | kind 6 radar at (56, 5), 32 x 32 (a second cel set `0x7bd`, `0x7b8`) |

(The maxima are the starting ammunition: Tank 150 shells, Jeep 16 missiles, MSV 100 rockets and 10 mines, Heli 100 and 50: documents 45, 58, 60, 61, 63 met the same numbers. **Ammunition is not modelled yet (user's decision), so
the ammo bars are left out of the port for now.**)

Kind 4 is a bar like kind 5 (`FUN_00411da0` is the same drawing) with a different colour set (`0x446778` instead of `0x446760`) and a value that follows an object field (`slot + 0xc`); kind 7 (`FUN_004127b0`) lights
up to 16 small cels one by one (tween `0x9999` per tick), cel `0x20ac0` / `0x7af`; kind 8 (`FUN_00412960`) shows a cel picked by the absolute value (0-16) of `state + 0x5c`, from one of two tables depending on its sign: **a needle that swings to
either side**, the Jeep's compass (the Jeep has no radar of its own on its panel; `state + 0x5c` is set by its state handler, document 57's direction to the flag: still to confirm).

## Step 3: the panel picture: kinds 2 and 3, and cels 1943-1946

Kind 2 (`FUN_00411bb0`) with its init `FUN_00411b70` is the panel's *base picture*: the init does `slot.cel += 0x797` (= 1943). The four cels 1943-1946 are all 144 x 56; drawn one under the other (a contact sheet) they are four metal panels:
a dark screen, a yellow jerry-can (fuel) icon, rocket icons (ammo) and bars for the first; a round dial with a fuel can and two rungs for the second; two screens/three icons for the third; a round radar circle for the fourth. They match
the four vehicles in record order (**1943 Tank, 1944 Jeep, 1945 MSV, 1946 Heli**), and the slot 9 positions above fall on their screens (Tank's radar at (19, 11) is the dark square on the left). The kind-2 callback also slides
the panel: it eases its y offset (`panel + 0x104`, updated by `FUN_0042cdd0` at `dt * 0x...`) so a new vehicle's panel rises into place. The registry now names them `ui.hud.panel.*` (and 1940 `ui.hud.panel_blank`,
the empty frame the template draws before any vehicle: hand edit plus `AUDIT8` in `classify_batch2.py`).

## The bar colours (open, and how far they are read)

Each bar draws its filled part with a 1-pixel cel (`0x238b4`) whose PLUT pointer (`+0xc`, per `rf_effect_cel.py` an own palette) is `0x446760 + colour * 2` for fuel (`0x446778 + ...` for ammo) and `0x446758` for the empty part. Memory there:
`00 00 00 7c | 00 00 20 7d | 00 00 20 7e | 00 00 40 7f | 00 00 00 40 | 00 00 00 00 ...`: as 16-bit words the second word of each pair is `0x7c00, 0x7d20, 0x7e20, 0x7f40` then `0x4000`, and the empty colour is `0x0884`. Read as 15-bit RGB
(5-5-5) these are red, orange-red, orange, yellow, dark red, and a near-black blue-grey. That reading is a **guess**: the port uses it and marks it untraced (whether these tables are 15-bit words or bytes of the 8-bit palette
is not yet confirmed against the blit routine `FUN_00419ea0`).

## There is no health readout

Not on any of the four panels: the slots are fuel, ammunition (1-2), and radar/compass. Vehicle hit points are shown to the player only through the vehicle itself (document 59's hit flash and the wreck of document 48).
The port's "hp" text is therefore a debug aid, not something the original has.

## Not done

Kind 3 (`0x411c90`, a second base variant); kind 9 (Heli slot 8); the exact meaning of `state + 0x5c` for the compass; the colour tables' format; the panel slide's constants; the announcer.

**Next:** rendering the traced panel (base cel, fuel bar, radar) in the port.

## Applied in the port (checked by screenshots)

`tools/extract_hud_panels.py` -> `tools/data/hud_panels.json`; `build_pack.py` adds each base cel's sprite id (`packs/original_pc/hud/panels.json`); `game/hud_panel.gd` draws the panel of the current vehicle: base picture,
fuel bar (rectangle, easing 0.6 px per tick, colour steps) and radar window at the record's position and size. Screenshots of the Tank, MSV and Heli: **the radar window falls exactly on each panel's screen and the fuel bar on its fuel slot**
(the empty dark bars beside them are the ammunition bars, not modelled), which confirms the record coordinates and the 1943-1946 order. The "hp" line left in the port's text is a debug aid. Not drawn: ammunition bars, the Jeep's
compass, the radar grid/brackets, the slide-in; the 3x scale and the bottom-left position are the port's "modern" layout (the original's screen layout is traced in [document 96](96-worked-example-the-original-screen-layout-and-the-classic-hud.md)); the bar colours are the unverified 15-bit reading.
