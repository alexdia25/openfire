# How we're doing this

This folder is a **walkthrough of the method**, not a reference of the results. It exists
so you (the project owner, not just an AI agent picking up context) can follow how each
file format got cracked and, eventually, do the next one yourself.

The results — the actual current ground truth about every format, every open question,
every architectural decision — live in [`docs/PORTING_PLAN.md`](../PORTING_PLAN.md). That
document is optimized for an AI agent resuming work with no memory of this conversation:
dense, exhaustive, organized by topic. These documents are optimized for a human reading
them in order for the first time: narrative, worked examples, real commands you can re-run.

**Read them in this order:**

1. [**Setting up the toolchain**](01-setting-up-the-toolchain.md) — what's installed, where,
   and why it has to run headless (no GUI automation available to an AI agent).
2. [**Easy formats first**](02-easy-formats-first.md) — `.SDT` and `.RFA`, cracked with
   nothing but a hex viewer and knowledge of two standard file formats. No disassembler
   needed. Start here to build intuition before reaching for Ghidra.
3. [**The Ghidra workflow**](03-ghidra-workflow.md) — the general recipe for cracking a
   format that *isn't* just a renamed standard one: anchor on a string or API call,
   decompile outward from it, form a hypothesis, verify against every real file.
4. [**Worked example: the `.RFM` map format**](04-worked-example-rfm-format.md) — the
   recipe from step 3, run in full, on a real format, with real commands and real output.
   This is the one to read closely.
5. [**Worked example: `ART.CAR` and a wrong turn**](05-worked-example-art-car.md) — the
   same recipe, except the first hypothesis was wrong, it got shipped as a "best effort"
   converter anyway, and *that was a mistake* — here's how it got caught and fixed.
6. [**Verification philosophy**](06-verification-philosophy.md) — the handful of hard-won
   rules that came out of documents 4 and 5, distilled so you don't have to relearn them
   the expensive way.

   **Before continuing to document 8, check [`NEXT_STEPS.md`](NEXT_STEPS.md).** It's
   deliberately not numbered into this sequence — everything above and below it is a frozen
   snapshot of how one specific question got answered, but `NEXT_STEPS.md` is the opposite:
   it's edited in place every time the backlog changes, so it always reflects the *current*
   open-questions state rather than the state as of whenever it was written. Read the numbered
   docs below for the story of how each item got solved; read `NEXT_STEPS.md` for what's
   actually left right now.

8. [**Worked example: mapping `.RFM` art ids to `ART.CAR` cels**](08-worked-example-art-id-mapping.md) —
   the backlog's top item, solved: the recipe applied a third time, this
   time chaining two data-structure traces straight to an exact answer with no guessing
   needed.
