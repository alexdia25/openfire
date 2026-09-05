# 11. Worked example: confirming a dead end fast by rereading work already on hand

The smallest entry in this series, and worth including for exactly that reason: this one
needed **zero new Ghidra invocations**. The answer was already sitting in a decompile log
from an earlier investigation, unread for that particular question until now.

## The question

[Document 4](04-worked-example-rfm-format.md) left the `EDTN` chunk tag on the backlog: a
4-byte payload (two identical `u16` values, e.g. `27 03 27 03`) present in every one of the
204 real `.rfm` files, never decoded. Low priority, since `tools/convert_rfm.py` already
round-trips it opaquely without understanding it — but still an open question.

## Realizing the anchor already existed

The level loader, `FUN_00414130`, had already been fully decompiled — repeatedly, across
several earlier investigations in this project, each one re-running
`DecompileOne.java 00414130` rather than re-deriving it from scratch (that's the entire
point of writing findings down as they land: the next investigation gets to start from the
last one's endpoint). A copy of that decompile was still sitting in this session's own
scratch directory from tracing the runtime tile buffer for [document 8](08-worked-example-art-id-mapping.md).
Grepping it directly, no new Ghidra call needed:

```
grep -n "0044882c\|00448824\|0044881c" loader.log
```

Three hits, each a chunk-tag string comparison inside the loader's chunk-walking loop —
and only three, in the entire function. `DumpStringAt.java` on each of those three addresses
confirmed exactly which tags they are:

```
@ 0044881c: VHCL
@ 00448824: NAME
@ 0044882c: LEVL
```

That's the full list. There is no fourth comparison anywhere in `FUN_00414130` for `EDTN`.

## What that means

The loader's chunk-walking logic (documented in full in
[document 4](04-worked-example-rfm-format.md)) is generic: it reads a tag and a record
length, and if the tag matches one of the three it's looking for, does something with the
payload; otherwise it just adds the record length to its position and moves to the next
chunk. `EDTN` doesn't match any of the three checks, so it falls straight into that generic
skip path. **The game itself never reads the `EDTN` chunk's contents, under any
circumstances.** Not "unidentified" — confirmed unused.

This closes the question in a stronger way than decoding the field's meaning would have.
Whatever `EDTN` is for — a build timestamp, a checksum, a level-editor version stamp — it's
information the *level editor* cared about and the *game* discarded. A faithful port doesn't
need to understand it any more than `RFIRE.BIN` does. Round-tripping it as an opaque blob,
which `tools/convert_rfm.py` already did before this question was even asked, turns out to
be exactly the behaviorally correct choice, not a shortcut taken in the absence of a real
answer.

## The lesson

Before reaching for a new search, a new anchor, or a new decompile: **check whether the
answer is already sitting in something this project has already produced.** Every finding
in this project gets written down specifically so this is possible — a `.log` file from a
different investigation, a paragraph in `docs/PORTING_PLAN.md`, a comment in a converter.
This one cost a `grep` and a dump of 24 bytes. Not every question needs a fresh
`FindDataXrefs.java` sweep to close.

**Next:** back to [document 7](07-next-steps.md) for the current backlog.
