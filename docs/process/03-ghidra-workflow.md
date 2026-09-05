# 3. The Ghidra workflow

`.RFM` and `ART.CAR` are not renamed standard formats — they're game-specific, and the only
ground truth for what their bytes mean is the code in `RFIRE.BIN` that reads them. This
document is the general recipe used to get that ground truth out. [Document 4](04-worked-example-rfm-format.md)
runs this recipe in full on a real format; read this one first for the shape of it.

## The recipe

1. **Anchor on something findable.** A string the loader must compare against (a file
   extension, a magic number, a chunk tag), or a Windows API call the loader must make to do
   its job (`CreateFileA`, `ReadFile`, `DirectDrawCreate`...). You can't start from nothing;
   you start from the one thing you're already confident must exist in the binary somewhere.
2. **Find cross-references to that anchor.** Every place in the code that touches it.
3. **Decompile the containing function(s).** Ghidra's decompiler turns x86 disassembly back
   into C-like pseudocode. It's not always pretty, but it's vastly faster to read than raw
   assembly, and it's real code, not a guess.
4. **Read the decompiled C and form a hypothesis** about what the bytes mean.
5. **Verify the hypothesis against every real data file**, not one or two samples. This step
   is non-negotiable — see [document 6](06-verification-philosophy.md) for why, in painful
   detail.
6. **Write the converter, run it against every file, and look at the output** — ideally by
   rendering it, not just checking that nothing crashed.
7. **Write the finding down** (in `docs/PORTING_PLAN.md`) before moving on, so it survives
   a context reset.

Steps 2-4 usually repeat several times — the function you land on calls another function
that's the *real* one you want, or references a table you need to dump and decode
separately. That's normal; each hop is another small script run, not a fresh investigation.

## The script toolkit

Every script below lives in `tools/ghidra_scripts/` and is a small, single-purpose Java
file — Ghidra compiles them on the fly, no build step. None of them touch or modify the
program; they're all read-only queries. When an existing script didn't quite answer the
question, the answer was almost always to write a new ~40-line script rather than force an
existing one to do something it wasn't shaped for — several of these (`FindDataXrefs`,
`FindImportCallers`, `FindSymbol`, `DecompileMany`) got written mid-investigation, exactly
when the existing ones ran out of reach. That's a normal and cheap thing to do; don't
hesitate to add a new one.

| Script | What it answers |
|---|---|
| `FindRfmStrings.java` | "What Return Fire format strings exist, and what code touches them?" Good first move in any fresh investigation. |
| `FindBytes.java <hex>` | "Where does this exact byte sequence occur, and what references it?" A raw memory scan — works even when the bytes aren't recognized as code, data, or a string. |
| `FindConstant.java <hex32>` | Like `FindBytes`, but only looks at *scalar instruction operands* (immediates). Faster when it works, but misses anything loaded from memory. See the WRL magic example below for what happens when it doesn't. |
| `FindSymbol.java <substr>` | Case-insensitive search over every symbol — functions, labels, data — not just functions. The one to reach for when hunting a Win32 API by name; see below for why. |
| `FindImportCallers.java <substr>` | Every function/import whose name contains the substring, plus every caller, decompiled. |
| `FindDataXrefs.java <hexAddr>` | Every place in the code that reads or writes a given *global variable* address — for tracing a queue pointer or lookup-table base forward through the whole program, not just one call graph. |
| `FindCallers.java <hexAddr>` | Every caller of a given function, decompiled. |
| `DecompileOne.java <hexAddr>` | One function, plus its immediate callers and callees, all decompiled. The main workhorse for walking a call graph one hop at a time. |
| `DecompileMany.java <addr> [addr...]` | A flat list of functions decompiled with no expansion — for surveying a dozen candidates at once without an exponential-size log. |
| `ForceDecompile.java <hexAddr>` | Disassemble + force-create a function at an address Ghidra's static analysis didn't recognize as one. Needed for anything only reachable through an indirect/computed call (a function-pointer table), since static analysis can't always follow those on its own. |
| `DumpStringAt.java <hexAddr> [n]` | Raw hex + ASCII dump of `n` bytes at an address — for reading a small table or string constant directly. |
| `DumpFunctionTable.java <hexAddr> <count>` | Reads `count` little-endian pointers starting at an address and decompiles whichever land on a recognized function — for jump/dispatch tables. |

## A real example of the recipe hitting a dead end and recovering

Cracking `.RFM` started from the magic bytes `"WRL\0"` at offset 0 of every level file. The
first instinct was `FindConstant.java`, since a 4-byte magic often gets compared as a single
32-bit immediate in compiled code:

```powershell
-postScript FindConstant.java 004C5257   # "WRL\0" packed little-endian as a 32-bit int
```

**Zero hits.** Not "the magic isn't checked" — it clearly is, every level file starts with
it and the loader clearly validates files somehow — but a scalar-operand scan only catches
values baked in as instruction immediates. If the compiler instead loaded the constant from
a data location and compared byte-by-byte (which turned out to be exactly what happened —
the loader used `lstrcmpiA` against the string), a scalar scan will never see it.

Switching to `FindBytes.java`, a raw memory scan that doesn't care whether Ghidra thinks the
bytes are code, data, or nothing, found it immediately (note this one takes the bytes in
plain file order, not packed as an integer, so it's `57524C00` not `004C5257`):

```powershell
-postScript FindBytes.java 57524C00      # "WRL\0" as literal file-order bytes
```

One hit, with 8 cross-references straight to the level-loading function. That one dead end is why `FindBytes.java` exists
and is listed above as the default choice for magic-number hunting — `FindConstant.java` is
kept because it's occasionally faster when it does work, but it's the second thing to try,
not the first, now that we know its blind spot.

A related version of the same lesson showed up looking for a specific Win32 API
(`StretchDIBits`) by name: `FindImportCallers.java` found nothing, because a Win32 function
called only through an Import Address Table slot doesn't show up as a `Function` in
Ghidra's function manager at all — only as a `Data`/`Label` symbol for the IAT slot itself.
`FindSymbol.java`, which searches *all* symbol types, found `PTR_StretchDIBits_0048e53c`
immediately; `FindDataXrefs.java` on that address then found every real call site. Same
shape of lesson: when the "obvious" tool finds nothing, that's a signal to check what kind
of symbol you're actually looking for, not a signal that the thing doesn't exist.

**Next:** [Worked example: the `.RFM` map format, start to finish](04-worked-example-rfm-format.md).
