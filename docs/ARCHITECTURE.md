# Architecture

Two diagrams: the offline pipeline that turns the original game into a Godot pack, and the
shape of the runtime code that pack loads into. For the detailed ground truth behind either
one, see [`PORTING_PLAN.md`](PORTING_PLAN.md); for how each piece was found, see
[`docs/process/`](process/README.md).

## The pipeline

<svg width="100%" viewBox="0 0 680 290" role="img" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">
<title>Return Fire to Godot port: pipeline architecture</title>
<desc>A four-stage pipeline: the original game, a reverse-engineering and conversion toolchain, generated data packs, and the Godot runtime, with a documentation layer that traces every stage back to the original code.</desc>
<defs>
<marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="#5F5E5A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>
<g>
<rect x="40" y="40" width="130" height="56" rx="8" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5"/>
<text x="105" y="58" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#2C2C2A">Original game</text>
<text x="105" y="76" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#444441">Not shipped</text>
</g>
<g>
<rect x="190" y="40" width="130" height="56" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="255" y="58" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#04342C">Toolchain</text>
<text x="255" y="76" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#085041">Ghidra + Python</text>
</g>
<g>
<rect x="340" y="40" width="130" height="56" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="405" y="58" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#04342C">Data packs</text>
<text x="405" y="76" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#085041">Not committed</text>
</g>
<g>
<rect x="490" y="40" width="130" height="56" rx="8" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="555" y="58" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#04342C">Godot runtime</text>
<text x="555" y="76" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#085041">Ships in repo</text>
</g>
<line x1="170" y1="68" x2="188" y2="68" stroke="#5F5E5A" stroke-width="1.5" marker-end="url(#arrow)"/>
<line x1="320" y1="68" x2="338" y2="68" stroke="#5F5E5A" stroke-width="1.5" marker-end="url(#arrow)"/>
<line x1="470" y1="68" x2="488" y2="68" stroke="#5F5E5A" stroke-width="1.5" marker-end="url(#arrow)"/>
<line x1="105" y1="96" x2="105" y2="160" stroke="#B4B2A9" stroke-width="0.75" stroke-dasharray="3 3"/>
<line x1="255" y1="96" x2="255" y2="160" stroke="#B4B2A9" stroke-width="0.75" stroke-dasharray="3 3"/>
<line x1="405" y1="96" x2="405" y2="160" stroke="#B4B2A9" stroke-width="0.75" stroke-dasharray="3 3"/>
<line x1="555" y1="96" x2="555" y2="160" stroke="#B4B2A9" stroke-width="0.75" stroke-dasharray="3 3"/>
<g>
<rect x="40" y="160" width="580" height="90" rx="16" fill="#F1EFE8" stroke="#5F5E5A" stroke-width="0.5" stroke-dasharray="4 3"/>
<text x="330" y="190" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#2C2C2A">Documentation &amp; tracing</text>
<text x="330" y="212" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#444441">Every finding traced and paired</text>
</g>
</svg>

The original 1996 executable and its data files (`C:\Users\Alex\Documents\returnfire`) are
never touched by the shipped code — Ghidra and a set of Python extractors
(`tools/extract_*.py`, `tools/convert_*.py`) read them offline and produce a **data pack**
(`packs/original_pc/`: sprites, terrain, levels, vehicles, HUD, audio). Packs embed real
extracted pixel and audio data, so — like the Ghidra project and every raw `.RFA`/`.RFM`/
`.SDT`/`.CAR`/`.BIN` file — they're gitignored; only the hand-authored ID registry under
`packs/registry/` is tracked. The Godot runtime (`game/*.gd`) is the only stage that ships:
it loads a pack at runtime (never through `res://` import, since the pack doesn't exist at
edit time) and contains no decompiled code or original assets, just GDScript. Underneath all
four stages, `docs/process/NN-*.md` pairs each decompiled/disassembled finding with the port
code it became, and `PORTING_PLAN.md` is the standing summary of all of it.

## Runtime internals

<svg width="100%" viewBox="0 0 680 290" role="img" xmlns="http://www.w3.org/2000/svg" font-family="Arial, Helvetica, sans-serif">
<title>Godot runtime internals</title>
<desc>Inside the Godot runtime: the Vehicle simulation feeds MatchController, which orchestrates docking, mines, flags and the win condition, and in turn drives the presentation layer of 3D view, HUD and sound.</desc>
<defs>
<marker id="arrow2" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
<path d="M2 1L8 5L2 9" fill="none" stroke="#5F5E5A" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
</marker>
</defs>
<g>
<rect x="80" y="60" width="520" height="190" rx="20" fill="#E1F5EE" stroke="#0F6E56" stroke-width="0.5"/>
<text x="340" y="88" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#04342C">Godot runtime</text>
<text x="340" y="106" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#085041">All shipped GDScript</text>
</g>
<g>
<rect x="100" y="140" width="150" height="56" rx="10" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="175" y="158" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#042C53">Vehicle</text>
<text x="175" y="176" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#0C447C">Drive, fire, dock</text>
</g>
<g>
<rect x="265" y="140" width="150" height="56" rx="10" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="340" y="158" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#042C53">MatchController</text>
<text x="340" y="176" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#0C447C">Docks, flags, win</text>
</g>
<g>
<rect x="430" y="140" width="150" height="56" rx="10" fill="#E6F1FB" stroke="#185FA5" stroke-width="0.5"/>
<text x="505" y="158" text-anchor="middle" dominant-baseline="central" font-size="14" font-weight="500" fill="#042C53">Presentation</text>
<text x="505" y="176" text-anchor="middle" dominant-baseline="central" font-size="12" fill="#0C447C">View, HUD &amp; audio</text>
</g>
<line x1="250" y1="168" x2="263" y2="168" stroke="#5F5E5A" stroke-width="1.5" marker-end="url(#arrow2)"/>
<line x1="415" y1="168" x2="428" y2="168" stroke="#5F5E5A" stroke-width="1.5" marker-end="url(#arrow2)"/>
</svg>

`Vehicle` (`game/vehicle.gd`) is the per-vehicle simulation: movement, weapons, ammunition,
mines, the docking trigger, and a generic `sound_cue` signal. `MatchController`
(`game/match_controller.gd`) is the orchestrator: docking/undocking, the mine reserve, flags,
the win condition, vehicle selection at the base. Everything under **Presentation** only
*reads* that state to show or play it — the 3D renderers (`vehicle_render_3d.gd`,
`terrain_view_3d.gd` and its siblings), the 2D HUD/radar/hangar-selector screen, and
`sound_manager.gd`. The arrows simplify a two-way relationship: Presentation and
`SoundManager` actually listen to signals `Vehicle` and `MatchController` emit, rather than
being polled by them.

`tools/tests/*.gd` are headless Godot scripts that exercise `MatchController`/`Vehicle`
directly (no scene, no renderer) to check traced numbers — tick counts, damage, stock — against
the disassembly.

---
*Diagrams are hand-authored, not from the original game, and reflect the state as of document
83 (2026-09-22). Regenerate them (ask an agent to update this file) if the module boundaries
above drift.*
