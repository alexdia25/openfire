# 10. Worked example: what the `>>1` computation actually does

Not every investigation in this project has been a saga. This one — one of the smaller
items on [document 7](07-next-steps.md)'s backlog — took two `FindDataXrefs.java` calls and
two decompiles to resolve, which is worth showing precisely because it demonstrates the same
recipe scales down, not just up.

## The starting point

[Document 4](04-worked-example-rfm-format.md) had already found and named the two candidate
position pools (`0xB4`/`0xDC` tile values) and the level loader's random-commit logic, and
left one loose end: right after picking one random candidate per pool, the loader computes
`pool_count >> 1` and stores it somewhere, un-investigated. The plan's own guess at the time
was "possibly a win-condition threshold." A guess recorded as a guess, not asserted as fact
— exactly what [document 6](06-verification-philosophy.md)'s rule 5 asks for.

## Following it forward

The anchor already existed (the two globals the loader writes those halved counts into,
`DAT_0048ca20` and `DAT_0048ca24`) — no new string or API search needed, just
`FindDataXrefs.java 0048ca20`. It came back with only **3 references total**: the loader
(already known) and 2 inside a single other function, `FUN_00432710`. A 3-reference result
is a strong signal on its own — whatever this value does, it's used in exactly one other
place, so that's the whole story.

Reading `FUN_00432710`:

```c
uVar5 = (*param_2 & 0xc000) >> 0xe;              /* pool index from tile bits 14-15 */
...
iVar1 = *(int *)(&DAT_0048ca20 + uVar5 * 4);      /* this pool's remaining budget */
*(int *)(&DAT_0048ca20 + uVar5 * 4) = iVar1 + -1; /* decrement it */
...
/* if this was the pool's tracked active target, call FUN_00432600(uVar5) to replace it */
```

Two things fall out immediately. First, `param_2` here is a tile pointer being handled by
what's clearly an object-destruction path — this function runs when something gets removed
from play. Second, `(tile & 0xc000) >> 14` reads bits 14-15 of the tile's runtime value —
which section 1.5 had already flagged as a dumped-but-unchased field, guessed to be
"orientation-ish." Seeing it used as a small array index here (0 or 1, selecting between two
adjacent 4-byte globals `DAT_0048ca20`/`DAT_0048ca24`) rules that guess out on the spot: it's
a pool-membership tag, not orientation. **A wrong guess sitting in the docs long enough to
get checked against real code is exactly what those guesses are for.**

## One more hop

`FUN_00432600(pool)` (the replacement call) was worth reading in full, decompiling it
directly by address since it was already named from the caller. It scans the pool's own
candidate array (confirmed by a quick decompile of `FUN_00413db0`, the function that
originally built that array, to nail down exactly which global belongs to which pool letter
— `pool_index==0`/tile `0xB4` uses `DAT_0045ae70`/`DAT_0045ae28`, `pool_index==1`/tile `0xDC`
uses `DAT_0045b270`/`DAT_0045ae2c`) for any candidate still showing an "intact" state, and if
any remain, randomly activates one as the new target.

## What this adds up to

Not "destroy half the pool's targets simultaneously to win" (the original guess). Instead:
**each pool is a rotating single-target spawner** — exactly one destructible target is live
per pool at a time, and destroying it immediately activates a replacement from the pool's
remaining candidates, up to a total budget of half the pool's candidate count. That's a
materially different — and, reading it, more obviously correct — description of the
"bases keep reappearing somewhere else" feel the original game is known for.

## What's still open, and why that's an honest place to stop

The full cross-reference list for both budget globals is exactly 3 sites, all now read.
Nothing anywhere in the binary reads *both* budgets together to declare a match won or lost.
That means the actual mission-complete condition — if it exists and is driven by these
counters at all — is implemented somewhere this investigation didn't reach. Rather than
guess further, this was recorded as the honest boundary of what was actually traced: the
replacement mechanism is solved with the same confidence as every other entry in this
document series; the win condition is a clearly-scoped next step, not something papered
over. See [document 7](07-next-steps.md) for it as a next action.

## Postscript: chasing the next hop, and hitting a real dead end

The obvious next step was named above: `FUN_0042c4d0`, called right as a pool's tracking
gets cleared once its budget runs out. Decompiling it directly settled the question in one
step — but not the way the lead suggested:

```c
void __cdecl FUN_0042c4d0(int param_1)
{
  if ((*(uint *)(param_1 + 0xc) & 0x80) == 0) {
    *(uint *)(param_1 + 0xc) = *(uint *)(param_1 + 0xc) | 0x80;
    *(int *)(param_1 + 0x38) = DAT_0046a7b0;
    DAT_0046a7b0 = param_1;
  }
}
```

That's a generic "mark this object dead (flag bit `0x80`) and link it into a free list" —
nothing about pools, targets, or match state at all. Its caller list confirms it: over 35
call sites scattered across the entire binary, covering what look like vehicles,
projectiles, and ordinary objects generally. It's called from `FUN_00432710` for the same
reason it's called everywhere else — some bookkeeping object is done being used — not as a
special win-condition hook.

This is worth recording precisely *because* it's a disproof, not a success — per
[document 6](06-verification-philosophy.md)'s rule 5, a wrong lead is worth keeping on the
record with what actually happened to it, so nobody re-spends the same effort re-checking
it. The trail from here runs into a large, general AI-targeting/combat module
(`FUN_00432d00`, `FUN_00432d80`, `FUN_00432e40` and neighbors — found by the same
`FindDataXrefs.java` sweep, this time on the per-pool "active target" pointer array) with no
obvious "declare victory" anchor visible in it. Rather than opening an unbounded
investigation into an unrelated subsystem chasing a hunch, this is where the trail was left
— honestly marked as a checked-and-ruled-out lead, not a solved question. See
[document 7](07-next-steps.md) for the current state of this open item.

**Next:** [Worked example: confirming a dead end fast by rereading work already on hand](11-worked-example-edtn-chunk.md).
