# 26. Worked example: reading a branch to the end instead of its summary

[Document 24](24-worked-example-capture-the-flag-lead.md) left the flag lead at "a strong,
multi-source hypothesis, not yet a closed proof" — a real debug string, real two-team flag art,
and a real code link into `FUN_00432710`, but the description of *what actually gates the
flag spawn* was a paraphrase: "reads a value, and uses the result to decide whether destroying
the active target falls through into ordinary replacement, or into spawning a flag object
instead." That's true, but it's a summary of a branch, not the branch itself — and this session
showed the difference matters.

## Chasing the "not yet found" list one item at a time

Document 24 explicitly listed what wasn't yet found: where `DAT_00442b00` — the debug menu's
"Flag in first building" value — gets *set*, not just read. The obvious next move is exactly
what document 3's recipe always says: find every reference, not just the one already known.
`FindDataXrefs.java 00442b00` this time turned up **three** references, not one:

1. `FUN_00432710` — the already-known read (the destruction handler).
2. `FUN_004065c0` — the debug-menu renderer itself, reading its own live value to print it.
3. A data-only reference at `00442b78`, "(no fn)" — not code at all, just the debug menu's
   own static table declaring where this item's live-value pointer points. Expected, not new.

**No write site exists anywhere in the compiled code.** That's the actual answer to document
24's open question, and it's a clean one: dumping the raw bytes at `00442b00` shows `00 00 00
00`, and the debug menu's generic widget code (visible in `FUN_004065c0`'s own decompile) does
modify a live value *through an indirect pointer* when a developer navigates that menu item —
but that's the only mechanism that ever touches it, and it only runs while the hidden menu is
open. **In every real, non-debug game, this value is always 0.**

## The moment that mattered: reading past the summary

That finding could have been a dead end — "it's a debug-only toggle, therefore not part of real
gameplay" is a tempting, wrong conclusion to stop at. The fix was to actually read what happens
when the value *is* 0 (the only case that ever occurs in real play), instead of trusting the
earlier "gates whether X or Y" summary. The full decompile of `FUN_00432710` makes the real
rule exact:

```c
bVar6 = DAT_00442b00 == 0;                          // always true in real play
*(int *)(&DAT_0048ca20 + uVar5 * 4) = iVar1 + -1;    // decrement budget regardless
if ((bVar6) && ((-1 < iVar1 + -1 || (*(uint **)(&DAT_0045ae50 + uVar5 * 4) != param_2)))) {
    if (*(uint **)(&DAT_0045ae50 + uVar5 * 4) != param_2) goto LAB_0043286a;  // wasn't the active target -- nothing to do
    iVar1 = FUN_00432600(uVar5);                     // try to activate a replacement
    if (iVar1 != 0) goto LAB_0043286a;                // succeeded -- done
}
// falls through here when: bVar6 is false (never, in real play), OR the destroyed tile
// WAS the active target but budget was already exhausted, OR FUN_00432600 found no
// intact candidate left to activate
piVar2 = FUN_0042c290(0x44e3c0, uVar5, ...);          // spawn the flag object
```

Read in full, the branch says something much more specific than "gates whether": **the flag
object spawns exactly when the pool's active target is destroyed and no replacement is
available** — budget exhausted, or no intact candidate left. Not "sometimes, depending on a
mysterious debug value." A precise, mechanical rule, fully determined by state this project
already tracks.

## The payoff: zero new code needed to check it

`game/target_pool.gd`'s `TargetPool.destroy_active()` (Phase 4 step 5,
[document 22](22-worked-example-weapons-and-targets.md)) was written directly from this same
function months before this session — and its return value already means exactly the right
thing:

```gdscript
func destroy_active() -> bool:
    ...
    budget -= 1
    if budget <= 0:
        return false          # <- exactly the "budget exhausted" fallthrough
    ...
    if remaining.is_empty():
        return false          # <- exactly the "no intact candidate" fallthrough
    active_index = remaining[randi() % remaining.size()]
    return true
```

`destroy_active()` returning `false` *is* the flag-spawn condition, unmodified. This is the
same lesson document 22 already drew from this exact algorithm — a fully-traced mechanism
translates directly into code, no guessing needed — playing out a second time on a different
branch of the same function.

## Making it real: `FlagMarker`

New `game/flag_marker.gd` uses the confirmed `marker.capture_flag.<team>` art
([document 24](24-worked-example-capture-the-flag-lead.md)) and gets spawned from
`terrain_view.gd`'s existing `_check_target_hits()` at the exact point `destroy_active()`
returns `false`. Verified with a real-scene integration test against `RFMAP001`, whose pool
"b" has exactly one candidate and a budget of 0 — the minimal real-data case, where the very
first hit exhausts it: confirms exactly one `FlagMarker` spawns, at the destroyed target's own
position, with real sprite frames loaded from the pack, and that firing at the same (now empty)
spot again doesn't spawn a second one.

## What's honestly still true

This closes the *spawn trigger* precisely — a real, verified answer, not a hypothesis anymore.
It does not move the rest of document 24's "explicitly not yet found" list: nothing carries the
flag, there's no home-base check, and nothing declares a match won or lost. Which physical pool
belongs to which team's flag colour is also still an open, arbitrary guess
(`POOL_FLAG_COLOURS`, flagged in code). Phase 4 step 7 is not done; one precise piece of it is.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
