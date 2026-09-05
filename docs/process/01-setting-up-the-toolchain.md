# 1. Setting up the toolchain

## Why a disassembler at all?

The first few formats (`.SDT`, `.RFA` — see the [next document](02-easy-formats-first.md))
turned out to just be standard formats with renamed extensions. You can crack those with a
hex viewer and some knowledge of RIFF/BMP. But some formats — `.RFM` levels, `ART.CAR`
sprites — have real, game-specific structure: chunk tables, lookup tables, dispatch logic.
Guessing at those from bytes alone hits a wall fast, and a wrong guess can look right for a
while before it quietly breaks (see [document 5](05-worked-example-art-car.md) for exactly
that happening).

Past that wall, the only reliable source of truth is **the actual code that reads the
file** — `RFIRE.BIN`, the real 1996 executable. That means a disassembler/decompiler. We
used [Ghidra](https://ghidra-sre.org/) (free, NSA-developed, actively maintained), not
because it's the only option, but because it has a solid headless scripting API, which
turns out to matter a lot — see the next section.

## What's installed, and where

```
C:\Users\Alex\Documents\code\tools\
  jdk-21.0.12.1+1\          Eclipse Temurin JDK 21 (Ghidra 12.1.3 requires a JDK, not just a JRE)
  ghidra_12.1.3_PUBLIC\     Ghidra itself
  ghidra_projects\          the analysis database — RFIRE.BIN imported, auto-analyzed
```

**None of this is inside the `returnfire-godot` git repo, and none of it ever should be.**
`ghidra_projects\` in particular holds Ghidra's own database for `RFIRE.BIN` — internally
that's a disassembled and partially decompiled copy of the copyrighted game binary. Keeping
it outside the repo isn't just tidiness, it's the same legal boundary the whole project
depends on (see the README's "one rule that overrides everything else").

## Why headless, not the GUI

Ghidra is normally a GUI application — you'd open it, browse the disassembly, right-click
"Decompile", read the pane. **None of that is available to an AI agent driving a terminal.**
There's no way to click a button in a window that isn't there.

Ghidra ships a second interface for exactly this situation: `analyzeHeadless.bat`, a
command-line tool that can import a binary, run auto-analysis, and — critically — run
arbitrary scripts against the analyzed program and print their output to stdout. Every
finding in this project came through that pipe: a script prints decompiled C, or a table
dump, or a list of cross-references, straight to a log file that gets `grep`'d.

One consequence worth knowing up front: **Jython isn't bundled with this Ghidra version**,
only Python3/PyGhidra (which needs extra setup) and plain Java `GhidraScript`s (which Ghidra
compiles on the fly, no build step). Every script in `tools/ghidra_scripts/` is Java for
that reason — see [document 3](03-ghidra-workflow.md) for what's in there.

## The one gotcha: `JAVA_HOME`

Ghidra's own launcher needs `JAVA_HOME` set *before* it can even read its own config file
(`support/launch.properties`, which is where you'd normally point it at a specific JDK).
That's a bootstrapping problem: the config that's supposed to tell Ghidra which Java to use
can't be read until Java is already found.

Two things fix this together:

1. `launch.properties` has `JAVA_HOME_OVERRIDE` set to the JDK path above, for normal use.
2. A small wrapper batch file, in case a shell hasn't picked up a persisted environment
   variable (this happens more than you'd expect — a new terminal session started by an
   automated tool doesn't always inherit user-level environment changes made moments
   earlier):

```bat
REM tools/ghidra_12.1.3_PUBLIC/run_ghidra.bat
@echo off
set "JAVA_HOME=C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
call "%~dp0ghidraRun.bat"
```

For headless scripting specifically, the simplest fix is to just set it inline at the top
of every PowerShell invocation, which is what every command in the rest of these documents
does:

```powershell
$env:JAVA_HOME = "C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
```

## Importing the binary and running auto-analysis

Ghidra needs to import a binary into a "project" once, and run its auto-analysis (function
detection, string discovery, PE import resolution) once, before any script can query it
usefully:

```powershell
$env:JAVA_HOME = "C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
& "C:\Users\Alex\Documents\code\tools\ghidra_12.1.3_PUBLIC\support\analyzeHeadless.bat" `
  "C:\Users\Alex\Documents\code\tools\ghidra_projects" returnfire `
  -import "C:\Users\Alex\Documents\returnfire\RFIRE.BIN"
```

This creates the `returnfire` project and runs full auto-analysis as part of the import (in
this case: 29 seconds, no errors — a good sign; this is a small, unpacked, unobfuscated
1996 binary with intact relocations, about as easy a target as reverse engineering gets).

**Every subsequent invocation uses `-process RFIRE.BIN` instead of `-import`**, to reopen
the already-analyzed project rather than re-importing:

```powershell
$env:JAVA_HOME = "C:\Users\Alex\Documents\code\tools\jdk-21.0.12.1+1"
& "C:\Users\Alex\Documents\code\tools\ghidra_12.1.3_PUBLIC\support\analyzeHeadless.bat" `
  "C:\Users\Alex\Documents\code\tools\ghidra_projects" returnfire `
  -process RFIRE.BIN -noanalysis `
  -scriptPath "C:\Users\Alex\Documents\code\returnfire-godot\tools\ghidra_scripts" `
  -postScript SomeScript.java someArgument
```

`-noanalysis` skips re-running auto-analysis (it's already been done and doesn't need
repeating); `-scriptPath` points at this repo's script directory; `-postScript` names the
script to run, plus its arguments. This four-line shape — set `JAVA_HOME`, then this one
command with a different script and arguments swapped in — is what every example in the
rest of these documents boils down to.

**Next:** [Easy formats first — cracking `.SDT` and `.RFA` without any of this](02-easy-formats-first.md).
