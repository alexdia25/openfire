# Tracing cheat sheet: how to read a function in RFIRE.BIN

*Deliberately unnumbered, like [NEXT_STEPS.md](NEXT_STEPS.md): a reference edited in place. The numbered documents
are stories; this is the lookup table you keep open while reading them.* [Document 3](03-ghidra-workflow.md) gives
the general recipe; this page is the day-to-day version for the game-logic documents (45 onward), where the
question is "what does this function do to a game object".

## 1. The loop, in five moves

1. **Pick one visible behaviour** you want the port to match ("the MSV's canisters change as it fires").
2. **Find a code address that is involved.** Usually one of: a pointer stored in a data table (a descriptor, a
   record), a constant you already know (a cel number like `457` = `0x1c9`), or a field you know is read.
3. **Read that function.** Decompile it; if Ghidra will not (see section 4), read the disassembly.
4. **Translate each line into a field name** using the maps in section 2, and write the translation down in the
   document *next to the quoted code*, so a reader can redo it.
5. **Check it against something observable** (a value in the data, a screenshot, a scripted run), and say which
   parts are traced and which are guesses.

## 2. The objects you keep meeting

Everything is a `dword` (4 bytes) at an offset; offsets below are hex, in bytes.

| Name | What it is | Fields seen so far |
|---|---|---|
| **object** (`obj`) | one live thing (vehicle, shell, flag) | `+0x10` team/player index, `+0x14` -> its class table (first dword = class number, 1 = vehicle), `+0x40/+0x44/+0x48` x/y/z position, `+0x4c` heading, `+0x54` speed, `+0x60` -> the player's *state* |
| **state** | per-player block at `0x458100 + player*0x140` | `+8` input flags, `+0x4c` "hit until" tick, `+0x50` gun elevation, `+0x58` weapon counter, `+0x70` in water, `+0x80` water immersion, `+0x84` engine |
| **record** | per-vehicle-type constants at `0x4456b8 + type*0x2e8` | speed, armour (`+0x24`), hit points (`+0x28`), fuel (`+0x210`), weapon slots |
| **descriptor** | how a thing is drawn | `+0` draw callback, `+0x24` init callback, `+0x2c` corner count, `+0x30` corners, `+0x34` part count, `+0x38` parts |
| **part** (8 dwords) | one textured quad | cel, flags (bit 3 = add the team variant), 4 corner indices |
| **draw object** | the per-frame copy the drawer works on | `+8` variant added to a flag-8 part's cel, `+0x1c` heading, `+0x2c` -> the object |

Numbers: positions and speeds are **16.16 fixed point** (divide by 65536; a game tile is 32 units). Headings are
22-bit angles (`0x400000` = 360 degrees, 64 steps of `0x10000`). A tick is 16 ms. `0x480d2c` is the frame's dt,
`0x480d38` the clock in ticks.

## 3. Reading x86 the way we do

| You see | It means |
|---|---|
| `MOV EAX,dword ptr [ESI + 0x40]` | `EAX = field 0x40 of the thing ESI points at` (a read) |
| `MOV dword ptr [ESI + 0x58],EAX` | write that field |
| `MOV [0x0043fb38],EAX` | write a *global*; here the cel of part 10 of the Jeep, because `0x43f9f8 + 10*0x20 = 0x43fb38` (the descriptor's parts start at `0x43f9f8`, 0x20 bytes each) |
| `AND EAX,0x30000` then `SHR EAX,0x10` | take bits 16-17 = "the integer part of a 16.16 number, modulo 4" |
| `ADD EAX,0x1c9` | `+ 457` (hex to decimal every time: `0x1c9` = 457) |
| `CMP dword ptr [EDX],0x6` / `JZ` | "if class is 6, jump" |
| `SAR EDX,0xd` | divide by 8192 (arithmetic shift) |
| `CALL 0x00410b70` | `FUN_00410b70`, which is a fixed-point multiply we treat as a black box |
| arguments | pushed right-to-left; the first `[EBP + 0x8]` is argument 1, `[EBP + 0xc]` argument 2 |

The decompiler's `*(int *)(param_1 + 0x2c)` is the same thing as `[ESI + 0x2c]`. When the two disagree with what
the game does, trust the disassembly.

## 4. Tools, and which question each answers

Run from the repo root (the Ghidra project stays outside the repo, and is opened read-only):

```bash
export JAVA_HOME=/c/Users/Alex/Documents/code/tools/jdk-21.0.12.1+1
/c/Users/Alex/Documents/code/tools/ghidra_12.1.3_PUBLIC/support/analyzeHeadless.bat \
  C:/Users/Alex/Documents/code/tools/ghidra_projects returnfire -process RFIRE.BIN -noanalysis -readOnly \
  -scriptPath $PWD/tools/ghidra_scripts -postScript <Script>.java <args>
```

| Question | Script and example |
|---|---|
| What is stored at this address? | `DumpDwords.java 0x43fd78 16` (a descriptor: draw callback first) |
| Who uses this value or pointer? | `FindPointerRefsMulti.java 43fb38 43fb18` (addresses without `0x`; prints code addresses that mention them, plus the enclosing function) |
| Who *writes* a field of an object? | `FindDispOps.java 0x40b000 0x410800 "+ 0x58],"` (every instruction in the range containing the text; the trailing `],` limits it to writes) |
| What does this function do? | `DecompileMany.java 0x0040c190 0x0040c390` |
| Decompiler finds nothing here | `DisasmForce.java 0x402d20 0x402dc0` (a callback reachable only through a data pointer: Ghidra never marked it as code; prints the instructions) |
| Raw instructions of a known function | `DumpDisasm.java 0x0040bb80 0x0040bd20` |

Things that trip people up:

- **No cross-references.** The project was imported with `-noanalysis`, so `FindDataXrefs` finds nothing for data
  reached through code. Use `FindPointerRefsMulti` (scans raw bytes) instead.
- **"Function creation failed" / empty output** means the address is inside a function or was never code. Use
  `DisasmForce`, and start at the real first instruction (`PUSH EBP`).
- **Field names are per object type.** `+0x40` is a position on a vehicle but a sound value on another object;
  always check what the pointer in `ESI` is before naming a field (find the caller and see what it passes).

## 5. A finding is written down like this

In each numbered document, for every claim: *(a)* the address, *(b)* the quoted instruction or decompiled line,
*(c)* the translation in plain words, *(d)* what confirms it. If any of these is missing, the claim is marked
**untraced** or **guess**, in the document, in the code comment and in the registry.