9. [**Worked example: the exact tint colour of `ART.CAR`'s effect masks**](09-worked-example-effect-tint-colour.md) —
   document 5's own loose end, solved: reading a fallback-generation algorithm in full,
   catching a real refinement by checking mask bytes against real data instead of trusting
   the code alone, and discovering one of the 93 "masks" wasn't a mask at all.
10. [**Worked example: what the `>>1` computation actually does**](10-worked-example-target-respawn.md) —
    a deliberately small one: two `FindDataXrefs.java` calls, no dead ends, and a stale guess
    corrected along the way — plus a postscript chasing the obvious next hop into a real,
    honestly-recorded dead end.
11. [**Worked example: confirming a dead end fast by rereading work already on hand**](11-worked-example-edtn-chunk.md) —
    the smallest one here: zero new Ghidra calls, just rereading a decompile log this
    project had already produced for a different question.
12. [**Worked example: decoding the `.RFM` header body with no Ghidra at all**](12-worked-example-header-body.md) —
    a pure byte-variance correlation across all 204 real files finds a timestamp pair and
    the actual level designers' names, still sitting in the shipped data. No disassembler
    needed, by design this time rather than luck.
13. [**Worked example: catching a wrong guess by finally rendering it**](13-worked-example-reticle-not-swatch.md) —
    document 9's "team-colour swatch" guess, retracted: the 4 cels turn out to be a
    target-lock reticle. A disproof that cost one crop of already-generated converter
    output, not a new investigation.
14. [**Worked example: is the music CD audio or a WAV file? (Both.)**](14-worked-example-music-mechanism.md) —
    tracing every caller of `mciSendCommandA` finds a CD-audio path and a WAV-streaming
    fallback sharing one per-track table, and along the way disproves the obvious guess
    about *which* WAV file (it's not `DRUMS.WAV`).
15. [**Worked example: the native resolution, and a tick rate that resists being found**](15-worked-example-resolution-and-tick-rate.md) —
    one backlog item that resolves cleanly (320x240) and a paired one that traces all the way
    to the real per-frame dispatch chain without landing a confirmed number, recorded
    honestly as a bounded, not-yet-finished trail rather than forced into a tidy answer. Its
    postscript then takes that trail's own next hop and rules it out as the wrong system
    entirely (the boot-time title slideshow).
16. [**Worked example: there's no sprite pivot, because it's not 2D**](16-worked-example-3d-projection.md) —
    the biggest architecture finding yet: vehicles are rendered via real perspective-projected
    3D quads (64 discrete headings, a shared 1/z table also used by the terrain blitter), not
    flat sprites rotated around a pivot. Reframes a data question into a real, now-informed
    rendering-architecture decision for Godot.
17. [**Worked example: reference discs arrive, and a stale guess gets corrected for free**](17-worked-example-reference-iso.md) —
    no Ghidra this time: cataloguing a newly-supplied retail ISO and identifying a 3DO
    expansion-pack disc image quietly disproves a guess that had been sitting in the plan
    since section 1.2 (the "missing `.avi` cutscenes" are actually more streamed audio) and
    opens a genuinely new goal (3DO "Maps o' Death" extraction).
18. [**Worked example: finding a COM vtable call with no symbol to search for**](18-worked-example-vtable-flip.md) —
    closes out document 15's tick-rate loose end: `Sleep()` and `SetTimer` were both ruled
    out by name, but the last candidate, `IDirectDrawSurface::Flip`, has no name to search
    for at all. A new script hunts vtable calls by slot offset instead, finds the game's one
    present routine, and shows there's no fixed tick — a blocking `Flip()` paces fullscreen
    play on vsync, and windowed play isn't paced by this mechanism at all.
19. [**Worked example: classifying 2165 cels without a disassembler**](19-worked-example-asset-registry.md) —
    a different kind of document: building the asset ID registry (section 2.4.1) isn't a
    reverse-engineering question, it's an authoring task. Covers the contact-sheet tooling,
    a scope trade-off made explicitly (coarse pass now, refine later) rather than assumed, two
    places a pixel-colour average beat eyeballing, and what just *looking* at every cel turned
    up: a new lead on team colouring and a possible rescue/infantry mechanic nobody had
    suspected before.
20. [**Worked example: a wrong palette that never looked wrong enough to notice**](20-worked-example-palette-offset.md) —
    the game's first rendered screenshot looked plausible and was still wrong: a raw pixel
    byte needs a `-10` shift into the shared PLUT before it matches the game's real, active
    palette, traced through a fade routine that's the only caller of `SetPalette` anywhere in
    the binary. Caught only because the user compared it against real screenshots — internal
    consistency checks (this project's usual habit) can't catch a bug that's wrong everywhere
    in the same plausible way.
21. [**Worked example: "the sprite looks very wrong after moving" was two bugs, not one**](21-worked-example-vehicle-mirroring-bug.md) —
    Phase 4 steps 2/3 (a player-controlled vehicle, a scrolling camera): a real mirror-flip
    bug in the vehicle's rotation rendering, and how tracing it surfaced a second, unrelated
    bug — an asset-registry auto-numbering script quietly undoing an already-confirmed
    team-colour rename every time it ran.
22. [**Worked example: reusing a solved RE finding as running code**](22-worked-example-weapons-and-targets.md) —
    Phase 4 steps 4/5 (weapons/projectiles, destructible targets): step 4 is an honestly-
    flagged placeholder, but step 5 turns a mechanism section 1.5 already fully traced from
    the binary directly into running Godot code — and shows what verification looks like when
    the real answer is already known and the only question is whether the reimplementation
    is actually correct (a 2000-trial unit test plus a real-scene integration test, not a
    screenshot).
23. [**Worked example: an opponent with no reverse-engineering behind it at all**](23-worked-example-enemy-ai-first-pass.md) —
    Phase 4 step 6 (enemy AI): unlike every other Phase 4 step so far, this one reimplements
    nothing from `RFIRE.BIN` — Phase 3's AI backlog is still untouched. Covers splitting
    `Vehicle`'s movement/firing code into two overridable decision seams instead of copy-
    pasting a second vehicle script, and a rate-dependent behaviour test that had to stop
    relying on headless mode's real (unthrottled) frame timing and drive `_process()`
    directly at a fixed timestep instead.

## The one rule that overrides everything else here

**Never commit extracted game assets or decompiled code to this repository.** Every
converter writes its output to `/build/`, which is gitignored. Every Ghidra project lives
outside this repo entirely (`C:\Users\Alex\Documents\code\tools\ghidra_projects\`), because
a Ghidra project file *is* a disassembled/decompiled copy of the copyrighted binary. What's
committed here is original analysis and original code: which byte means what, and the
converter that acts on that knowledge — never the game's own bytes or code. See
`docs/PORTING_PLAN.md` section 0 for the full legal rationale.

This is also why the images in `docs/process/images/` are either original schematic
diagrams (redrawn to illustrate a finding, not real cel pixels) or, where noted, a
synthetic debug visualization whose colours are procedurally assigned by numeric ID
(`tools/convert_rfm.py`'s `render_debug_png()`) rather than sampled from the game's own
art — never a crop of real extracted sprite art, even a small one.

## Where things actually live

| What | Where |
|---|---|
| The plan / current ground truth | `docs/PORTING_PLAN.md` |
| This walkthrough | `docs/process/` |
| Converters (Python, no dependencies) | `tools/*.py` |
| Ghidra scripts (Java, compiled on the fly) | `tools/ghidra_scripts/` |
| Dumped lookup tables from the binary | `tools/data/` |
| Your own copy of the game | `C:\Users\Alex\Documents\returnfire` (not in this repo) |
| Ghidra + JDK + the analysis project | `C:\Users\Alex\Documents\code\tools\` (not in this repo) |
| Converter output | `build/` (gitignored, regenerate any time) |
