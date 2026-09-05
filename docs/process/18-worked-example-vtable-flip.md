# 18. Worked example: finding a COM vtable call with no symbol to search for

[Document 15](15-worked-example-resolution-and-tick-rate.md) traced the fixed-sim-tick-rate
question as far as it could go with the tools on hand and landed on a specific, narrow next
step: the two classic Win32 pacing mechanisms (`Sleep()`, `SetTimer`/`WM_TIMER`) were both
ruled out by name, leaving one candidate — a blocking `IDirectDrawSurface::Flip` call pacing
the loop on vsync. The problem was that every tool this project had built so far
(`FindSymbol.java`, `FindDataXrefs.java`, `FindCallers.java`) finds things by **name or
address** — an imported function's symbol, a global's address, a function's entry point.
`Flip` has none of those. It's a method call through a COM object's vtable, which in the
decompiled C looks like `(**(code **)(*someObject + OFFSET))(someObject, ...)` — no `Flip`
string anywhere in the binary, no import table entry, nothing to search for by name.

## The technique: search by vtable slot number instead

`IDirectDrawSurface`'s methods have a fixed, publicly documented order (it's a COM
interface — `IUnknown`'s `QueryInterface`/`AddRef`/`Release` first, then the interface's own
methods in declaration order). Counting down the DirectDraw 1 vtable — the version that
matches this game's imports (`DirectDrawCreate` only, never `DirectDrawCreateEx`, so this is
`IDirectDrawSurface`, not the later `IDirectDrawSurface7`) — `Flip` is the 9th
interface-specific method, slot index 11 overall, which on 32-bit x86 (4-byte pointers) is
byte offset `11 * 4 = 0x2c` into the vtable.

That turns "find the `Flip` call" into "find every `CALL [reg + 0x2c]` instruction in the
binary" — a mechanical scan, not a name lookup. `tools/ghidra_scripts/FindVtableCall.java`
(new this session) does exactly that: it walks every instruction in the program, keeps the
ones whose mnemonic is `CALL` and whose text representation contains the target
displacement inside a memory operand, and decompiles each unique containing function so the
call can be read in its real context. It takes the offset as a hex argument, so the same
script works for any vtable slot, not just this one.

## Running it

```
$env:JAVA_HOME = "C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
& "...\analyzeHeadless.bat" "...\ghidra_projects" returnfire -process RFIRE.BIN -noanalysis `
  -scriptPath "...\tools\ghidra_scripts" -postScript FindVtableCall.java 2c
```

Two functions matched. One was a false-positive-shaped hit — a `CALL [reg + 0x2c]` that
turned out to belong to an unrelated COM interface used for something else entirely. The
real one, `FUN_004300e0`, was unambiguous the moment it was decompiled:

```c
piVar2 = (int *)(**(code **)(*DAT_00448d28 + 0x2c))(DAT_00448d28,0,1);
if (piVar2 == (int *)0x887601c2) {       // DDERR_SURFACELOST
    FUN_00420ff0();                       // Restore()
    piVar2 = (int *)(**(code **)(*DAT_00448d28 + 0x2c))(DAT_00448d28,0,1);
}
```

`Flip(LPDIRECTDRAWSURFACE lpSurfaceTargetOverride, DWORD dwFlags)` called as
`Flip(NULL, 1)` — `1` is `DDFLIP_WAIT`. The retry-after-`DDERR_SURFACELOST` pattern is the
giveaway: that error code and that recovery idiom (call `Restore()`, then retry the exact
same call) is a DirectDraw cliché that only makes sense for a call operating on a surface
that can be "lost" by an alt-tab or mode change — `Flip` fits; a `Blt`-family call to a
private buffer wouldn't need it. The same function has two sibling branches at offsets
`0x14` and `0x1c` on the same `DAT_00448d28` surface pointer, and both match `Blt` and
`BltFast`'s parameter shapes exactly — three independent confirmations of the vtable-offset
table in one function, for free.

## Closing the loop: is this actually called every frame?

Finding the call isn't enough — document 15's question was about the *main loop's* pacing,
so the call needs to be reached from there. `FindCallers.java` on `FUN_004300e0` turns up
several callers, including `FUN_004312c0` — already a known quantity, because document 15
traced it directly from `WinMain`'s idle-loop dispatch:

```c
void FUN_004312c0(void) {
  if (DAT_0044e0d0 != 0) {
    if (*(int *)PTR_PTR_0044e27c != 0) { /* boot-slideshow state machine, doc 15's postscript */ }
    FUN_004300e0(0);   // <-- unconditional, every iteration
  }
}
```

No gate, no frame-skip counter — every time the idle loop runs (which is every time there's
no window message to process), it presents. That's the missing link: the present call is
reached from exactly the place the pacing question is about.

## The answer

`FUN_004300e0` branches on a display-mode global (`DAT_00448d5c`, the same one document 15's
resolution finding already tied to `PS240.RFA`/`PS480.RFA`): **fullscreen modes call the
blocking `Flip(NULL, DDFLIP_WAIT)`**, which — under real exclusive-mode DirectDraw hardware
page-flipping — does not return until the next vertical retrace. **Windowed modes instead
call `Blt`/`BltFast`** into a rect computed from `GetClientRect`/`ClientToScreen`, with no
wait flag at all.

So: there is no fixed-Hz simulation tick anywhere in this binary, and there never was one to
find — document 15's instinct to leave the question open rather than force an answer was
the right call. What actually paces the game, when it paces at all, is a side effect of how
a *frame gets displayed*, not a counted interval: fullscreen play is implicitly capped to
whatever the display's real refresh rate is (60Hz on a stock 1996 CRT — not a portable
constant worth hardcoding), and windowed play isn't rate-limited by this mechanism at all,
consistent with everything document 15 already ruled out (no `Sleep()`, no `WM_TIMER`).

## The lesson

Three tools built earlier in this project (`FindSymbol`, `FindDataXrefs`, `FindCallers`) all
assume you have a name or an address to start from. A vtable call has neither — its "identity"
is a small integer (which slot in which interface), and that integer only becomes searchable
once you go get it from public documentation of the interface's layout rather than from
anything inside the binary itself. This is the same shape of move as section 1.6's use of
`trapexit/3doplay` to confirm `CCB_BGND`, or document 17's identification of the 3DO disc via
its public volume-header format — reaching for outside, publicly-documented structure instead
of re-deriving everything from the binary in isolation. The new script itself is
deliberately general (any vtable, any slot, not just `Flip`), so the next COM interface this
project needs to search inside — `IDirectSound`, say, if a lower-level audio question ever
comes up — doesn't need a fourth from-scratch technique.

**Next:** whichever of plan section 4's remaining items gets picked up next — what ends a
match (item 1), team colouring (item 3), or starting the 3DO filesystem-reader work (item 6).
