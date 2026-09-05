# 15. Worked example: the native resolution, and a tick rate that resists being found

Two backlog items were bundled together from the start — "native framebuffer dimensions and
the fixed sim tick rate" — because they sound like they'd be found the same way: trace the
window/surface setup, trace the main loop, done. One of them was that easy. The other one
is a genuine example of a question the recipe doesn't cleanly answer, and it's worth writing
up as-is rather than forcing a tidy ending.

## The resolution: one hardcoded default, found in one trace

The game window's actual pixel size comes from `CreateWindowExA` in `FUN_0041abe0`, but the
width/height it passes aren't literal numbers — they're two globals
(`DAT_00448d50`/`DAT_00448d54`) read out of a `RECT` that's been through `AdjustWindowRect`.
[Document 3](03-ghidra-workflow.md)'s recipe again: don't stop at the call site, find where
those globals are actually *written*. `FindDataXrefs.java` on `DAT_00448d50` turned up over a
dozen readers but only one writer with a literal value — the command-line-argument parser,
`FUN_0041a770`, which runs once at startup and sets defaults before parsing any `-flag`:

```c
DAT_00448d50 = 0x140;   // 320
DAT_00448d54 = 0xf0;    // 240
```

**320x240.** Confirmed by a second detail found along the way at no extra cost: the
pause-screen code branches between loading `ART/PS240.RFA` and `ART/PS480.RFA` depending on
a display-mode global, which independently confirms the game supports (at least) a
320-class and a 640-class display mode — 320x240 is the base/default one, reachable without
any command-line override.

This part of the question is closed in the ordinary way: one anchor (the window-creation
call), one trace back to a literal write, one check that nothing else writes a conflicting
value.

## The tick rate: the trace works, but the destination doesn't confirm anything

The same approach applied to "is there a fixed simulation tick rate" traced cleanly through
several real layers and then ran out of unambiguous signal:

1. `WinMain` (`FUN_0041eef0`)'s message loop calls a function pointer once per iteration
   whenever there's no window message to process — the classic "idle work" slot in a
   `PeekMessage`-based loop.
2. Once gameplay starts, that pointer is `FUN_00421de0`, which immediately calls
   `FUN_004312c0`.
3. `FUN_004312c0` calls `timeGetTime()` and passes the real elapsed milliseconds, plus a
   running frame counter, into a state-machine table (`PTR_PTR_0044e27c`) — a sequence of
   `(table, counter, elapsed_ms)` callbacks, each returning nonzero when it's done and the
   table pointer should advance to the next entry.

That's as far as this trace goes usefully. What it *doesn't* find is just as informative as
what it does: no `Sleep()` call, no frame-rate cap, and no fixed-size time-accumulator
pattern anywhere in this chain. The loop's only wait at all is a conditional `WaitMessage()`
gated on the window being in the background. Read at face value, that's evidence *against* a
classic fixed-Hz tick (the kind where the game accumulates real time and steps physics in
fixed 1/30s chunks, common in this console generation) — it looks more like the game just
runs every idle slice it gets, handing real elapsed time downstream, and lets vsync/redraw
pace the frame rate.

But "the trace didn't find a cap in the functions checked so far" isn't the same as
"confirmed uncapped" — the actual vehicle/physics update is one specific entry in that
`PTR_PTR_0044e27c` table, not yet identified among what's presumably several entries (title
screen, menu, in-game). It's entirely possible *that* function internally quantizes the
elapsed-time parameter into fixed steps even though nothing upstream of it does. Calling this
"solved: uncapped" without checking that function directly would be exactly the kind of
guess-dressed-as-finding that [document 13](13-worked-example-reticle-not-swatch.md) just
got burned by doing.

## Why this one stays open

This is being recorded as a **partial finding, not a completed one** — on purpose. The value
here isn't "the tick rate is X"; it's that the next person to pick this up doesn't have to
redo the WinMain trace. `docs/PORTING_PLAN.md` section 1.9 states exactly where the trail
currently ends (`PTR_PTR_0044e27c`) and exactly what the next step is (dump its entries, find
the in-game one, check whether it quantizes time). That's a concrete, boundedly-sized next
action, not a vague "investigate further."

## The lesson

Two backlog items that sound like the same kind of question can have very different shapes
once you're inside them. One resolves in a single trace to a literal constant; the other
resolves the *architecture* (there's a real-time-driven state-machine dispatch, not a
frame-count-driven one) without resolving the *specific number* the question asked for.
Writing down "here's exactly how far the trace got and why it stopped" is worth exactly as
much as writing down a clean answer — arguably more, since a future attempt at this doesn't
have to re-discover that `FUN_004312c0` is the right layer to have stopped at.

## Postscript: the next hop, taken — and it's the wrong system, not the wrong function

Immediately after this document was first written, the "next hop" it names — dump
`PTR_PTR_0044e27c`'s table entries, find the in-game one — was actually taken. All three
functions that ever write that pointer (`FUN_00431320`, `FUN_00431340`, `FUN_00431370`) were
traced to their fixed table addresses, and `DumpFunctionTable.java` dumped the raw contents
of each. Every single entry, across all three tables, resolves to the same small family of
functions (`FUN_00430da0`, `FUN_00430e20`, `FUN_00430fb0`, `FUN_00431120`, `FUN_00430b10`),
called with bitmap-filename string pointers and millisecond duration triples like `500`,
`1000`, `2500` — unmistakably fade-in/hold/fade-out timings for a slideshow, not physics
parameters. `FUN_00430b10` was already known (from the `timeGetTime`-caller trace in this
same document) to reference `TITLE_BanBL.bmp` and `TITLE_Win1.stm` by name. Put together:
**the whole `PTR_PTR_0044e27c` machinery is the boot-time publisher/title logo slideshow —
real, correctly traced, but the wrong system entirely, not gameplay.**

This is a different flavour of dead end than [document 10](10-worked-example-target-respawn.md)'s
`FUN_0042c4d0` — that one was the wrong *function* reached by a reasonable-looking call
graph edge; this is the right function, faithfully traced, that just turns out to belong to a
part of the game (the splash screens) nobody was asking about. The tell, in hindsight, was
sitting in the earlier trace the whole time: `FUN_00430b10` was already known to touch
`TITLE_*` bitmap strings before this postscript's dump even ran. Recognizing that as a red
flag *before* spending a dump-and-decompile pass on it would have been faster — a reminder
that a function's own already-known strings are a cheap sanity check worth applying before
extending a trace, not just after.

One genuinely useful negative result did fall out of the same pass: `FindSymbol.java SetTimer`
returns zero matches anywhere in `RFIRE.BIN`, so a `WM_TIMER`-driven fixed tick is now ruled
out too, on top of the earlier no-`Sleep()` result. Two of the three classic Win32
fixed-interval mechanisms are eliminated; the remaining candidate — a blocking
`IDirectDrawSurface::Flip` call pacing the loop on vsync — is a COM vtable call, not a named
import, so finding it needs the same technique this document's own section 1.9 used to
identify `Lock()` (a literal vtable-offset call site, not a symbol lookup). Left there,
narrower and more specific than before, rather than chased further this session.

**Next:** back to [document 7](07-next-steps.md) for the current backlog.
