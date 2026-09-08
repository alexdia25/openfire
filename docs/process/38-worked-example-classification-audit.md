# 38. Worked example: the Tank has 14 real parts, not 8 -- and a general classification audit

The user's ask that started this document was simple to state and hard to satisfy cheaply:
"we need to classify all the art better, so we know we aren't missing parts again in future."
Document 37's own addendum had just found 2 more real Tank parts beyond its original 6 --
this document found that count was *also* wrong, then built a reusable tool to check every
other code-traced object this project has, rather than trust another one-off eyeball pass.

## The Tank's real part count was never actually decoded correctly

Document 37's addendum trusted the angle-bucket draw-order byte strings as a part manifest:
whatever the highest index referenced there was, that was "the real part count." That
assumption was still wrong. Generalizing the extraction into a reusable script
(`tools/ghidra_scripts/DumpVehicleTypeParts.java`) and re-deriving the Tank's part count the
only reliable way -- walking part index 0, 1, 2, ... and stopping at the first entry whose
cel/corner indices go implausible, the same "garbage right after the real data" signal that
first exposed the 6-vs-8 miscount -- found **14 real parts**, not 8:

- The descriptor's `+0x2c` field (24 for the Tank) was never a part count at all -- it's the
  **corner array's own length**. Every part's 4 corner indices resolve inside `[0, 24)` with
  zero exceptions, up to the real boundary.
- The angle-bucket draw-order lists only ever reference indices 0-5 -- they cover the six
  "primary" hull faces document 37's main text already found, not a manifest of every part.
  Parts 6-13 are drawn unconditionally, outside any angle bucket, which is exactly why neither
  document 37's main text nor its own addendum ever saw them.

