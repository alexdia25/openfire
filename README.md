# Return Fire — Godot port

A from-scratch, data-driven Godot 4 reimplementation of *Return Fire* (1996, Silent
Software), the PC/Win95 port of the 3DO original.

Full plan, ground-truth format notes, architecture decisions and phase-by-phase
execution steps: [docs/PORTING_PLAN.md](docs/PORTING_PLAN.md). Read that file before
doing anything else in this repo — it is written to be self-contained.

New to reverse engineering, or want to follow (and eventually continue) the process
rather than just the results? Start at [docs/process/README.md](docs/process/README.md) —
a narrative, example-driven walkthrough of how each format got cracked so far, and how to
keep going.

## Legal

This repository contains **no game assets and no decompiled game code**. It ships
converters and engine code only. To build or run anything asset-dependent, point the
first-run setup at your own legally-obtained copy of *Return Fire*. This is the same
model used by devilutionX, OpenRCT2, and OpenTTD.

## Layout

```
/tools/   Python asset converters + pack validator
/src/     simulation code (fixed-point integer, no Godot engine types)
/game/    Godot scenes, scripts, shaders
/packs/   content packs + the asset ID registry (generated, mostly gitignored)
/docs/    the plan and format notes
/build/   converter output -- gitignored, regenerate locally from your own install
```
