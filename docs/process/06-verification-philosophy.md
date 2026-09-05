# 6. Verification philosophy

Five rules, each one a distillation of a specific real incident from
[document 4](04-worked-example-rfm-format.md) or [document 5](05-worked-example-art-car.md).
These are also recorded, more tersely, as "standing instructions" in
`docs/PORTING_PLAN.md` section 5 — this document is the expanded version, with the incident
each one came from, so the *why* doesn't get lost.

## 1. When a question is visual, render it and look — don't answer it with statistics

The `ART.CAR` transparency question (is palette index 0 always transparent?) had a
statistical heuristic — comparing how often index 0 shows up on a sprite's border versus
its interior — return "inconclusive": 77.8% vs 61.5%, not a clean signal either way. Looking
at the decoded atlas answered it in seconds: sprites sat cleanly isolated on transparent
black. The heuristic wasn't wrong to be inconclusive — these sprites really are mostly empty
space inside their bounding boxes, which is exactly what confused it — but reaching for a
render instead of trying to rescue the statistic was what actually resolved the question.

**Apply this whenever:** you're checking whether a decoded image, mask, or shape looks
correct. If you can render it, render it before you trust a number about it.

## 2. A plausible byte count is not a correctness proof for a codec

The `ART.CAR` packed-cel decoder ([document 5](05-worked-example-art-car.md)) ran to
completion on 92 of 93 cels and consumed a number of bytes within roughly 2x of the
cel's declared size — which sounds like real evidence of a working decoder. It rendered as
noise. **"The decoder didn't crash and used a sane number of bytes" and "the decoder is
correct" are unrelated claims** — the first is necessary but nowhere near sufficient, and
this project shipped a converter with exactly that mistake for a while before catching it.

**Apply this whenever:** you're validating a decoder for a binary format you reverse
engineered rather than looked up in a spec. Render the decoded output, or otherwise
directly inspect its content. A byte-budget check can rule out an obviously broken decoder;
it cannot confirm a correct one.

## 3. Cross-check against every real file, not a sample

The `.SDT` sound files ([document 2](02-easy-formats-first.md)) are 37/40 the boring common
case — checking only a handful would never have surfaced `AR1.SDT`'s 44.1kHz stereo audio,
or the two odd non-round sample rates. More consequentially, the `.RFM` VHCL-chunk/size-class
match ([document 4](04-worked-example-rfm-format.md)) is only actually *proven* because it
was checked against all 204 real files with zero exceptions — checked against 20 files, "48
of 50 large files have VHCL" would look like strong-but-imperfect evidence for something
that's actually a hard, exact rule with a bug in the checking code, not a soft correlation.

**Apply this whenever:** you think you've found a rule ("files at size X always have
property Y"). Write the check as code and run it against the entire dataset. A rule that's
true 95% of the time on a sample and a rule that's true 100% of the time overall look
identical from a small sample, and only one of them is safe to build a converter on.

## 4. If the "obvious" search method finds nothing, change the method before concluding the data isn't there

Looking for the `.RFM` magic bytes as a scalar instruction operand (`FindConstant.java`)
found zero hits, even though every level file starts with those exact bytes and the loader
clearly validates them somehow. The magic wasn't missing — it was compared via a string
function rather than baked in as an immediate, which a scalar-operand scan structurally
cannot see. A raw byte scan (`FindBytes.java`) found it immediately. The same shape of
mistake showed up again looking for a Win32 API by name (`FindImportCallers.java` found
nothing because the API was only referenced through an IAT data slot, not a named
`Function`) — solved the same way, by switching to a broader search (`FindSymbol.java`)
rather than concluding the API wasn't called at all.

**Apply this whenever:** a targeted search comes back empty for something you're confident
must exist in the binary. Before widening the *scope* of your search, first ask whether
you're using the right *kind* of search — the data is very often there, in a form your
first tool wasn't built to see.

## 5. Keep a disproven hypothesis in the repo, marked as superseded — don't delete it

`tools/rfcel.py`, the wrong `ART.CAR` packed-cel decoder, stayed in the repository after
being disproven, with a comment pointing at its replacement. That mattered concretely: its
row-offset-table discovery — a real, correct structural finding — turned out to be exactly
the mechanism the *actual* answer (span-based coverage masks) uses. If the file had simply
been deleted once the hypothesis built on top of it was shown to be wrong, that correct
piece would have had to be rediscovered from the binary a second time.

**Apply this whenever:** an investigation produces a decoder, a table dump, or a writeup
that turns out to be wrong in its conclusion. Don't delete the artifact — mark clearly which
part was wrong and which part (if any) was real, and let the next pass build on the part
that survives.

---

These aren't abstract good-engineering advice bolted on after the fact — every one of them
is here because *not* following it cost real time on this specific project. Read
[document 7](07-next-steps.md) next for the current backlog, and keep these five in mind
while working through it — the next wrong turn will look exactly as plausible as this one
did.