The 8 new parts: two are exact positional duplicates of an existing hull panel with a
*different* cel (177 over the bottom's 167, 192 over both the top and the left tread) -- read
as trim/window/hatch decals layered on the base panel (177's atlas note: "tan block, red-dot
windows"; 192's: "tan cab, red eyes+mouth trim"). Two (197, 207) are genuinely non-planar
panels. The last two are document 37's own unplaced "WARPED_PARTS" (202, 212) -- now confirmed
to actually be **two separate real parts for cel 202**, not one non-planar quad forced through
triangulation, which is exactly why every triangulation document 37 tried looked wrong: the
original never drew that shape as a single warped quad to begin with.

## Rendering them found a real bug, and a real non-bug

Implementing all 8 and sweeping all 8 compass headings (not one screenshot, per this project's
rule 1) found a black-wedge artifact on several headings. Isolating it (disabling every new
part one at a time) narrowed it to `_build_warped_mesh()`'s triangulation of non-convex quads:
it always split on the same diagonal (0-2 vs 1-3), which produces one inverted/overlapping
triangle for a quad with a reflex vertex. Fixed generally, not just for this one part: compute
the quad's own normal (Newell's method, works even off-planar), then pick whichever diagonal's
two triangles both agree with that normal's winding.

That fix cleared the artifact for the Tank's part 11 test case at every heading. The other
"unresolved" parts (197, 207, and cel 202's *second* part, 12) still show it -- but a
magenta-debug-colour material bypassing the real texture (`RF_DEBUG_WARPED_MESH_COLOR=1`,
kept as a permanent debug hook) proved the triangle *coverage* for these is already complete
and gap-free. **The remaining defect is a texture-UV problem, not a geometry hole**: this
function's naive "stretch the atlas rectangle across the 4 corners in order" UV assignment
warps badly for a non-rectangular quad, very likely sampling into the atlas's transparent
padding around the real sprite for some pixels. This is a materially more precise diagnosis
than document 37's "every triangulation looked glitched" -- the geometry was never the problem.

**Shipped:** 4 of the 8 new parts (177, 192 x2, 212) -- confirmed clean at every heading.
**Not shipped, recorded as data** (`UNRESOLVED_PARTS` in `game/vehicle_box_3d.gd`): 197, 207,
and both of cel 202's real parts, with the precise UV diagnosis above for whoever fixes it.

## The turret and gun barrel are conclusively not in this descriptor

The user's outstanding "where's the turret box and gun barrel" observation is now answered
more precisely, if not resolved: this session's boundary-detected walk covers **every** real
part of the Tank's per-vehicle-type record, not a partial trace. There is no 15th part, no
separate turret sub-list, nothing left unwalked. Whatever draws the turret and barrel in the
original -- if the Tank really has them as a persistent 3D structure and not, say, an animated
overlay drawn by an entirely different system -- it is **not** in this specific record. That
rules out one whole hypothesis rather than just leaving it untested.

## The general classification audit

The user asked for the broadest option when offered a scope choice: build a reusable tool and
run it everywhere, not just patch the Tank. `tools/registry/audit_code_referenced_cels.py`
cross-checks every cel this project has ever *proven* (by tracing real RFIRE.BIN code, not by
eyeballing a thumbnail) against the registry's own guess for that same cel, using two data
sources: `tools/data/vehicle_type_parts.json` (this document's new dump, all 4 vehicle types)
and `tools/data/coastal_decorations.json` (document 35/36's existing decoration catalogue).

Running it against Jeep/MSV/Heli's real geometry -- extracted for the first time this session,
the same way as the Tank's -- found 29 cels flatly misclassified as something else entirely
(character, prop, effect, marker, ui, decoration), not a vague-but-plausible guess like
document 37's cel 188, but a category error: nothing had ever traced these three vehicles'
real parts before. Corrected via this project's established hand-patch pattern (direct
`packs/registry/asset_ids.json` edit + a matching `put()` record in
`tools/registry/classify_bulk.py`) with a neutral `vehicle.<type>.part.NN` naming scheme --
these are proven to be real parts, but no visual-identification pass has been done on them
yet, so no descriptive name is invented. `confidence="code_verified"` is introduced as a new
tier, strictly above `"confirmed"` (which has sometimes meant no more than "eyeballed twice"
elsewhere in this registry): every cel carrying it is proven by walking real code, not visual
judgment. **None of Jeep/MSV/Heli are rendered in 3D yet** -- this is a registry-accuracy fix,
not a rendering one; only the Tank has a 3D presentation.

Running the same check against the decoration catalogue surfaced ~100 more "mismatches" that
turned out to be a different, softer question: many coastal decorations are legitimately
*assembled* from ordinary structure/prop cels (building walls, poles, banners) that are also
completely valid classified on their own. Recategorizing every such cel to `"decoration"`
would have been an unreviewed, sweeping taxonomy change with no clear right answer -- so the
script deliberately does **not** auto-fix these; it reports them as `SOFT MISMATCH`, left for
human judgment. Only 4 turned out to be a *real* bug regardless of appearance -- `"ui"` and
`"pickup"` describe rendering *roles* (a HUD overlay; a standalone collectible with its own
spawn logic) that are structurally incompatible with being a fixed part of something else, no
matter what the cel looks like. Direct atlas crops confirmed each: a wreath/ring shape
mislabeled `ui.radar.icon.01`, a small arch-trim piece and a red splatter shape both mislabeled
`pickup.star.*`, and an actual blend mask (`kind: effect_mask` in the atlas's own metadata,
not a drawable icon) also mislabeled `pickup.star.03`.

**Final state, `packs/registry/asset_ids.json`, 2165/2165 cels still classified, 0 registry
errors:**

| Finding | Count | Action |
|---|---|---|
| Vehicle cels, flat category error | 29 | Fixed -- renamed, category corrected, `code_verified` |
| Decoration cels, role-incompatible category | 4 | Fixed -- renamed, category corrected, `code_verified` |
| Already-correct cels upgraded to `code_verified` | 41 | Confidence upgraded only, id/category unchanged |
| Decoration cels, plausible composite reuse | 98 | Left alone -- documented as genuinely ambiguous |

The 98 soft mismatches are a real, useful finding in their own right -- a map of exactly which
decoration-adjacent cels' category reflects "what this looks like" rather than "every role it
plays" -- but reclassifying them is a product/taxonomy decision, not something this audit
should make unilaterally.

## What this doesn't settle

- The UV-mapping fix for `UNRESOLVED_PARTS` (197, 207, cel 202's second part) -- diagnosed
  precisely, not fixed.
- Jeep/MSV/Heli have zero 3D rendering -- this document only fixed their registry accuracy.
  Real geometry for all three now exists in `tools/data/vehicle_type_parts.json`, ready for
  whoever implements them the way `game/vehicle_box_3d.gd` implements the Tank.
- The turret/gun-barrel gap is *not* in the Tank's per-vehicle-type record (now conclusively
  ruled out) -- but where it actually lives is still completely untraced.
- The 98 soft-mismatch decoration cels -- a real, documented finding, deliberately left
  unresolved pending human judgment on the category taxonomy itself.

**Next:** back to [the next-steps doc](NEXT_STEPS.md) for the current backlog.
