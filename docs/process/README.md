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
7. [**Next steps**](07-next-steps.md) — the current open-questions backlog, reframed as
   "here's how you'd go about this one yourself," with pointers back into the workflow doc.

## The one rule that overrides everything else here

**Never commit extracted game assets or decompiled code to this repository.** Every
converter writes its output to `/build/`, which is gitignored. Every Ghidra project lives
outside this repo entirely (`C:\Users\Alex\Documents\code\tools\ghidra_projects\`), because
a Ghidra project file *is* a disassembled/decompiled copy of the copyrighted binary. What's
committed here is original analysis and original code: which byte means what, and the
converter that acts on that knowledge — never the game's own bytes or code. See
`docs/PORTING_PLAN.md` section 0 for the full legal rationale.

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
